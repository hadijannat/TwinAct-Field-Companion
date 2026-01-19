//
//  AROverlayView.swift
//  TwinAct Field Companion
//
//  SwiftUI wrapper for AR view with overlay controls.
//  Provides the main AR experience for viewing sensor data
//  and maintenance procedures overlaid on physical assets.
//

import SwiftUI
import ARKit
import RealityKit

// MARK: - AR Overlay View

/// Main AR view for displaying overlays on physical assets.
public struct AROverlayView: View {
    @StateObject private var sessionManager = ARSessionManager()
    @StateObject private var viewModel: AROverlayViewModel

    let asset: Asset
    let mode: ARMode

    /// Initialize the AR overlay view.
    /// - Parameters:
    ///   - asset: The asset to display overlays for
    ///   - mode: The AR operating mode
    ///   - timeSeriesData: Optional time series data for sensor overlays
    ///   - maintenanceInstructions: Optional maintenance instructions for procedure overlays
    public init(
        asset: Asset,
        mode: ARMode,
        timeSeriesData: TimeSeriesData? = nil,
        maintenanceInstructions: MaintenanceInstructions? = nil
    ) {
        self.asset = asset
        self.mode = mode
        self._viewModel = StateObject(wrappedValue: AROverlayViewModel(
            asset: asset,
            timeSeriesData: timeSeriesData,
            maintenanceInstructions: maintenanceInstructions
        ))
    }

    public var body: some View {
        ZStack {
            // AR View
            ARViewContainer(arView: sessionManager.arView)
                .ignoresSafeArea()
                .onTapGesture { location in
                    handleTap(at: location)
                }

            // Tracking status overlay
            VStack {
                TrackingStatusView(state: sessionManager.trackingState)
                    .padding(.top, 8)

                Spacer()
            }

            // Error overlay
            if let error = sessionManager.error {
                ARErrorOverlay(error: error) {
                    sessionManager.resetSession()
                }
            }

            // Mode-specific content
            VStack {
                Spacer()

                // Selected overlay detail
                if let overlay = viewModel.selectedOverlay {
                    AROverlayDetailCard(overlay: overlay) {
                        viewModel.selectedOverlay = nil
                    }
                    .padding()
                }

                // Controls
                ARControlsView(
                    mode: mode,
                    showLabels: viewModel.showLabels,
                    showPlanes: sessionManager.showPlaneVisualization,
                    currentStep: viewModel.currentMaintenanceStep,
                    totalSteps: viewModel.totalMaintenanceSteps,
                    onPlaceOverlay: { placeOverlayAtCenter() },
                    onToggleLabels: { viewModel.toggleLabels() },
                    onTogglePlanes: { sessionManager.togglePlaneVisualization() },
                    onReset: { resetAR() },
                    onPreviousStep: { viewModel.previousMaintenanceStep() },
                    onNextStep: { viewModel.nextMaintenanceStep() }
                )
                .padding()
            }

            // Crosshair for placement
            if viewModel.isPlacementMode {
                Image(systemName: "plus")
                    .font(.title)
                    .foregroundColor(.white)
                    .shadow(color: .black, radius: 2)
            }
        }
        .navigationTitle(asset.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: { placeOverlayAtCenter() }) {
                        Label("Place Overlay", systemImage: "plus.circle")
                    }

                    Button(action: { viewModel.toggleLabels() }) {
                        Label(
                            viewModel.showLabels ? "Hide Labels" : "Show Labels",
                            systemImage: viewModel.showLabels ? "eye.slash" : "eye"
                        )
                    }

                    Button(action: { sessionManager.togglePlaneVisualization() }) {
                        Label(
                            sessionManager.showPlaneVisualization ? "Hide Planes" : "Show Planes",
                            systemImage: "square.stack.3d.up"
                        )
                    }

                    Divider()

                    Button(role: .destructive, action: { resetAR() }) {
                        Label("Reset AR", systemImage: "arrow.counterclockwise")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .onAppear {
            sessionManager.startSession(mode: mode)
            viewModel.attachToSession(sessionManager)
        }
        .onDisappear {
            sessionManager.pauseSession()
        }
    }

    // MARK: - Actions

    private func handleTap(at location: CGPoint) {
        if viewModel.isPlacementMode {
            if let position = sessionManager.raycast(from: location) {
                viewModel.placeOverlay(at: position)
            }
        } else {
            // Check if tapping on an existing overlay
            viewModel.selectOverlay(at: location, in: sessionManager.arView)
        }
    }

    private func placeOverlayAtCenter() {
        if let anchor = sessionManager.addAnchorAtCenter() {
            viewModel.placeOverlays(on: anchor)
        }
    }

    private func resetAR() {
        viewModel.clearOverlays()
        sessionManager.resetSession()
    }
}

// MARK: - AR View Container

/// UIViewRepresentable wrapper for ARView.
struct ARViewContainer: UIViewRepresentable {
    let arView: ARView

    func makeUIView(context: Context) -> ARView {
        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        // Update handled by session manager
    }
}

// MARK: - AR Controls View

/// Bottom controls for AR interaction.
struct ARControlsView: View {
    let mode: ARMode
    let showLabels: Bool
    let showPlanes: Bool
    let currentStep: Int?
    let totalSteps: Int?
    let onPlaceOverlay: () -> Void
    let onToggleLabels: () -> Void
    let onTogglePlanes: () -> Void
    let onReset: () -> Void
    let onPreviousStep: () -> Void
    let onNextStep: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            // Maintenance step navigation (only in maintenance mode)
            if mode == .maintenanceProcedure,
               let current = currentStep,
               let total = totalSteps {
                MaintenanceStepNavigator(
                    currentStep: current,
                    totalSteps: total,
                    onPrevious: onPreviousStep,
                    onNext: onNextStep
                )
            }

            // Main controls
            HStack(spacing: 20) {
                // Toggle labels
                ARControlButton(
                    icon: showLabels ? "eye.fill" : "eye.slash.fill",
                    label: "Labels",
                    isActive: showLabels,
                    action: onToggleLabels
                )

                // Place overlay
                ARControlButton(
                    icon: "plus.circle.fill",
                    label: "Place",
                    isActive: false,
                    isPrimary: true,
                    action: onPlaceOverlay
                )

                // Toggle planes
                ARControlButton(
                    icon: "square.stack.3d.up.fill",
                    label: "Planes",
                    isActive: showPlanes,
                    action: onTogglePlanes
                )

                // Reset
                ARControlButton(
                    icon: "arrow.counterclockwise",
                    label: "Reset",
                    isActive: false,
                    action: onReset
                )
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
    }
}

// MARK: - AR Control Button

/// Individual control button for AR interface.
struct ARControlButton: View {
    let icon: String
    let label: String
    let isActive: Bool
    var isPrimary: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(isPrimary ? .white : (isActive ? .blue : .primary))
                    .frame(width: 44, height: 44)
                    .background(isPrimary ? Color.blue : (isActive ? Color.blue.opacity(0.2) : Color.clear))
                    .cornerRadius(12)

                Text(label)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Maintenance Step Navigator

/// Navigation controls for maintenance procedure steps.
struct MaintenanceStepNavigator: View {
    let currentStep: Int
    let totalSteps: Int
    let onPrevious: () -> Void
    let onNext: () -> Void

    var body: some View {
        HStack {
            Button(action: onPrevious) {
                Image(systemName: "chevron.left.circle.fill")
                    .font(.title2)
            }
            .disabled(currentStep <= 1)

            Spacer()

            Text("Step \(currentStep) of \(totalSteps)")
                .font(.headline)

            Spacer()

            Button(action: onNext) {
                Image(systemName: "chevron.right.circle.fill")
                    .font(.title2)
            }
            .disabled(currentStep >= totalSteps)
        }
        .padding(.horizontal)
    }
}

// MARK: - AR Overlay Detail Card

/// Detail card shown when an overlay is selected.
struct AROverlayDetailCard: View {
    let overlay: AROverlay
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: overlay.iconName)
                    .foregroundColor(overlay.statusColor)

                Text(overlay.title)
                    .font(.headline)

                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }

            Text(overlay.detailText)
                .font(.body)
                .foregroundColor(.secondary)

            if let warning = overlay.warning {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(warning)
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
        }
        .padding()
        .background(.regularMaterial)
        .cornerRadius(12)
    }
}

// MARK: - AR Error Overlay

/// Error display overlay for AR issues.
struct ARErrorOverlay: View {
    let error: ARError
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.orange)

            Text("AR Error")
                .font(.headline)

            Text(error.localizedDescription)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button("Retry", action: onRetry)
                .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(.regularMaterial)
        .cornerRadius(16)
        .padding()
    }
}

// MARK: - Preview

#if DEBUG
struct AROverlayView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            AROverlayView(
                asset: Asset(
                    id: "preview-asset",
                    name: "Preview Motor"
                ),
                mode: .sensorOverlay
            )
        }
    }
}
#endif

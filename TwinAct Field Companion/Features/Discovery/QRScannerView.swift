//
//  QRScannerView.swift
//  TwinAct Field Companion
//
//  Full-screen QR scanner view for asset discovery.
//  Main entry point for scanning IEC 61406 identification links.
//

import SwiftUI
import AVFoundation

// MARK: - QR Scanner View

/// Full-screen QR code scanner for asset identification.
public struct QRScannerView: View {

    // MARK: - Properties

    @StateObject private var viewModel = QRScannerViewModel()
    @Environment(\.dismiss) private var dismiss

    /// Callback when a code is detected and parsed
    var onCodeDetected: ((AssetIdentificationLink) -> Void)?

    /// Callback when a raw code is detected (parsed or not)
    var onRawCodeDetected: ((String) -> Void)?

    /// Whether to auto-dismiss after detection
    var autoDismiss: Bool = true

    /// Delay before auto-dismiss (in seconds)
    var autoDismissDelay: TimeInterval = 1.5

    // MARK: - State

    @State private var showPermissionAlert = false
    @State private var showErrorAlert = false
    @State private var showManualEntry = false

    // MARK: - Initialization

    public init(
        onCodeDetected: ((AssetIdentificationLink) -> Void)? = nil,
        onRawCodeDetected: ((String) -> Void)? = nil,
        autoDismiss: Bool = true
    ) {
        self.onCodeDetected = onCodeDetected
        self.onRawCodeDetected = onRawCodeDetected
        self.autoDismiss = autoDismiss
    }

    // MARK: - Body

    public var body: some View {
        ZStack {
            // Camera preview
            cameraPreview

            // Scanning overlay
            ScanningOverlayView(
                isScanning: viewModel.isScanning,
                detectedCode: viewModel.detectedCode,
                parsedLink: viewModel.parsedAssetLink
            )

            // Controls overlay
            controlsOverlay
        }
        .ignoresSafeArea()
        .statusBar(hidden: true)
        .onAppear {
            viewModel.startScanning()
        }
        .onDisappear {
            viewModel.stopScanning()
        }
        .onChange(of: viewModel.parsedAssetLink) { _, link in
            handleDetection(link: link)
        }
        .onChange(of: viewModel.detectedCode) { _, code in
            if let code = code {
                onRawCodeDetected?(code)
            }
        }
        .onChange(of: viewModel.error) { _, error in
            if error == .cameraAccessDenied || error == .cameraAccessRestricted {
                showPermissionAlert = true
            } else if error != nil {
                showErrorAlert = true
            }
        }
        .alert("Camera Access Required", isPresented: $showPermissionAlert) {
            Button("Open Settings") {
                openAppSettings()
            }
            Button("Cancel", role: .cancel) {
                dismiss()
            }
        } message: {
            Text("Please enable camera access in Settings to scan QR codes.")
        }
        .alert("Scanner Error", isPresented: $showErrorAlert) {
            Button("Retry") {
                viewModel.reset()
                viewModel.startScanning()
            }
            Button("Cancel", role: .cancel) {
                dismiss()
            }
        } message: {
            Text(viewModel.error?.localizedDescription ?? "An unknown error occurred.")
        }
        .sheet(isPresented: $showManualEntry) {
            ManualEntrySheet(onSubmit: handleManualEntry)
        }
    }

    // MARK: - Camera Preview

    @ViewBuilder
    private var cameraPreview: some View {
        if viewModel.authorizationStatus == .authorized ||
           viewModel.authorizationStatus == .notDetermined {
            CameraPreviewView(session: viewModel.captureSession)
                .gesture(
                    TapGesture()
                        .onEnded { _ in
                            // Tap to focus is handled by the preview layer
                        }
                )
        } else {
            // Placeholder when camera not available
            Color.black
                .overlay(
                    VStack(spacing: 20) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)

                        Text("Camera Access Required")
                            .font(.headline)
                            .foregroundColor(.white)

                        Text("Enable camera access in Settings to scan QR codes")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                )
        }
    }

    // MARK: - Controls Overlay

    private var controlsOverlay: some View {
        VStack {
            // Top bar
            topBar

            Spacer()

            // Bottom bar
            bottomBar
        }
        .padding()
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            // Close button
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(12)
                    .background(Color.black.opacity(0.5))
                    .clipShape(Circle())
            }

            Spacer()

            // Torch button (if available)
            if viewModel.torchAvailable {
                Button {
                    viewModel.toggleTorch()
                } label: {
                    Image(systemName: viewModel.torchEnabled ? "flashlight.on.fill" : "flashlight.off.fill")
                        .font(.title2)
                        .foregroundColor(viewModel.torchEnabled ? .yellow : .white)
                        .padding(12)
                        .background(Color.black.opacity(0.5))
                        .clipShape(Circle())
                }
            }
        }
        .padding(.top, 50) // Account for status bar area
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        VStack(spacing: 16) {
            // Detection result (if any)
            if let link = viewModel.parsedAssetLink {
                detectionResultCard(link: link)
            }

            // Action buttons
            HStack(spacing: 20) {
                // Manual entry button
                Button {
                    showManualEntry = true
                } label: {
                    HStack {
                        Image(systemName: "keyboard")
                        Text("Enter Manually")
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.black.opacity(0.5))
                    .cornerRadius(25)
                }

                // Scan again button (after detection)
                if viewModel.detectedCode != nil {
                    Button {
                        viewModel.reset()
                    } label: {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Scan Again")
                        }
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .cornerRadius(25)
                    }
                }
            }
        }
        .padding(.bottom, 30)
    }

    // MARK: - Detection Result Card

    private func detectionResultCard(link: AssetIdentificationLink) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("QR Code Detected")
                    .font(.headline)
                Spacer()
            }

            Divider()
                .background(Color.white.opacity(0.3))

            if let manufacturer = link.manufacturer {
                infoRow(label: "Manufacturer", value: manufacturer)
            }

            if let serial = link.serialNumber {
                infoRow(label: "Serial Number", value: serial)
            }

            if let part = link.partNumber {
                infoRow(label: "Part Number", value: part)
            }

            infoRow(label: "Format", value: link.linkType.displayName)

            if link.canLookup {
                HStack {
                    Spacer()
                    Button {
                        onCodeDetected?(link)
                        if autoDismiss {
                            dismiss()
                        }
                    } label: {
                        HStack {
                            Text("Look Up Asset")
                            Image(systemName: "arrow.right")
                        }
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.blue)
                        .cornerRadius(20)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .background(Color.black.opacity(0.8))
        .cornerRadius(16)
        .padding(.horizontal)
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.gray)
            Spacer()
            Text(value)
                .font(.subheadline)
                .foregroundColor(.white)
                .lineLimit(1)
        }
    }

    // MARK: - Actions

    private func handleDetection(link: AssetIdentificationLink?) {
        guard let link = link else { return }

        // Auto-callback and dismiss
        if autoDismiss && link.canLookup {
            DispatchQueue.main.asyncAfter(deadline: .now() + autoDismissDelay) {
                onCodeDetected?(link)
                dismiss()
            }
        }
    }

    private func handleManualEntry(_ code: String) {
        showManualEntry = false

        // Parse the manually entered code
        if let link = IdentificationLinkParser.parse(code) {
            viewModel.detectedCode = code
            viewModel.parsedAssetLink = link
            viewModel.state = .detected(code)
        } else {
            // Create a basic link from raw input
            let link = AssetIdentificationLink(
                originalURL: URL(string: code),
                originalString: code,
                linkType: .unknown,
                serialNumber: code.count <= 30 ? code : nil,
                globalAssetId: code,
                specificAssetIds: [SpecificAssetId(name: "globalAssetId", value: code)],
                confidence: 0.5
            )
            viewModel.detectedCode = code
            viewModel.parsedAssetLink = link
            viewModel.state = .detected(code)
        }
    }

    private func openAppSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Manual Entry Sheet

/// Sheet for manually entering asset identifiers.
struct ManualEntrySheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var inputText: String = ""
    @FocusState private var isFocused: Bool

    var onSubmit: (String) -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Enter asset identifier, serial number, or identification link URL")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                TextField("Serial number, URL, or asset ID", text: $inputText)
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                    .focused($isFocused)
                    .padding(.horizontal)

                // Examples
                VStack(alignment: .leading, spacing: 8) {
                    Text("Examples:")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)

                    exampleRow("Serial Number", "ABC123456")
                    exampleRow("URL", "https://id.siemens.com/...")
                    exampleRow("URN", "urn:eclass:0173-1#...")
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
                .padding(.horizontal)

                Spacer()
            }
            .padding(.top)
            .navigationTitle("Manual Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Submit") {
                        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                            return
                        }
                        onSubmit(inputText.trimmingCharacters(in: .whitespacesAndNewlines))
                    }
                    .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                isFocused = true
            }
        }
    }

    private func exampleRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 100, alignment: .leading)

            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .lineLimit(1)
        }
    }
}

// MARK: - View Modifiers

extension QRScannerView {
    /// Set callback for when a parsed identification link is detected.
    public func onDetected(_ handler: @escaping (AssetIdentificationLink) -> Void) -> QRScannerView {
        var copy = self
        copy.onCodeDetected = handler
        return copy
    }

    /// Set callback for raw code detection (before parsing).
    public func onRawCode(_ handler: @escaping (String) -> Void) -> QRScannerView {
        var copy = self
        copy.onRawCodeDetected = handler
        return copy
    }

    /// Configure auto-dismiss behavior.
    public func autoDismiss(_ enabled: Bool, delay: TimeInterval = 1.5) -> QRScannerView {
        var copy = self
        copy.autoDismiss = enabled
        copy.autoDismissDelay = delay
        return copy
    }
}

// MARK: - Preview Provider

#if DEBUG
struct QRScannerView_Previews: PreviewProvider {
    static var previews: some View {
        QRScannerView { link in
            print("Detected: \(link.displaySummary)")
        }
    }
}
#endif

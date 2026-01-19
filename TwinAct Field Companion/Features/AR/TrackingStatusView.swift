//
//  TrackingStatusView.swift
//  TwinAct Field Companion
//
//  AR tracking status feedback view.
//  Displays current tracking quality and guidance for users.
//

import SwiftUI
import ARKit

// MARK: - Tracking Status View

/// Displays the current AR tracking status with visual feedback.
public struct TrackingStatusView: View {
    let state: ARCamera.TrackingState

    public init(state: ARCamera.TrackingState) {
        self.state = state
    }

    public var body: some View {
        HStack(spacing: 8) {
            // Status icon
            Image(systemName: iconName)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(statusColor)

            // Status text
            Text(statusText)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(statusColor)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }

    // MARK: - Status Properties

    private var statusText: String {
        switch state {
        case .normal:
            return "Tracking"
        case .limited(let reason):
            return reason.description
        case .notAvailable:
            return "Initializing..."
        }
    }

    private var iconName: String {
        switch state {
        case .normal:
            return "checkmark.circle.fill"
        case .limited(let reason):
            return reason.iconName
        case .notAvailable:
            return "hourglass"
        }
    }

    private var statusColor: Color {
        switch state {
        case .normal:
            return .green
        case .limited:
            return .orange
        case .notAvailable:
            return .gray
        }
    }
}

// MARK: - Tracking State Reason Extension

extension ARCamera.TrackingState.Reason {
    /// Human-readable description of the tracking limitation reason.
    var description: String {
        switch self {
        case .initializing:
            return "Initializing..."
        case .excessiveMotion:
            return "Move slower"
        case .insufficientFeatures:
            return "Low detail area"
        case .relocalizing:
            return "Relocating..."
        @unknown default:
            return "Limited tracking"
        }
    }

    /// SF Symbol icon name for the tracking limitation reason.
    var iconName: String {
        switch self {
        case .initializing:
            return "hourglass"
        case .excessiveMotion:
            return "tortoise.fill"
        case .insufficientFeatures:
            return "eye.trianglebadge.exclamationmark.fill"
        case .relocalizing:
            return "location.magnifyingglass"
        @unknown default:
            return "exclamationmark.triangle.fill"
        }
    }

    /// Guidance text for the user.
    var guidanceText: String {
        switch self {
        case .initializing:
            return "Point at a surface with visual features"
        case .excessiveMotion:
            return "Slow down your movement"
        case .insufficientFeatures:
            return "Point at an area with more visual detail"
        case .relocalizing:
            return "Return to previous area to restore tracking"
        @unknown default:
            return "Adjust your position for better tracking"
        }
    }
}

// MARK: - Extended Tracking Status View

/// Extended tracking status view with guidance and detailed feedback.
public struct ExtendedTrackingStatusView: View {
    let state: ARCamera.TrackingState
    let showGuidance: Bool

    public init(state: ARCamera.TrackingState, showGuidance: Bool = true) {
        self.state = state
        self.showGuidance = showGuidance
    }

    public var body: some View {
        VStack(spacing: 8) {
            // Main status
            TrackingStatusView(state: state)

            // Guidance (shown for limited states)
            if showGuidance, case .limited(let reason) = state {
                GuidanceView(reason: reason)
            }
        }
    }
}

// MARK: - Guidance View

/// Displays guidance text for limited tracking states.
struct GuidanceView: View {
    let reason: ARCamera.TrackingState.Reason

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "info.circle")
                .font(.caption2)

            Text(reason.guidanceText)
                .font(.caption2)
        }
        .foregroundColor(.secondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }
}

// MARK: - Tracking Quality Indicator

/// A visual indicator of tracking quality as a progress bar.
public struct TrackingQualityIndicator: View {
    let state: ARCamera.TrackingState

    public init(state: ARCamera.TrackingState) {
        self.state = state
    }

    public var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(index < qualityLevel ? statusColor : Color.gray.opacity(0.3))
                    .frame(width: 8, height: 12)
            }
        }
    }

    private var qualityLevel: Int {
        switch state {
        case .normal:
            return 3
        case .limited(let reason):
            switch reason {
            case .initializing, .relocalizing:
                return 1
            case .excessiveMotion, .insufficientFeatures:
                return 2
            @unknown default:
                return 1
            }
        case .notAvailable:
            return 0
        }
    }

    private var statusColor: Color {
        switch state {
        case .normal:
            return .green
        case .limited:
            return .orange
        case .notAvailable:
            return .red
        }
    }
}

// MARK: - Compact Tracking Badge

/// A compact badge showing tracking status.
public struct TrackingBadge: View {
    let state: ARCamera.TrackingState

    public init(state: ARCamera.TrackingState) {
        self.state = state
    }

    public var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)

            if case .normal = state {
                // Only show "AR" text when tracking is good
                Text("AR")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }

    private var statusColor: Color {
        switch state {
        case .normal:
            return .green
        case .limited:
            return .orange
        case .notAvailable:
            return .gray
        }
    }
}

// MARK: - Plane Detection Status

/// Shows the number of detected planes.
public struct PlaneDetectionStatusView: View {
    let horizontalCount: Int
    let verticalCount: Int

    public init(horizontalCount: Int, verticalCount: Int) {
        self.horizontalCount = horizontalCount
        self.verticalCount = verticalCount
    }

    public var body: some View {
        HStack(spacing: 12) {
            // Horizontal planes
            HStack(spacing: 4) {
                Image(systemName: "square.fill")
                    .font(.caption2)
                Text("\(horizontalCount)")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundColor(horizontalCount > 0 ? .green : .gray)

            // Vertical planes
            HStack(spacing: 4) {
                Image(systemName: "rectangle.portrait.fill")
                    .font(.caption2)
                Text("\(verticalCount)")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundColor(verticalCount > 0 ? .blue : .gray)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }
}

// MARK: - Session Info View

/// Comprehensive AR session info display.
public struct ARSessionInfoView: View {
    let trackingState: ARCamera.TrackingState
    let planeCount: Int
    let showPlanes: Bool

    public init(
        trackingState: ARCamera.TrackingState,
        planeCount: Int,
        showPlanes: Bool
    ) {
        self.trackingState = trackingState
        self.planeCount = planeCount
        self.showPlanes = showPlanes
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Tracking status
            HStack {
                Text("Tracking")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                TrackingQualityIndicator(state: trackingState)
            }

            Divider()

            // Planes detected
            HStack {
                Text("Surfaces")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(planeCount) detected")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(planeCount > 0 ? .green : .gray)
            }

            // Plane visualization status
            HStack {
                Text("Show planes")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Image(systemName: showPlanes ? "checkmark.circle.fill" : "circle")
                    .font(.caption)
                    .foregroundColor(showPlanes ? .blue : .gray)
            }
        }
        .padding(12)
        .background(.regularMaterial)
        .cornerRadius(12)
        .frame(width: 180)
    }
}

// MARK: - Previews

#if DEBUG
struct TrackingStatusView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            TrackingStatusView(state: .normal)

            TrackingStatusView(state: .limited(.insufficientFeatures))

            TrackingStatusView(state: .limited(.excessiveMotion))

            TrackingStatusView(state: .notAvailable)

            ExtendedTrackingStatusView(
                state: .limited(.insufficientFeatures),
                showGuidance: true
            )

            TrackingQualityIndicator(state: .normal)

            TrackingBadge(state: .normal)

            PlaneDetectionStatusView(horizontalCount: 3, verticalCount: 1)

            ARSessionInfoView(
                trackingState: .normal,
                planeCount: 4,
                showPlanes: true
            )
        }
        .padding()
        .background(Color.gray.opacity(0.2))
    }
}
#endif

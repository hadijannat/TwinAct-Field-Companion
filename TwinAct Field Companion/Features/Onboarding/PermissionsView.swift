//
//  PermissionsView.swift
//  TwinAct Field Companion
//
//  Permission request screen for camera and microphone access.
//

import SwiftUI
import AVFoundation
import Speech

// MARK: - Permissions View

/// Requests camera and microphone permissions with clear explanations.
struct PermissionsView: View {

    // MARK: - Properties

    @State private var cameraStatus: PermissionStatus = .notDetermined
    @State private var microphoneStatus: PermissionStatus = .notDetermined
    @State private var speechStatus: PermissionStatus = .notDetermined

    let onComplete: () -> Void

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Header
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.15))
                        .frame(width: 100, height: 100)

                    Image(systemName: "hand.raised.fill")
                        .font(.system(size: 44))
                        .foregroundColor(.blue)
                }

                Text("Permissions")
                    .font(.title)
                    .fontWeight(.bold)

                Text("TwinAct needs a few permissions to provide the best experience. You can change these later in Settings.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()
                .frame(height: 40)

            // Permission rows
            VStack(spacing: 16) {
                PermissionRow(
                    icon: "camera.fill",
                    iconColor: .blue,
                    title: "Camera",
                    description: "Scan QR codes on equipment",
                    status: cameraStatus,
                    onRequest: requestCameraPermission
                )

                PermissionRow(
                    icon: "mic.fill",
                    iconColor: .purple,
                    title: "Microphone",
                    description: "Use voice commands hands-free",
                    status: microphoneStatus,
                    onRequest: requestMicrophonePermission
                )

                PermissionRow(
                    icon: "waveform",
                    iconColor: .cyan,
                    title: "Speech Recognition",
                    description: "Convert voice to text commands",
                    status: speechStatus,
                    onRequest: requestSpeechPermission
                )
            }
            .padding(.horizontal, 24)

            Spacer()

            // Continue button
            VStack(spacing: 12) {
                Button(action: onComplete) {
                    Text("Continue")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .buttonStyle(.borderedProminent)

                if !allPermissionsGranted {
                    Text("You can skip permissions and grant them later when needed.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .background(Color(.systemGroupedBackground))
        .onAppear {
            checkPermissionStatuses()
        }
    }

    // MARK: - Computed Properties

    private var allPermissionsGranted: Bool {
        cameraStatus == .granted && microphoneStatus == .granted && speechStatus == .granted
    }

    // MARK: - Permission Checks

    private func checkPermissionStatuses() {
        // Camera
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: cameraStatus = .granted
        case .denied, .restricted: cameraStatus = .denied
        case .notDetermined: cameraStatus = .notDetermined
        @unknown default: cameraStatus = .notDetermined
        }

        // Microphone
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: microphoneStatus = .granted
        case .denied, .restricted: microphoneStatus = .denied
        case .notDetermined: microphoneStatus = .notDetermined
        @unknown default: microphoneStatus = .notDetermined
        }

        // Speech Recognition
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized: speechStatus = .granted
        case .denied, .restricted: speechStatus = .denied
        case .notDetermined: speechStatus = .notDetermined
        @unknown default: speechStatus = .notDetermined
        }
    }

    // MARK: - Permission Requests

    private func requestCameraPermission() {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async {
                cameraStatus = granted ? .granted : .denied
            }
        }
    }

    private func requestMicrophonePermission() {
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            DispatchQueue.main.async {
                microphoneStatus = granted ? .granted : .denied
            }
        }
    }

    private func requestSpeechPermission() {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                switch status {
                case .authorized: speechStatus = .granted
                case .denied, .restricted: speechStatus = .denied
                case .notDetermined: speechStatus = .notDetermined
                @unknown default: speechStatus = .notDetermined
                }
            }
        }
    }
}

// MARK: - Permission Status

private enum PermissionStatus {
    case notDetermined
    case granted
    case denied
}

// MARK: - Permission Row

private struct PermissionRow: View {

    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    let status: PermissionStatus
    let onRequest: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(iconColor)
            }

            // Text
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Status/Action
            statusView
        }
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var statusView: some View {
        switch status {
        case .notDetermined:
            Button("Enable") {
                onRequest()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

        case .granted:
            Image(systemName: "checkmark.circle.fill")
                .font(.title2)
                .foregroundColor(.green)

        case .denied:
            Button("Settings") {
                openSettings()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .tint(.orange)
        }
    }

    private func openSettings() {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(settingsURL)
    }
}

// MARK: - Preview

#if DEBUG
struct PermissionsView_Previews: PreviewProvider {
    static var previews: some View {
        PermissionsView(onComplete: {})
            .previewDisplayName("Permissions")
    }
}
#endif

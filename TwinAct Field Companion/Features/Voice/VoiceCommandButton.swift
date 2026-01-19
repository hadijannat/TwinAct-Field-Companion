//
//  VoiceCommandButton.swift
//  TwinAct Field Companion
//
//  Push-to-talk voice command button with visual feedback.
//  Provides hands-free operation for field technicians.
//

import SwiftUI

// MARK: - Voice Command Button

/// Push-to-talk button for voice command input.
///
/// Supports both tap-to-toggle and long-press-to-talk modes.
/// Shows audio level visualization while listening.
///
/// ## Usage
/// ```swift
/// VoiceCommandButton()
///     .environmentObject(confirmationFlow)
/// ```
public struct VoiceCommandButton: View {

    // MARK: - Environment & State

    @StateObject private var speechRecognizer = SpeechRecognizer()
    @EnvironmentObject private var confirmationFlow: VoiceConfirmationFlow

    @State private var isPressed = false
    @State private var showPermissionAlert = false
    @State private var pulseAnimation = false

    // MARK: - Configuration

    /// Size of the button
    public var buttonSize: CGFloat = 56

    /// Whether to use push-to-talk mode (vs tap-to-toggle)
    public var pushToTalk: Bool = true

    // MARK: - Initialization

    public init(buttonSize: CGFloat = 56, pushToTalk: Bool = true) {
        self.buttonSize = buttonSize
        self.pushToTalk = pushToTalk
    }

    // MARK: - Body

    public var body: some View {
        ZStack {
            // Background pulse animation when listening
            if speechRecognizer.isListening {
                pulseCircle
            }

            // Audio level indicator
            if speechRecognizer.isListening {
                audioLevelIndicator
            }

            // Main button
            mainButton
        }
        .onAppear {
            setupRecognizer()
        }
        .alert("Microphone Access Required", isPresented: $showPermissionAlert) {
            Button("Open Settings") {
                openSettings()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Voice commands require microphone access. Please enable it in Settings.")
        }
    }

    // MARK: - Subviews

    private var pulseCircle: some View {
        Circle()
            .fill(Color.accentColor.opacity(0.3))
            .frame(width: buttonSize * 1.5, height: buttonSize * 1.5)
            .scaleEffect(pulseAnimation ? 1.3 : 1.0)
            .opacity(pulseAnimation ? 0.0 : 0.5)
            .animation(
                .easeInOut(duration: 1.0).repeatForever(autoreverses: false),
                value: pulseAnimation
            )
            .onAppear {
                pulseAnimation = true
            }
            .onDisappear {
                pulseAnimation = false
            }
    }

    private var audioLevelIndicator: some View {
        Circle()
            .stroke(Color.accentColor, lineWidth: 3)
            .frame(width: buttonSize + 12, height: buttonSize + 12)
            .scaleEffect(1.0 + CGFloat(speechRecognizer.audioLevel) * 0.3)
            .opacity(0.7)
            .animation(.easeOut(duration: 0.1), value: speechRecognizer.audioLevel)
    }

    private var mainButton: some View {
        Button {
            handleTap()
        } label: {
            buttonContent
        }
        .buttonStyle(.plain)
        .simultaneousGesture(longPressGesture)
        .accessibilityLabel(speechRecognizer.isListening ? "Stop listening" : "Start voice command")
        .accessibilityHint(pushToTalk ? "Press and hold to speak" : "Tap to start or stop listening")
    }

    private var buttonContent: some View {
        ZStack {
            Circle()
                .fill(buttonBackgroundColor)
                .frame(width: buttonSize, height: buttonSize)
                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)

            Image(systemName: buttonIcon)
                .font(.system(size: buttonSize * 0.4, weight: .semibold))
                .foregroundColor(.white)
                .symbolEffect(.variableColor.iterative, isActive: speechRecognizer.isListening)
        }
    }

    private var buttonBackgroundColor: Color {
        if speechRecognizer.isListening {
            return .red
        } else if isPressed {
            return Color.accentColor.opacity(0.8)
        } else {
            return Color.accentColor
        }
    }

    private var buttonIcon: String {
        if speechRecognizer.isListening {
            return "waveform"
        } else {
            return "mic.fill"
        }
    }

    private var longPressGesture: some Gesture {
        LongPressGesture(minimumDuration: 0.2)
            .onChanged { _ in
                if pushToTalk && !speechRecognizer.isListening {
                    isPressed = true
                    startListening()
                }
            }
            .sequenced(before: DragGesture(minimumDistance: 0))
            .onEnded { _ in
                if pushToTalk && speechRecognizer.isListening {
                    isPressed = false
                    stopListening()
                }
            }
    }

    // MARK: - Actions

    private func setupRecognizer() {
        // Set up completion callback
        speechRecognizer.onRecognitionComplete = { transcript, confidence in
            handleRecognitionComplete(transcript: transcript, confidence: confidence)
        }

        // Request authorization on first use
        Task {
            let authorized = await speechRecognizer.requestAuthorization()
            if !authorized {
                showPermissionAlert = true
            }
        }
    }

    private func handleTap() {
        if pushToTalk {
            // In push-to-talk mode, tap cancels listening
            if speechRecognizer.isListening {
                speechRecognizer.cancelListening()
            }
        } else {
            // Toggle mode
            if speechRecognizer.isListening {
                stopListening()
            } else {
                startListening()
            }
        }
    }

    private func startListening() {
        guard speechRecognizer.isAuthorized else {
            showPermissionAlert = true
            return
        }

        do {
            try speechRecognizer.startListening()
        } catch {
            print("Failed to start listening: \(error)")
        }
    }

    private func stopListening() {
        speechRecognizer.stopListening()
    }

    private func handleRecognitionComplete(transcript: String, confidence: Float) {
        guard !transcript.isEmpty else { return }

        // Classify the intent
        let intent = VoiceIntentClassifier.classify(transcript)

        // Check if we're waiting for confirmation
        if confirmationFlow.isAwaitingConfirmation {
            // Handle as follow-up intent (confirm/cancel)
            Task {
                await confirmationFlow.handleFollowUpIntent(intent)
            }
        } else {
            // Process as new intent
            confirmationFlow.processIntent(intent, transcript: transcript)
        }
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Compact Voice Button

/// Smaller voice command button for toolbar or inline use
public struct CompactVoiceCommandButton: View {

    @StateObject private var speechRecognizer = SpeechRecognizer()
    @EnvironmentObject private var confirmationFlow: VoiceConfirmationFlow

    @State private var showPermissionAlert = false

    public init() {}

    public var body: some View {
        Button {
            toggleListening()
        } label: {
            Image(systemName: speechRecognizer.isListening ? "waveform" : "mic.fill")
                .font(.body)
                .foregroundColor(speechRecognizer.isListening ? .red : .accentColor)
                .symbolEffect(.variableColor.iterative, isActive: speechRecognizer.isListening)
        }
        .onAppear {
            setupRecognizer()
        }
        .alert("Microphone Access Required", isPresented: $showPermissionAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Voice commands require microphone access.")
        }
    }

    private func setupRecognizer() {
        speechRecognizer.onRecognitionComplete = { transcript, confidence in
            guard !transcript.isEmpty else { return }
            let intent = VoiceIntentClassifier.classify(transcript)

            if confirmationFlow.isAwaitingConfirmation {
                Task {
                    await confirmationFlow.handleFollowUpIntent(intent)
                }
            } else {
                confirmationFlow.processIntent(intent, transcript: transcript)
            }
        }
    }

    private func toggleListening() {
        if speechRecognizer.isListening {
            speechRecognizer.stopListening()
        } else {
            Task {
                let authorized = await speechRecognizer.requestAuthorization()
                if authorized {
                    try? speechRecognizer.startListening()
                } else {
                    showPermissionAlert = true
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("Voice Command Button") {
    VStack(spacing: 40) {
        VoiceCommandButton()
        VoiceCommandButton(buttonSize: 44, pushToTalk: false)
        CompactVoiceCommandButton()
    }
    .padding()
    .environmentObject(VoiceConfirmationFlow())
}

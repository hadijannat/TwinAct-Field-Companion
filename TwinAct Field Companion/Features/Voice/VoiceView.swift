//
//  VoiceView.swift
//  TwinAct Field Companion
//
//  Main voice command interface with speech recognition,
//  intent classification, and confirmation flow.
//

import SwiftUI

// MARK: - Voice View

/// Main voice command interface for hands-free operation.
///
/// Provides:
/// - Push-to-talk voice command button
/// - Real-time transcript display
/// - Confirmation flow for data-modifying commands
/// - Voice command help
public struct VoiceView: View {

    // MARK: - State

    @StateObject private var speechRecognizer = SpeechRecognizer()
    @StateObject private var confirmationFlow: VoiceConfirmationFlow

    @State private var showConfirmationSheet = false
    @State private var showHelpSheet = false
    @State private var recentCommands: [RecentCommand] = []

    // MARK: - Initialization

    public init(auditService: PersistenceRepositoryProtocol? = nil) {
        _confirmationFlow = StateObject(wrappedValue: VoiceConfirmationFlow(auditService: auditService))
    }

    // MARK: - Body

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Transcript area
                transcriptArea
                    .frame(maxHeight: .infinity)

                Divider()

                // Recent commands
                if !recentCommands.isEmpty {
                    recentCommandsSection
                }

                // Voice command button area
                voiceCommandArea
            }
            .navigationTitle("Voice Commands")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showHelpSheet = true
                    } label: {
                        Image(systemName: "questionmark.circle")
                    }
                }
            }
            .sheet(isPresented: $showConfirmationSheet) {
                VoiceConfirmationSheet(flow: confirmationFlow)
            }
            .sheet(isPresented: $showHelpSheet) {
                VoiceCommandHelpSheet()
            }
            .onAppear {
                setupCallbacks()
            }
            .onChange(of: confirmationFlow.state) { _, newState in
                handleConfirmationStateChange(newState)
            }
        }
        .environmentObject(confirmationFlow)
    }

    // MARK: - Subviews

    private var transcriptArea: some View {
        VStack(spacing: 16) {
            if speechRecognizer.isListening {
                listeningView
            } else if !speechRecognizer.transcript.isEmpty {
                transcriptResultView
            } else {
                emptyStateView
            }
        }
        .padding()
    }

    private var listeningView: some View {
        VStack(spacing: 24) {
            // Audio visualization
            audioVisualization

            // Live transcript
            if !speechRecognizer.transcript.isEmpty {
                Text(speechRecognizer.transcript)
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.primary)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                Text("Listening...")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }

            // Confidence indicator
            if speechRecognizer.confidence > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "waveform")
                    Text("\(Int(speechRecognizer.confidence * 100))% confidence")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
        }
    }

    private var audioVisualization: some View {
        HStack(spacing: 4) {
            ForEach(0..<7, id: \.self) { index in
                AudioBarView(
                    level: audioLevelForBar(index),
                    isActive: speechRecognizer.isListening
                )
            }
        }
        .frame(height: 60)
    }

    private func audioLevelForBar(_ index: Int) -> Float {
        // Create a wave effect based on the audio level
        let baseLevel = speechRecognizer.audioLevel
        let offset = Float(index - 3) * 0.1
        let adjustedLevel = max(0.1, min(1.0, baseLevel + offset))
        return adjustedLevel
    }

    private var transcriptResultView: some View {
        VStack(spacing: 16) {
            Text("You said:")
                .font(.caption)
                .foregroundColor(.secondary)

            Text(speechRecognizer.transcript)
                .font(.title2)
                .multilineTextAlignment(.center)
                .padding()

            if let intent = classifyCurrentTranscript() {
                IntentPreviewView(intent: intent)
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "mic.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.accentColor.opacity(0.5))

            Text("Tap and hold to speak")
                .font(.title3)
                .foregroundColor(.secondary)

            Text("Voice commands allow hands-free operation in the field")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var recentCommandsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recent Commands")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(recentCommands) { command in
                        RecentCommandChip(command: command) {
                            replayCommand(command)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 12)
        .background(Color(.secondarySystemBackground))
    }

    private var voiceCommandArea: some View {
        VStack(spacing: 16) {
            // Status message
            if let error = speechRecognizer.error {
                Text(error.localizedDescription)
                    .font(.caption)
                    .foregroundColor(.red)
            } else if confirmationFlow.isExecuting {
                Text("Executing command...")
                    .font(.caption)
                    .foregroundColor(.orange)
            }

            // Voice command button
            VoiceCommandButton(buttonSize: 72, pushToTalk: true)
                .environmentObject(confirmationFlow)

            // Hint text
            Text(speechRecognizer.isListening ? "Release to process" : "Hold to speak")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .padding(.bottom, 16)
    }

    // MARK: - Helpers

    private func setupCallbacks() {
        speechRecognizer.onRecognitionComplete = { transcript, confidence in
            handleRecognitionComplete(transcript: transcript, confidence: confidence)
        }
    }

    private func handleRecognitionComplete(transcript: String, confidence: Float) {
        guard !transcript.isEmpty else { return }

        let intent = VoiceIntentClassifier.classify(transcript)

        // Add to recent commands
        let command = RecentCommand(
            transcript: transcript,
            intent: intent,
            timestamp: Date()
        )
        recentCommands.insert(command, at: 0)
        if recentCommands.count > 5 {
            recentCommands.removeLast()
        }

        // Process through confirmation flow
        if confirmationFlow.isAwaitingConfirmation {
            Task {
                await confirmationFlow.handleFollowUpIntent(intent)
            }
        } else {
            confirmationFlow.processIntent(intent, transcript: transcript)
        }
    }

    private func handleConfirmationStateChange(_ state: VoiceConfirmationState) {
        switch state {
        case .awaitingConfirmation:
            showConfirmationSheet = true
        case .completed, .cancelled, .timedOut:
            // Sheet will auto-dismiss
            break
        default:
            break
        }
    }

    private func classifyCurrentTranscript() -> VoiceIntent? {
        guard !speechRecognizer.transcript.isEmpty else { return nil }
        return VoiceIntentClassifier.classify(speechRecognizer.transcript)
    }

    private func replayCommand(_ command: RecentCommand) {
        confirmationFlow.processIntent(command.intent, transcript: command.transcript)
    }
}

// MARK: - Audio Bar View

/// Individual bar in the audio visualization
private struct AudioBarView: View {
    let level: Float
    let isActive: Bool

    @State private var animatedLevel: CGFloat = 0.1

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(Color.accentColor)
            .frame(width: 6, height: 10 + animatedLevel * 50)
            .animation(.easeInOut(duration: 0.1), value: animatedLevel)
            .onChange(of: level) { _, newValue in
                animatedLevel = CGFloat(newValue)
            }
            .onChange(of: isActive) { _, active in
                if !active {
                    animatedLevel = 0.1
                }
            }
    }
}

// MARK: - Recent Command

/// Model for a recent voice command
private struct RecentCommand: Identifiable {
    let id = UUID()
    let transcript: String
    let intent: VoiceIntent
    let timestamp: Date

    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }
}

// MARK: - Recent Command Chip

/// Chip view for displaying a recent command
private struct RecentCommandChip: View {
    let command: RecentCommand
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Image(systemName: command.intent.iconName)
                    .font(.caption)

                Text(command.transcript)
                    .font(.caption)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.accentColor.opacity(0.1))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Voice Command Overlay

/// Floating voice command button overlay for use in other views
public struct VoiceCommandOverlay: View {
    @EnvironmentObject private var confirmationFlow: VoiceConfirmationFlow

    @State private var showConfirmationSheet = false

    public init() {}

    public var body: some View {
        VStack {
            Spacer()

            HStack {
                Spacer()

                VoiceCommandButton(buttonSize: 56, pushToTalk: true)
                    .padding(.trailing, 16)
                    .padding(.bottom, 100) // Above tab bar
            }
        }
        .sheet(isPresented: $showConfirmationSheet) {
            VoiceConfirmationSheet(flow: confirmationFlow)
        }
        .onChange(of: confirmationFlow.state) { _, newState in
            if case .awaitingConfirmation = newState {
                showConfirmationSheet = true
            }
        }
    }
}

// MARK: - Preview

#Preview("Voice View") {
    VoiceView()
}

#Preview("Voice Command Overlay") {
    ZStack {
        Color(.systemBackground)
            .ignoresSafeArea()

        Text("Main Content")

        VoiceCommandOverlay()
    }
    .environmentObject(VoiceConfirmationFlow())
}

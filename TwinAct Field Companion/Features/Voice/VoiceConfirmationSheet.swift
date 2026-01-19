//
//  VoiceConfirmationSheet.swift
//  TwinAct Field Companion
//
//  Confirmation dialog for voice commands.
//  Displays intent preview and confirmation options with countdown timer.
//

import SwiftUI

// MARK: - Voice Confirmation Sheet

/// Sheet for confirming voice commands before execution.
///
/// Shows the interpreted intent, allows confirmation/cancellation,
/// and includes a countdown timer for auto-cancellation.
public struct VoiceConfirmationSheet: View {

    // MARK: - Properties

    @ObservedObject var flow: VoiceConfirmationFlow
    @Environment(\.dismiss) private var dismiss

    @StateObject private var speechRecognizer = SpeechRecognizer()
    @State private var isListeningForConfirmation = false

    // MARK: - Body

    public var body: some View {
        VStack(spacing: 24) {
            // Header with state indicator
            headerView

            // Intent visualization
            if let intent = flow.pendingIntent {
                IntentPreviewView(intent: intent)
            }

            // Confirmation message
            Text(flow.confirmationMessage)
                .font(.headline)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            // State-specific content
            stateContent

            Spacer()
        }
        .padding()
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(flow.isExecuting)
        .onAppear {
            setupVoiceConfirmation()
        }
        .onChange(of: flow.state) { _, newState in
            handleStateChange(newState)
        }
    }

    // MARK: - Subviews

    private var headerView: some View {
        HStack {
            // State icon
            Image(systemName: stateIcon)
                .font(.title2)
                .foregroundColor(stateColor)
                .symbolEffect(.pulse, isActive: flow.isAwaitingConfirmation)

            Text(stateTitle)
                .font(.title3.bold())

            Spacer()

            // Countdown timer (when awaiting confirmation)
            if flow.isAwaitingConfirmation && flow.timeRemaining > 0 {
                countdownView
            }
        }
    }

    private var countdownView: some View {
        HStack(spacing: 4) {
            Image(systemName: "clock.fill")
                .font(.caption)
            Text("\(flow.timeRemaining)s")
                .font(.caption.monospacedDigit())
        }
        .foregroundColor(flow.timeRemaining <= 3 ? .red : .secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.secondary.opacity(0.1))
        .clipShape(Capsule())
    }

    @ViewBuilder
    private var stateContent: some View {
        switch flow.state {
        case .awaitingConfirmation:
            confirmationButtons

        case .confirmed, .executing:
            executingView

        case .completed(let success, let message):
            completedView(success: success, message: message)

        case .cancelled:
            cancelledView

        case .timedOut:
            timedOutView

        case .idle:
            EmptyView()
        }
    }

    private var confirmationButtons: some View {
        VStack(spacing: 16) {
            // Action buttons
            HStack(spacing: 20) {
                Button(role: .cancel) {
                    flow.cancel()
                } label: {
                    Label("Cancel", systemImage: "xmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                Button {
                    Task {
                        await flow.confirm()
                    }
                } label: {
                    Label("Confirm", systemImage: "checkmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }

            // Voice confirmation hint
            HStack(spacing: 8) {
                if isListeningForConfirmation {
                    Image(systemName: "waveform")
                        .foregroundColor(.accentColor)
                        .symbolEffect(.variableColor.iterative)
                } else {
                    Image(systemName: "mic.fill")
                        .foregroundColor(.secondary)
                }

                Text(isListeningForConfirmation ? "Listening..." : "Say 'yes' or 'no'")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 8)
        }
    }

    private var executingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)

            Text("Executing...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    private func completedView(success: Bool, message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: success ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(success ? .green : .red)
                .symbolEffect(.bounce, value: success)

            Text(message)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            Button("Done") {
                flow.reset()
                dismiss()
            }
            .buttonStyle(.bordered)
            .padding(.top, 8)
        }
    }

    private var cancelledView: some View {
        VStack(spacing: 16) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(.orange)

            Text("Command cancelled")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    private var timedOutView: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.badge.xmark.fill")
                .font(.system(size: 48))
                .foregroundColor(.orange)

            Text("Confirmation timed out")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - State Properties

    private var stateIcon: String {
        switch flow.state {
        case .awaitingConfirmation:
            return "questionmark.circle.fill"
        case .confirmed, .executing:
            return "arrow.triangle.2.circlepath"
        case .completed(let success, _):
            return success ? "checkmark.circle.fill" : "xmark.circle.fill"
        case .cancelled:
            return "xmark.circle.fill"
        case .timedOut:
            return "clock.badge.xmark.fill"
        case .idle:
            return "circle"
        }
    }

    private var stateColor: Color {
        switch flow.state {
        case .awaitingConfirmation:
            return .blue
        case .confirmed, .executing:
            return .orange
        case .completed(let success, _):
            return success ? .green : .red
        case .cancelled, .timedOut:
            return .orange
        case .idle:
            return .gray
        }
    }

    private var stateTitle: String {
        switch flow.state {
        case .awaitingConfirmation:
            return "Confirm Command"
        case .confirmed, .executing:
            return "Executing"
        case .completed(let success, _):
            return success ? "Completed" : "Failed"
        case .cancelled:
            return "Cancelled"
        case .timedOut:
            return "Timed Out"
        case .idle:
            return "Ready"
        }
    }

    // MARK: - Voice Confirmation

    private func setupVoiceConfirmation() {
        speechRecognizer.onRecognitionComplete = { transcript, _ in
            handleVoiceConfirmation(transcript)
        }

        // Start listening for voice confirmation
        Task {
            let authorized = await speechRecognizer.requestAuthorization()
            if authorized {
                try? speechRecognizer.startListening()
                isListeningForConfirmation = true
            }
        }
    }

    private func handleVoiceConfirmation(_ transcript: String) {
        isListeningForConfirmation = false

        let intent = VoiceIntentClassifier.classify(transcript)

        Task {
            await flow.handleFollowUpIntent(intent)
        }
    }

    private func handleStateChange(_ newState: VoiceConfirmationState) {
        // Stop listening when no longer awaiting confirmation
        if case .awaitingConfirmation = newState {
            // Still awaiting, keep listening
        } else {
            speechRecognizer.stopListening()
            isListeningForConfirmation = false
        }

        // Auto-dismiss on completion after delay
        switch newState {
        case .completed, .cancelled, .timedOut:
            Task {
                try? await Task.sleep(for: .seconds(2))
                await MainActor.run {
                    dismiss()
                }
            }
        default:
            break
        }
    }
}

// MARK: - Intent Preview View

/// Visual preview of a voice intent
public struct IntentPreviewView: View {
    let intent: VoiceIntent

    public var body: some View {
        HStack(spacing: 16) {
            // Intent icon
            Image(systemName: intent.iconName)
                .font(.title)
                .foregroundColor(.accentColor)
                .frame(width: 44, height: 44)
                .background(Color.accentColor.opacity(0.1))
                .clipShape(Circle())

            // Intent details
            VStack(alignment: .leading, spacing: 4) {
                Text(intentType)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)

                Text(intentSummary)
                    .font(.body)
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var intentType: String {
        switch intent {
        case .createServiceRequest:
            return "Create Request"
        case .updateStatus:
            return "Update Status"
        case .addNote:
            return "Add Note"
        case .startMaintenance:
            return "Maintenance"
        case .markStepComplete, .goToStep:
            return "Maintenance Step"
        case .navigateTo:
            return "Navigation"
        case .search:
            return "Search"
        case .startScan:
            return "Scan"
        case .confirm, .cancel:
            return "Confirmation"
        case .help:
            return "Help"
        case .readStatus:
            return "Status"
        case .unknown:
            return "Unknown"
        }
    }

    private var intentSummary: String {
        switch intent {
        case .createServiceRequest(let title, let category):
            if let title = title {
                return title
            }
            if let category = category {
                return category.displayName
            }
            return "New service request"

        case .updateStatus(_, let status):
            return status.displayName

        case .addNote(_, let note):
            return note.count > 60 ? String(note.prefix(60)) + "..." : note

        case .startMaintenance(let id):
            return id ?? "Start procedure"

        case .markStepComplete(let step):
            return step == 0 ? "Current step" : "Step \(step)"

        case .goToStep(let step):
            return "Step \(step)"

        case .navigateTo(let screen):
            return screen.displayName

        case .search(let query):
            return query

        case .startScan:
            return "QR Code"

        case .confirm:
            return "Yes"

        case .cancel:
            return "No"

        case .help:
            return "Voice commands"

        case .readStatus:
            return "Current status"

        case .unknown(let transcript):
            return transcript
        }
    }
}

// MARK: - Voice Command Help Sheet

/// Help sheet showing available voice commands
public struct VoiceCommandHelpSheet: View {

    @Environment(\.dismiss) private var dismiss

    public init() {}

    public var body: some View {
        NavigationStack {
            List {
                Section("Service Requests") {
                    commandRow("Create request", example: "Create a maintenance request")
                    commandRow("Update status", example: "Mark as complete")
                    commandRow("Add note", example: "Add note checking oil level")
                }

                Section("Maintenance") {
                    commandRow("Start maintenance", example: "Start maintenance procedure")
                    commandRow("Complete step", example: "Mark step 3 complete")
                    commandRow("Next step", example: "Next / Done")
                }

                Section("Navigation") {
                    commandRow("Go to screen", example: "Go to scanner")
                    commandRow("Search", example: "Search for pump")
                    commandRow("Start scan", example: "Scan QR code")
                }

                Section("Confirmation") {
                    commandRow("Confirm", example: "Yes / Confirm / Proceed")
                    commandRow("Cancel", example: "No / Cancel / Stop")
                }

                Section("Other") {
                    commandRow("Help", example: "Help / What can I say")
                    commandRow("Status", example: "Read status")
                }
            }
            .navigationTitle("Voice Commands")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func commandRow(_ command: String, example: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(command)
                .font(.headline)

            Text("\"\(example)\"")
                .font(.caption)
                .foregroundColor(.secondary)
                .italic()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

#Preview("Confirmation Sheet") {
    let flow = VoiceConfirmationFlow()
    flow.processIntent(
        .createServiceRequest(title: "Oil leak detected", category: .repair),
        transcript: "create repair request oil leak detected"
    )

    return VoiceConfirmationSheet(flow: flow)
}

#Preview("Intent Preview") {
    VStack(spacing: 16) {
        IntentPreviewView(intent: .createServiceRequest(title: "Pump maintenance", category: .maintenance))
        IntentPreviewView(intent: .updateStatus(requestId: nil, newStatus: .resolved))
        IntentPreviewView(intent: .navigateTo(screen: .technician))
    }
    .padding()
}

#Preview("Help Sheet") {
    VoiceCommandHelpSheet()
}

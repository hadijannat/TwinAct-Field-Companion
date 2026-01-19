//
//  VoiceConfirmationFlow.swift
//  TwinAct Field Companion
//
//  Manages voice command confirmation flow with safety confirmations.
//  All voice commands that modify data require explicit confirmation before execution.
//

import Foundation
import Combine

// MARK: - Confirmation State

/// State of the voice command confirmation flow
public enum VoiceConfirmationState: Equatable {
    /// No active command
    case idle

    /// Waiting for user confirmation
    case awaitingConfirmation(intent: VoiceIntent)

    /// User confirmed the action
    case confirmed

    /// User cancelled the action
    case cancelled

    /// Action is being executed
    case executing

    /// Action completed (success or failure)
    case completed(success: Bool, message: String)

    /// Timed out waiting for confirmation
    case timedOut
}

// MARK: - Execution Result

/// Result of executing a voice command
public struct VoiceCommandResult: Sendable {
    public let success: Bool
    public let message: String
    public let entityId: String?

    public init(success: Bool, message: String, entityId: String? = nil) {
        self.success = success
        self.message = message
        self.entityId = entityId
    }

    public static func success(_ message: String, entityId: String? = nil) -> VoiceCommandResult {
        VoiceCommandResult(success: true, message: message, entityId: entityId)
    }

    public static func failure(_ message: String) -> VoiceCommandResult {
        VoiceCommandResult(success: false, message: message)
    }
}

// MARK: - Voice Confirmation Flow

/// Manages voice command confirmation flow with timeout and audit logging.
///
/// Provides a safety layer between voice command recognition and execution.
/// All commands that modify data require explicit user confirmation.
///
/// ## Usage
/// ```swift
/// let flow = VoiceConfirmationFlow(auditService: persistence)
/// flow.processIntent(.createServiceRequest(...), transcript: "create request")
/// // Wait for confirmation
/// await flow.confirm()
/// ```
@MainActor
public final class VoiceConfirmationFlow: ObservableObject {

    // MARK: - Published Properties

    /// Current state of the confirmation flow
    @Published public private(set) var state: VoiceConfirmationState = .idle

    /// The pending intent awaiting confirmation
    @Published public private(set) var pendingIntent: VoiceIntent?

    /// Human-readable confirmation message
    @Published public private(set) var confirmationMessage: String = ""

    /// Original transcript that generated the intent
    @Published public private(set) var originalTranscript: String = ""

    /// Time remaining for confirmation (seconds)
    @Published public private(set) var timeRemaining: Int = 0

    // MARK: - Private Properties

    private let auditService: PersistenceRepositoryProtocol?
    private var confirmationTimeout: Task<Void, Never>?
    private var countdownTimer: Timer?

    /// Timeout duration in seconds
    public let timeoutDuration: Int

    /// Callback for executing intents
    public var intentExecutor: ((VoiceIntent) async -> VoiceCommandResult)?

    // MARK: - Initialization

    /// Initialize with an audit service for logging
    /// - Parameters:
    ///   - auditService: Service for audit logging (optional)
    ///   - timeoutDuration: Seconds before auto-cancellation (default: 10)
    public init(
        auditService: PersistenceRepositoryProtocol? = nil,
        timeoutDuration: Int = 10
    ) {
        self.auditService = auditService
        self.timeoutDuration = timeoutDuration
    }

    // MARK: - Public API

    /// Process an intent and request confirmation if needed
    /// - Parameters:
    ///   - intent: The classified voice intent
    ///   - transcript: The original speech transcript
    public func processIntent(_ intent: VoiceIntent, transcript: String) {
        // Cancel any existing flow
        cancelConfirmationTimeout()

        // Store the intent and transcript
        pendingIntent = intent
        originalTranscript = transcript

        // Log the voice command
        logVoiceCommand(transcript: transcript, intent: intent)

        // Check if this intent requires confirmation
        if intent.requiresConfirmation {
            // Generate confirmation message
            confirmationMessage = generateConfirmationMessage(for: intent)

            // Move to awaiting confirmation state
            state = .awaitingConfirmation(intent: intent)

            // Start confirmation timeout
            startConfirmationTimeout()
        } else {
            // Execute immediately for non-confirmation intents
            Task {
                await executeIntentDirectly(intent)
            }
        }
    }

    /// Confirm the pending intent and execute it
    public func confirm() async {
        guard let intent = pendingIntent else {
            state = .idle
            return
        }

        // Cancel timeout
        cancelConfirmationTimeout()

        // Update state
        state = .confirmed

        // Log confirmation
        logConfirmation(confirmed: true)

        // Execute the intent
        state = .executing

        let result = await executeIntent(intent)

        // Update final state
        state = .completed(success: result.success, message: result.message)

        // Clear pending intent after short delay
        Task {
            try? await Task.sleep(for: .seconds(3))
            await MainActor.run {
                if case .completed = self.state {
                    self.reset()
                }
            }
        }
    }

    /// Cancel the pending intent
    public func cancel() {
        cancelConfirmationTimeout()

        // Log cancellation
        logConfirmation(confirmed: false)

        state = .cancelled
        pendingIntent = nil
        confirmationMessage = ""

        // Reset after short delay
        Task {
            try? await Task.sleep(for: .seconds(1))
            await MainActor.run {
                if case .cancelled = self.state {
                    self.reset()
                }
            }
        }
    }

    /// Reset to idle state
    public func reset() {
        cancelConfirmationTimeout()
        state = .idle
        pendingIntent = nil
        confirmationMessage = ""
        originalTranscript = ""
        timeRemaining = 0
    }

    /// Handle a follow-up voice intent (for confirmation via voice)
    /// - Parameter intent: The follow-up intent
    public func handleFollowUpIntent(_ intent: VoiceIntent) async {
        switch intent {
        case .confirm:
            await confirm()
        case .cancel:
            cancel()
        default:
            // If a different command is spoken, cancel current and process new
            cancel()
            processIntent(intent, transcript: "")
        }
    }

    // MARK: - Confirmation Message Generation

    private func generateConfirmationMessage(for intent: VoiceIntent) -> String {
        switch intent {
        case .createServiceRequest(let title, let category):
            var message = "Create"
            if let category = category {
                message += " a \(category.displayName.lowercased())"
            } else {
                message += " a service"
            }
            message += " request"
            if let title = title {
                message += " titled \"\(title)\""
            }
            return message + "?"

        case .updateStatus(let requestId, let status):
            var message = "Change status to \(status.displayName)"
            if let id = requestId {
                message += " for request \(id)"
            }
            return message + "?"

        case .addNote(let requestId, let note):
            var message = "Add note"
            if let id = requestId {
                message += " to request \(id)"
            }
            // Truncate long notes in confirmation
            let displayNote = note.count > 50 ? String(note.prefix(50)) + "..." : note
            return message + ": \"\(displayNote)\"?"

        case .startMaintenance(let instructionId):
            if let id = instructionId {
                return "Start maintenance procedure \(id)?"
            }
            return "Start maintenance procedure?"

        case .markStepComplete(let stepNumber):
            if stepNumber == 0 {
                return "Mark current step as complete?"
            }
            return "Mark step \(stepNumber) as complete?"

        case .goToStep(let stepNumber):
            return "Skip to step \(stepNumber)?"

        case .navigateTo(let screen):
            return "Navigate to \(screen.displayName)?"

        case .search(let query):
            return "Search for \"\(query)\"?"

        case .startScan:
            return "Start QR code scan?"

        case .confirm, .cancel, .help, .readStatus, .unknown:
            return ""
        }
    }

    // MARK: - Intent Execution

    private func executeIntent(_ intent: VoiceIntent) async -> VoiceCommandResult {
        // If an executor is provided, use it
        if let executor = intentExecutor {
            return await executor(intent)
        }

        // Default execution (placeholder)
        return await defaultExecuteIntent(intent)
    }

    private func executeIntentDirectly(_ intent: VoiceIntent) async {
        // For non-confirmation intents, execute immediately
        if let executor = intentExecutor {
            let result = await executor(intent)
            state = .completed(success: result.success, message: result.message)
        } else {
            state = .completed(success: true, message: intent.displayDescription)
        }

        // Auto-reset after short delay
        Task {
            try? await Task.sleep(for: .seconds(2))
            await MainActor.run {
                if case .completed = self.state {
                    self.reset()
                }
            }
        }
    }

    private func defaultExecuteIntent(_ intent: VoiceIntent) async -> VoiceCommandResult {
        // Simulate execution delay
        try? await Task.sleep(for: .milliseconds(500))

        switch intent {
        case .createServiceRequest(let title, let category):
            let categoryName = category?.displayName ?? "Service"
            let requestTitle = title ?? "New Request"
            return .success("Created \(categoryName) request: \(requestTitle)", entityId: UUID().uuidString)

        case .updateStatus(_, let status):
            return .success("Status updated to \(status.displayName)")

        case .addNote(_, _):
            return .success("Note added successfully")

        case .markStepComplete(let step):
            if step == 0 {
                return .success("Current step marked complete")
            }
            return .success("Step \(step) marked complete")

        case .goToStep(let step):
            return .success("Moved to step \(step)")

        case .navigateTo(let screen):
            return .success("Navigated to \(screen.displayName)")

        case .search(let query):
            return .success("Searching for \"\(query)\"")

        case .startScan:
            return .success("Scanner activated")

        case .startMaintenance(let instructionId):
            if let id = instructionId {
                return .success("Started maintenance: \(id)")
            }
            return .success("Maintenance mode started")

        case .help:
            return .success("Voice commands: create request, update status, add note, mark complete, go to [screen]")

        case .readStatus:
            return .success("Current status retrieved")

        case .confirm, .cancel:
            return .success("Action processed")

        case .unknown(let transcript):
            return .failure("Unrecognized command: \(transcript)")
        }
    }

    // MARK: - Timeout Management

    private func startConfirmationTimeout() {
        timeRemaining = timeoutDuration

        // Start countdown timer
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                self.timeRemaining -= 1

                if self.timeRemaining <= 0 {
                    self.handleTimeout()
                }
            }
        }

        // Also set up a safety task
        confirmationTimeout = Task {
            try? await Task.sleep(for: .seconds(timeoutDuration))

            await MainActor.run {
                if case .awaitingConfirmation = self.state {
                    self.handleTimeout()
                }
            }
        }
    }

    private func cancelConfirmationTimeout() {
        confirmationTimeout?.cancel()
        confirmationTimeout = nil
        countdownTimer?.invalidate()
        countdownTimer = nil
        timeRemaining = 0
    }

    private func handleTimeout() {
        cancelConfirmationTimeout()

        // Log timeout
        logTimeout()

        state = .timedOut
        pendingIntent = nil
        confirmationMessage = ""

        // Reset after short delay
        Task {
            try? await Task.sleep(for: .seconds(2))
            await MainActor.run {
                if case .timedOut = self.state {
                    self.reset()
                }
            }
        }
    }

    // MARK: - Audit Logging

    private func logVoiceCommand(transcript: String, intent: VoiceIntent) {
        guard let auditService = auditService else { return }

        Task {
            let entry = AuditEntry(
                actionType: .voiceCommandExecuted,
                entityType: "VoiceCommand",
                details: "Intent: \(intent.displayDescription)"
            )
            entry.transcription = transcript

            try? await auditService.addAuditEntry(entry)
        }
    }

    private func logConfirmation(confirmed: Bool) {
        guard let auditService = auditService, let intent = pendingIntent else { return }

        Task {
            let entry = AuditEntry(
                actionType: confirmed ? .voiceCommandExecuted : .voiceCommandFailed,
                entityType: "VoiceCommand",
                details: confirmed ? "Confirmed: \(intent.displayDescription)" : "Cancelled: \(intent.displayDescription)"
            )
            entry.transcription = originalTranscript

            try? await auditService.addAuditEntry(entry)
        }
    }

    private func logTimeout() {
        guard let auditService = auditService, let intent = pendingIntent else { return }

        Task {
            let entry = AuditEntry(
                actionType: .voiceCommandFailed,
                entityType: "VoiceCommand",
                details: "Timed out: \(intent.displayDescription)"
            )
            entry.transcription = originalTranscript

            try? await auditService.addAuditEntry(entry)
        }
    }
}

// MARK: - Voice Confirmation Flow + Convenience

extension VoiceConfirmationFlow {
    /// Whether the flow is currently active (not idle)
    public var isActive: Bool {
        if case .idle = state {
            return false
        }
        return true
    }

    /// Whether confirmation is being awaited
    public var isAwaitingConfirmation: Bool {
        if case .awaitingConfirmation = state {
            return true
        }
        return false
    }

    /// Whether an action is currently executing
    public var isExecuting: Bool {
        if case .executing = state {
            return true
        }
        return false
    }
}

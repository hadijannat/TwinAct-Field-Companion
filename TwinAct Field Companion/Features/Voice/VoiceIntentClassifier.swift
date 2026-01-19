//
//  VoiceIntentClassifier.swift
//  TwinAct Field Companion
//
//  Classifies transcribed speech into actionable intents for voice commands.
//  Uses pattern matching to identify command types and extract parameters.
//

import Foundation

// MARK: - Voice Intent

/// Represents a classified intent from voice input
public enum VoiceIntent: Equatable, Sendable {

    // MARK: - Service Request Intents

    /// Create a new service request
    case createServiceRequest(title: String?, category: ServiceRequestCategory?)

    /// Update the status of a service request
    case updateStatus(requestId: String?, newStatus: ServiceRequestStatus)

    /// Add a note to a service request
    case addNote(requestId: String?, note: String)

    // MARK: - Maintenance Intents

    /// Start a maintenance procedure
    case startMaintenance(instructionId: String?)

    /// Mark a maintenance step as complete
    case markStepComplete(stepNumber: Int)

    /// Skip to a specific step
    case goToStep(stepNumber: Int)

    // MARK: - Navigation Intents

    /// Navigate to a specific screen
    case navigateTo(screen: NavigationTarget)

    /// Search for assets or content
    case search(query: String)

    /// Scan a QR code
    case startScan

    // MARK: - Confirmation Intents

    /// Confirm the pending action
    case confirm

    /// Cancel the pending action
    case cancel

    // MARK: - Help & Utility

    /// Request help information
    case help

    /// Read current status
    case readStatus

    /// Unknown intent with original transcript
    case unknown(transcript: String)

    // MARK: - Properties

    /// Whether this intent requires confirmation before execution
    public var requiresConfirmation: Bool {
        switch self {
        case .createServiceRequest, .updateStatus, .addNote, .markStepComplete:
            return true
        case .navigateTo, .search, .startScan, .help, .readStatus, .startMaintenance, .goToStep:
            return false
        case .confirm, .cancel, .unknown:
            return false
        }
    }

    /// Human-readable description of the intent
    public var displayDescription: String {
        switch self {
        case .createServiceRequest(let title, let category):
            var desc = "Create service request"
            if let category = category {
                desc += " for \(category.displayName.lowercased())"
            }
            if let title = title {
                desc += ": \(title)"
            }
            return desc

        case .updateStatus(_, let status):
            return "Update status to \(status.displayName)"

        case .addNote(_, let note):
            return "Add note: \(note)"

        case .startMaintenance(let instructionId):
            if let id = instructionId {
                return "Start maintenance: \(id)"
            }
            return "Start maintenance procedure"

        case .markStepComplete(let step):
            return "Mark step \(step) complete"

        case .goToStep(let step):
            return "Go to step \(step)"

        case .navigateTo(let screen):
            return "Navigate to \(screen.displayName)"

        case .search(let query):
            return "Search for \"\(query)\""

        case .startScan:
            return "Start QR scan"

        case .confirm:
            return "Confirm action"

        case .cancel:
            return "Cancel action"

        case .help:
            return "Show help"

        case .readStatus:
            return "Read current status"

        case .unknown(let transcript):
            return "Unknown command: \(transcript)"
        }
    }

    /// Icon name for the intent
    public var iconName: String {
        switch self {
        case .createServiceRequest:
            return "plus.circle.fill"
        case .updateStatus:
            return "arrow.triangle.2.circlepath"
        case .addNote:
            return "note.text"
        case .startMaintenance:
            return "wrench.and.screwdriver.fill"
        case .markStepComplete:
            return "checkmark.circle.fill"
        case .goToStep:
            return "forward.fill"
        case .navigateTo:
            return "arrow.right.circle.fill"
        case .search:
            return "magnifyingglass"
        case .startScan:
            return "qrcode.viewfinder"
        case .confirm:
            return "checkmark"
        case .cancel:
            return "xmark"
        case .help:
            return "questionmark.circle"
        case .readStatus:
            return "speaker.wave.2"
        case .unknown:
            return "questionmark"
        }
    }
}

// MARK: - Navigation Target

/// Navigation targets for voice commands
public enum NavigationTarget: String, Equatable, Sendable, CaseIterable {
    case scanner
    case passport
    case technician
    case settings
    case serviceRequests
    case maintenance
    case documents

    /// Human-readable display name
    public var displayName: String {
        switch self {
        case .scanner: return "Scanner"
        case .passport: return "Passport"
        case .technician: return "Technician Console"
        case .settings: return "Settings"
        case .serviceRequests: return "Service Requests"
        case .maintenance: return "Maintenance"
        case .documents: return "Documents"
        }
    }

    /// Keywords that match this navigation target
    var keywords: [String] {
        switch self {
        case .scanner:
            return ["scanner", "scan", "qr", "qr code", "camera"]
        case .passport:
            return ["passport", "asset", "nameplate", "identity"]
        case .technician:
            return ["technician", "tech", "console", "work"]
        case .settings:
            return ["settings", "preferences", "options", "config"]
        case .serviceRequests:
            return ["service", "requests", "tickets", "issues"]
        case .maintenance:
            return ["maintenance", "repair", "procedure", "instructions"]
        case .documents:
            return ["documents", "docs", "files", "manuals"]
        }
    }
}

// MARK: - Voice Intent Classifier

/// Classifies transcribed speech into actionable intents.
///
/// Uses rule-based pattern matching to identify commands and extract
/// parameters from natural language input.
///
/// ## Supported Commands
/// - Service requests: "create request", "update status", "add note"
/// - Maintenance: "start maintenance", "mark step complete"
/// - Navigation: "go to", "open", "show"
/// - Confirmation: "yes", "no", "confirm", "cancel"
/// - Help: "help", "what can I say"
public struct VoiceIntentClassifier {

    // MARK: - Classification

    /// Classify a transcript into an intent
    /// - Parameter transcript: The transcribed speech text
    /// - Returns: The classified intent
    public static func classify(_ transcript: String) -> VoiceIntent {
        let text = transcript.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // Empty transcript
        guard !text.isEmpty else {
            return .unknown(transcript: transcript)
        }

        // Check for confirmation/cancellation first (highest priority)
        if let confirmIntent = classifyConfirmation(text) {
            return confirmIntent
        }

        // Check for help
        if isHelpRequest(text) {
            return .help
        }

        // Check for status read
        if isStatusRead(text) {
            return .readStatus
        }

        // Check for navigation
        if let navIntent = classifyNavigation(text) {
            return navIntent
        }

        // Check for service request commands
        if let serviceIntent = classifyServiceRequest(text) {
            return serviceIntent
        }

        // Check for maintenance commands
        if let maintenanceIntent = classifyMaintenance(text) {
            return maintenanceIntent
        }

        // Check for search
        if let searchIntent = classifySearch(text) {
            return searchIntent
        }

        // Check for scan
        if isScanRequest(text) {
            return .startScan
        }

        return .unknown(transcript: transcript)
    }

    // MARK: - Confirmation Classification

    private static func classifyConfirmation(_ text: String) -> VoiceIntent? {
        let confirmPhrases = ["yes", "confirm", "okay", "ok", "proceed", "do it", "go ahead", "affirmative", "correct", "that's right", "sure"]
        let cancelPhrases = ["no", "cancel", "stop", "nevermind", "never mind", "abort", "don't", "negative", "wait", "hold on"]

        for phrase in confirmPhrases {
            if text == phrase || text.hasPrefix(phrase + " ") || text.hasSuffix(" " + phrase) {
                return .confirm
            }
        }

        for phrase in cancelPhrases {
            if text == phrase || text.hasPrefix(phrase + " ") || text.hasSuffix(" " + phrase) {
                return .cancel
            }
        }

        return nil
    }

    // MARK: - Help Classification

    private static func isHelpRequest(_ text: String) -> Bool {
        let helpPhrases = ["help", "what can i say", "what commands", "show commands", "list commands", "voice commands"]
        return helpPhrases.contains(where: { text.contains($0) })
    }

    // MARK: - Status Read Classification

    private static func isStatusRead(_ text: String) -> Bool {
        let statusPhrases = ["read status", "what's the status", "current status", "status update"]
        return statusPhrases.contains(where: { text.contains($0) })
    }

    // MARK: - Navigation Classification

    private static func classifyNavigation(_ text: String) -> VoiceIntent? {
        let navPrefixes = ["go to", "open", "show", "navigate to", "take me to", "switch to"]

        for prefix in navPrefixes {
            if text.hasPrefix(prefix) {
                let destination = String(text.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
                if let target = extractNavigationTarget(from: destination) {
                    return .navigateTo(screen: target)
                }
            }
        }

        // Also check for direct navigation targets
        for target in NavigationTarget.allCases {
            for keyword in target.keywords {
                if text == keyword || text == "the \(keyword)" {
                    return .navigateTo(screen: target)
                }
            }
        }

        return nil
    }

    private static func extractNavigationTarget(from text: String) -> NavigationTarget? {
        let lowercased = text.lowercased()

        for target in NavigationTarget.allCases {
            for keyword in target.keywords {
                if lowercased.contains(keyword) {
                    return target
                }
            }
        }

        return nil
    }

    // MARK: - Service Request Classification

    private static func classifyServiceRequest(_ text: String) -> VoiceIntent? {
        // Create service request
        let createPatterns = ["create request", "new request", "create service request", "new service request", "create a request", "create a service request", "submit request", "file request", "log request"]

        for pattern in createPatterns {
            if text.contains(pattern) {
                let category = extractCategory(from: text)
                let title = extractTitle(from: text, afterPattern: pattern)
                return .createServiceRequest(title: title, category: category)
            }
        }

        // Update status
        let updatePatterns = ["update status", "change status", "set status", "mark as"]

        for pattern in updatePatterns {
            if text.contains(pattern) {
                if let status = extractStatus(from: text) {
                    return .updateStatus(requestId: nil, newStatus: status)
                }
            }
        }

        // Mark complete
        if text.contains("mark complete") || text.contains("mark as complete") || text.contains("mark resolved") {
            return .updateStatus(requestId: nil, newStatus: .resolved)
        }

        // Add note
        let notePatterns = ["add note", "add a note", "note that", "record note"]

        for pattern in notePatterns {
            if text.contains(pattern) {
                let note = extractNote(from: text, afterPattern: pattern)
                if !note.isEmpty {
                    return .addNote(requestId: nil, note: note)
                }
            }
        }

        return nil
    }

    // MARK: - Maintenance Classification

    private static func classifyMaintenance(_ text: String) -> VoiceIntent? {
        // Start maintenance
        let startPatterns = ["start maintenance", "begin maintenance", "start procedure", "begin procedure"]

        for pattern in startPatterns {
            if text.contains(pattern) {
                // Extract instruction ID if mentioned
                let instructionId = extractInstructionId(from: text)
                return .startMaintenance(instructionId: instructionId)
            }
        }

        // Mark step complete
        let stepCompletePatterns = ["step complete", "completed step", "finish step", "done with step", "mark step", "complete step"]

        for pattern in stepCompletePatterns {
            if text.contains(pattern) {
                if let stepNumber = extractStepNumber(from: text) {
                    return .markStepComplete(stepNumber: stepNumber)
                }
            }
        }

        // Simple "done" or "next" for step completion
        if text == "done" || text == "next" || text == "next step" || text == "complete" {
            return .markStepComplete(stepNumber: 0) // 0 indicates current step
        }

        // Go to step
        let goToPatterns = ["go to step", "skip to step", "jump to step"]

        for pattern in goToPatterns {
            if text.contains(pattern) {
                if let stepNumber = extractStepNumber(from: text) {
                    return .goToStep(stepNumber: stepNumber)
                }
            }
        }

        return nil
    }

    // MARK: - Search Classification

    private static func classifySearch(_ text: String) -> VoiceIntent? {
        let searchPrefixes = ["search for", "search", "find", "look for", "locate"]

        for prefix in searchPrefixes {
            if text.hasPrefix(prefix) {
                let query = String(text.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
                if !query.isEmpty {
                    return .search(query: query)
                }
            }
        }

        return nil
    }

    // MARK: - Scan Classification

    private static func isScanRequest(_ text: String) -> Bool {
        let scanPhrases = ["scan", "scan qr", "scan code", "start scan", "start scanning", "qr scan"]
        return scanPhrases.contains(where: { text.contains($0) })
    }

    // MARK: - Extraction Helpers

    private static func extractCategory(from text: String) -> ServiceRequestCategory? {
        let categoryMap: [String: ServiceRequestCategory] = [
            "maintenance": .maintenance,
            "repair": .repair,
            "inspection": .inspection,
            "calibration": .calibration,
            "replacement": .replacement,
            "installation": .installation,
            "consultation": .consultation,
            "training": .training
        ]

        for (keyword, category) in categoryMap {
            if text.contains(keyword) {
                return category
            }
        }

        return nil
    }

    private static func extractStatus(from text: String) -> ServiceRequestStatus? {
        let statusMap: [String: ServiceRequestStatus] = [
            "new": .new,
            "in progress": .inProgress,
            "on hold": .onHold,
            "resolved": .resolved,
            "closed": .closed,
            "complete": .resolved,
            "completed": .resolved,
            "done": .resolved
        ]

        for (keyword, status) in statusMap {
            if text.contains(keyword) {
                return status
            }
        }

        return nil
    }

    private static func extractTitle(from text: String, afterPattern pattern: String) -> String? {
        guard let range = text.range(of: pattern) else { return nil }

        var remaining = String(text[range.upperBound...]).trimmingCharacters(in: .whitespaces)

        // Remove common filler words
        let fillerWords = ["for", "about", "regarding", "called", "titled", "named"]
        for filler in fillerWords {
            if remaining.hasPrefix(filler + " ") {
                remaining = String(remaining.dropFirst(filler.count + 1))
            }
        }

        remaining = remaining.trimmingCharacters(in: .whitespaces)

        // Check if there's a category keyword and extract title after it
        let categories = ["maintenance", "repair", "inspection", "calibration", "replacement", "installation", "consultation", "training"]
        for category in categories {
            if remaining.hasPrefix(category + " ") {
                remaining = String(remaining.dropFirst(category.count + 1))
                break
            }
        }

        return remaining.isEmpty ? nil : remaining
    }

    private static func extractNote(from text: String, afterPattern pattern: String) -> String {
        guard let range = text.range(of: pattern) else { return "" }

        var note = String(text[range.upperBound...]).trimmingCharacters(in: .whitespaces)

        // Remove common filler words
        let fillerWords = ["that", "saying", "stating"]
        for filler in fillerWords {
            if note.hasPrefix(filler + " ") {
                note = String(note.dropFirst(filler.count + 1))
            }
        }

        return note.trimmingCharacters(in: .whitespaces)
    }

    private static func extractInstructionId(from text: String) -> String? {
        // Look for instruction ID patterns (e.g., "MAINT-001", "procedure 5")
        let patterns = [
            #"(?:instruction|procedure)\s+([A-Za-z0-9\-]+)"#,
            #"([A-Z]+-\d+)"#
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               let range = Range(match.range(at: 1), in: text) {
                return String(text[range])
            }
        }

        return nil
    }

    private static func extractStepNumber(from text: String) -> Int? {
        // Look for numbers in the text
        let pattern = #"(?:step\s+)?(\d+)"#

        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let range = Range(match.range(at: 1), in: text) {
            return Int(text[range])
        }

        // Also check for word numbers
        let wordNumbers: [String: Int] = [
            "one": 1, "two": 2, "three": 3, "four": 4, "five": 5,
            "six": 6, "seven": 7, "eight": 8, "nine": 9, "ten": 10,
            "first": 1, "second": 2, "third": 3, "fourth": 4, "fifth": 5
        ]

        for (word, number) in wordNumbers {
            if text.contains(word) {
                return number
            }
        }

        return nil
    }
}

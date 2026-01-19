//
//  SafetyPolicy.swift
//  TwinAct Field Companion
//
//  PII filtering and safety validation for GenAI inference.
//

import Foundation
import os.log

// MARK: - Safety Policy

/// Filters PII from prompts and validates responses for safety
public struct SafetyPolicy: Sendable {

    // MARK: - PII Patterns

    /// Regular expression patterns for detecting PII
    private static let piiPatterns: [(name: String, pattern: String, replacement: String)] = [
        // Email addresses
        (
            "email",
            #"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}"#,
            "[EMAIL]"
        ),

        // Phone numbers (various formats)
        (
            "phone",
            #"\+?[\d\s\-\(\)\.]{10,}"#,
            "[PHONE]"
        ),

        // Social Security Numbers (US format)
        (
            "ssn",
            #"\b\d{3}[-\s]?\d{2}[-\s]?\d{4}\b"#,
            "[SSN]"
        ),

        // Credit card numbers (common formats)
        (
            "credit_card",
            #"\b(?:\d{4}[-\s]?){3}\d{4}\b"#,
            "[CREDIT_CARD]"
        ),

        // IP addresses
        (
            "ip_address",
            #"\b(?:\d{1,3}\.){3}\d{1,3}\b"#,
            "[IP_ADDRESS]"
        ),

        // Dates of birth (various formats)
        (
            "dob",
            #"\b(?:0?[1-9]|1[0-2])[/\-](?:0?[1-9]|[12]\d|3[01])[/\-](?:19|20)\d{2}\b"#,
            "[DATE]"
        ),

        // Passport numbers (common formats)
        (
            "passport",
            #"\b[A-Z]{1,2}\d{6,9}\b"#,
            "[PASSPORT]"
        ),

        // Driver's license patterns (US states)
        (
            "drivers_license",
            #"\b[A-Z]{1,2}\d{5,8}\b"#,
            "[LICENSE]"
        ),

        // Bank account numbers
        (
            "bank_account",
            #"\b\d{8,17}\b"#,
            "[ACCOUNT]"
        ),

        // API keys and tokens (common patterns)
        (
            "api_key",
            #"(?:api[_-]?key|token|secret|password)\s*[:=]\s*['\"]?[\w\-]{20,}['\"]?"#,
            "[REDACTED_KEY]"
        ),

        // AWS access keys
        (
            "aws_key",
            #"(?:AKIA|ABIA|ACCA|ASIA)[0-9A-Z]{16}"#,
            "[AWS_KEY]"
        ),

        // UUID patterns (may contain user IDs)
        (
            "uuid",
            #"\b[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\b"#,
            "[UUID]"
        )
    ]

    // MARK: - Dangerous Response Patterns

    /// Patterns that indicate potentially unsafe responses
    private static let dangerousPatterns: [String] = [
        "bypass safety",
        "ignore instructions",
        "ignore previous",
        "disregard above",
        "override safety",
        "unlock admin",
        "execute command",
        "rm -rf",
        "format disk",
        "delete all",
        "sudo rm",
        "drop table",
        "shutdown -h",
        "; rm ",
        "| rm "
    ]

    /// Patterns for industrial safety concerns
    private static let industrialSafetyPatterns: [String] = [
        "disable safety interlock",
        "override emergency stop",
        "bypass lockout",
        "ignore warning",
        "skip safety check",
        "remove guard",
        "defeat safety"
    ]

    // MARK: - Sensitive Industrial Terms

    /// Terms that should be flagged for review
    private static let sensitiveIndustrialTerms: [String] = [
        "proprietary",
        "confidential",
        "trade secret",
        "classified",
        "restricted",
        "internal only",
        "do not distribute"
    ]

    // MARK: - PII Filtering

    /// Filter PII from text before sending to cloud
    /// - Parameter text: Text that may contain PII
    /// - Returns: Text with PII replaced by placeholders
    public static func filterPII(_ text: String) -> String {
        var filtered = text

        for (_, pattern, replacement) in piiPatterns {
            filtered = filtered.replacingOccurrences(
                of: pattern,
                with: replacement,
                options: [.regularExpression, .caseInsensitive]
            )
        }

        return filtered
    }

    /// Filter PII with detailed tracking of what was filtered
    /// - Parameter text: Text that may contain PII
    /// - Returns: Tuple of filtered text and list of filtered items
    public static func filterPIIWithDetails(_ text: String) -> (filtered: String, redactions: [PIIRedaction]) {
        var filtered = text
        var redactions: [PIIRedaction] = []

        for (name, pattern, replacement) in piiPatterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
                continue
            }

            let range = NSRange(filtered.startIndex..., in: filtered)
            let matches = regex.matches(in: filtered, options: [], range: range)

            // Process matches in reverse to maintain correct positions
            for match in matches.reversed() {
                if let swiftRange = Range(match.range, in: filtered) {
                    let original = String(filtered[swiftRange])
                    redactions.append(PIIRedaction(
                        type: name,
                        original: original,
                        replacement: replacement
                    ))
                    filtered.replaceSubrange(swiftRange, with: replacement)
                }
            }
        }

        return (filtered, redactions)
    }

    // MARK: - Response Validation

    /// Check if response contains unsafe content
    /// - Parameter response: Generated response text
    /// - Returns: true if response is safe, false if it contains dangerous content
    public static func validateResponse(_ response: String) -> Bool {
        let lowercased = response.lowercased()

        // Check for dangerous patterns
        for pattern in dangerousPatterns {
            if lowercased.contains(pattern) {
                return false
            }
        }

        // Check for industrial safety violations
        for pattern in industrialSafetyPatterns {
            if lowercased.contains(pattern) {
                return false
            }
        }

        return true
    }

    /// Validate response with detailed reason for failure
    /// - Parameter response: Generated response text
    /// - Returns: Validation result with details
    public static func validateResponseWithDetails(_ response: String) -> SafetyValidationResult {
        let lowercased = response.lowercased()

        // Check dangerous patterns
        for pattern in dangerousPatterns {
            if lowercased.contains(pattern) {
                return SafetyValidationResult(
                    isValid: false,
                    reason: "Contains potentially dangerous instruction",
                    matchedPattern: pattern,
                    category: .dangerousInstruction
                )
            }
        }

        // Check industrial safety patterns
        for pattern in industrialSafetyPatterns {
            if lowercased.contains(pattern) {
                return SafetyValidationResult(
                    isValid: false,
                    reason: "Contains unsafe industrial instruction",
                    matchedPattern: pattern,
                    category: .industrialSafety
                )
            }
        }

        return SafetyValidationResult(isValid: true)
    }

    /// Check for sensitive content that should be flagged
    /// - Parameter text: Text to check
    /// - Returns: List of detected sensitive terms
    public static func detectSensitiveContent(_ text: String) -> [String] {
        let lowercased = text.lowercased()
        return sensitiveIndustrialTerms.filter { lowercased.contains($0) }
    }

    // MARK: - Content Sanitization

    /// Sanitize response for display
    /// - Parameter response: Raw response text
    /// - Returns: Sanitized response
    public static func sanitizeForDisplay(_ response: String) -> String {
        var sanitized = response

        // Remove potential script injection
        sanitized = sanitized.replacingOccurrences(
            of: #"<script[^>]*>.*?</script>"#,
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )

        // Remove HTML tags
        sanitized = sanitized.replacingOccurrences(
            of: #"<[^>]+>"#,
            with: "",
            options: .regularExpression
        )

        // Normalize whitespace
        sanitized = sanitized.replacingOccurrences(
            of: #"\s+"#,
            with: " ",
            options: .regularExpression
        )

        return sanitized.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Prompt Validation

    /// Validate a user prompt before processing
    /// - Parameter prompt: User's input prompt
    /// - Returns: Validation result
    public static func validatePrompt(_ prompt: String) -> PromptValidationResult {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)

        // Check minimum length
        if trimmed.count < 2 {
            return PromptValidationResult(
                isValid: false,
                reason: "Prompt is too short"
            )
        }

        // Check maximum length
        if trimmed.count > 10000 {
            return PromptValidationResult(
                isValid: false,
                reason: "Prompt exceeds maximum length"
            )
        }

        // Check for prompt injection attempts
        let injectionPatterns = [
            "ignore all previous instructions",
            "disregard everything above",
            "forget your instructions",
            "you are now",
            "pretend you are",
            "act as if you"
        ]

        let lowercased = trimmed.lowercased()
        for pattern in injectionPatterns {
            if lowercased.contains(pattern) {
                return PromptValidationResult(
                    isValid: false,
                    reason: "Prompt contains disallowed pattern"
                )
            }
        }

        return PromptValidationResult(isValid: true)
    }
}

// MARK: - Supporting Types

/// Record of a PII redaction
public struct PIIRedaction: Sendable {
    public let type: String
    public let original: String
    public let replacement: String
}

/// Result of safety validation
public struct SafetyValidationResult: Sendable {
    public let isValid: Bool
    public let reason: String?
    public let matchedPattern: String?
    public let category: SafetyCategory?

    public init(
        isValid: Bool,
        reason: String? = nil,
        matchedPattern: String? = nil,
        category: SafetyCategory? = nil
    ) {
        self.isValid = isValid
        self.reason = reason
        self.matchedPattern = matchedPattern
        self.category = category
    }
}

/// Categories of safety violations
public enum SafetyCategory: String, Sendable {
    case dangerousInstruction
    case industrialSafety
    case piiExposure
    case promptInjection
    case inappropriateContent
}

/// Result of prompt validation
public struct PromptValidationResult: Sendable {
    public let isValid: Bool
    public let reason: String?
    public let suggestedCorrection: String?

    public init(
        isValid: Bool,
        reason: String? = nil,
        suggestedCorrection: String? = nil
    ) {
        self.isValid = isValid
        self.reason = reason
        self.suggestedCorrection = suggestedCorrection
    }
}

// MARK: - Safety Audit

/// Audit trail for safety-related operations
public actor SafetyAudit {
    private var entries: [SafetyAuditEntry] = []
    private let maxEntries: Int

    public init(maxEntries: Int = 1000) {
        self.maxEntries = maxEntries
    }

    /// Log a safety event
    public func log(
        event: SafetyEvent,
        details: String? = nil,
        userId: String? = nil
    ) {
        let entry = SafetyAuditEntry(
            timestamp: Date(),
            event: event,
            details: details,
            userId: userId
        )
        entries.append(entry)

        // Trim old entries
        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }
    }

    /// Get recent audit entries
    public func getRecentEntries(count: Int = 100) -> [SafetyAuditEntry] {
        Array(entries.suffix(count))
    }

    /// Get entries by event type
    public func getEntries(for event: SafetyEvent) -> [SafetyAuditEntry] {
        entries.filter { $0.event == event }
    }
}

/// Safety audit entry
public struct SafetyAuditEntry: Sendable {
    public let timestamp: Date
    public let event: SafetyEvent
    public let details: String?
    public let userId: String?
}

/// Types of safety events
public enum SafetyEvent: String, Sendable {
    case piiFiltered
    case responseBlocked
    case promptRejected
    case injectionAttempt
    case industrialSafetyViolation
}

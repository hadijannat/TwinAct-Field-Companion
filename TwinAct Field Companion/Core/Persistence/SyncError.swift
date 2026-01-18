//
//  SyncError.swift
//  TwinAct Field Companion
//
//  Sync-specific errors for offline queue processing
//

import Foundation

// MARK: - Sync Error

/// Errors that can occur during sync operations
public enum SyncError: Error, LocalizedError, Sendable {

    // MARK: - Connection Errors

    /// Device is not connected to the network
    case notConnected

    /// Network doesn't meet sync requirements (e.g., Wi-Fi only mode)
    case networkRequirementsNotMet(reason: String)

    // MARK: - Sync State Errors

    /// Sync is already in progress
    case syncInProgress

    /// Sync was cancelled
    case cancelled

    /// Background task expired before sync completed
    case backgroundTaskExpired

    // MARK: - Operation Errors

    /// Individual operation failed
    case operationFailed(operationId: UUID, underlying: Error)

    /// Maximum retry attempts exceeded for an operation
    case maxRetriesExceeded(operationId: UUID, attempts: Int)

    /// Payload could not be decoded
    case payloadDecodingFailed(operationId: UUID, underlying: Error)

    // MARK: - Conflict Errors

    /// Conflict detected during sync - requires resolution
    case conflictDetected(operationId: UUID, resolution: ConflictResolver.Resolution)

    /// Conflict requires manual resolution by user
    case manualResolutionRequired(operationId: UUID, localVersion: String, serverVersion: String)

    // MARK: - Server Errors

    /// Server returned an error
    case serverError(operationId: UUID?, statusCode: Int, message: String?)

    /// Resource not found on server
    case resourceNotFound(operationId: UUID, entityId: String)

    // MARK: - LocalizedError Implementation

    public var errorDescription: String? {
        switch self {
        case .notConnected:
            return "No network connection available"

        case .networkRequirementsNotMet(let reason):
            return "Network requirements not met: \(reason)"

        case .syncInProgress:
            return "Sync is already in progress"

        case .cancelled:
            return "Sync was cancelled"

        case .backgroundTaskExpired:
            return "Background task expired before sync completed"

        case .operationFailed(let operationId, let underlying):
            return "Operation \(operationId.uuidString.prefix(8)) failed: \(underlying.localizedDescription)"

        case .maxRetriesExceeded(let operationId, let attempts):
            return "Operation \(operationId.uuidString.prefix(8)) exceeded maximum retries (\(attempts) attempts)"

        case .payloadDecodingFailed(let operationId, _):
            return "Failed to decode payload for operation \(operationId.uuidString.prefix(8))"

        case .conflictDetected(let operationId, _):
            return "Conflict detected for operation \(operationId.uuidString.prefix(8))"

        case .manualResolutionRequired(let operationId, _, _):
            return "Manual conflict resolution required for operation \(operationId.uuidString.prefix(8))"

        case .serverError(let operationId, let statusCode, let message):
            let opStr = operationId.map { "Operation \($0.uuidString.prefix(8)): " } ?? ""
            let msgStr = message ?? "Unknown error"
            return "\(opStr)Server error (\(statusCode)): \(msgStr)"

        case .resourceNotFound(let operationId, let entityId):
            return "Operation \(operationId.uuidString.prefix(8)): Resource not found (\(entityId))"
        }
    }

    public var failureReason: String? {
        switch self {
        case .notConnected:
            return "The device does not have an active network connection"

        case .networkRequirementsNotMet:
            return "The current network connection does not meet the configured requirements for syncing"

        case .syncInProgress:
            return "A sync operation is already running"

        case .cancelled:
            return "The sync operation was cancelled by the user or system"

        case .backgroundTaskExpired:
            return "iOS terminated the background task before sync could complete"

        case .operationFailed:
            return "The server rejected the operation or a network error occurred"

        case .maxRetriesExceeded:
            return "The operation failed repeatedly and will not be retried"

        case .payloadDecodingFailed:
            return "The stored operation data could not be decoded"

        case .conflictDetected:
            return "The local and server versions of this data differ"

        case .manualResolutionRequired:
            return "The conflict cannot be automatically resolved"

        case .serverError:
            return "The server returned an error response"

        case .resourceNotFound:
            return "The resource no longer exists on the server"
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .notConnected:
            return "Connect to the internet and try again"

        case .networkRequirementsNotMet:
            return "Connect to a Wi-Fi network or change the sync settings"

        case .syncInProgress:
            return "Wait for the current sync to complete"

        case .cancelled:
            return "Trigger sync again when ready"

        case .backgroundTaskExpired:
            return "The sync will resume automatically when the app is opened"

        case .operationFailed:
            return "The operation will be retried automatically"

        case .maxRetriesExceeded:
            return "Review the failed operation and retry manually or discard it"

        case .payloadDecodingFailed:
            return "This operation cannot be synced and should be discarded"

        case .conflictDetected:
            return "Review the conflict and choose which version to keep"

        case .manualResolutionRequired:
            return "Open the conflict resolution screen to resolve"

        case .serverError:
            return "Try again later. If the problem persists, contact support"

        case .resourceNotFound:
            return "The resource may have been deleted. Consider removing this operation"
        }
    }

    // MARK: - Error Classification

    /// Whether this error indicates a transient condition that may succeed on retry
    public var isRetryable: Bool {
        switch self {
        case .notConnected, .networkRequirementsNotMet, .backgroundTaskExpired:
            return true

        case .operationFailed(_, let underlying):
            // Check if underlying error is retryable
            if let aasError = underlying as? AASError {
                return aasError.isRetryable
            }
            return true

        case .serverError(_, let statusCode, _):
            // 5xx errors are typically retryable
            return statusCode >= 500 && statusCode < 600

        case .syncInProgress, .cancelled, .maxRetriesExceeded,
             .payloadDecodingFailed, .conflictDetected,
             .manualResolutionRequired, .resourceNotFound:
            return false
        }
    }

    /// Whether this error requires user intervention
    public var requiresUserAction: Bool {
        switch self {
        case .manualResolutionRequired, .maxRetriesExceeded, .payloadDecodingFailed:
            return true

        case .conflictDetected(_, let resolution):
            if case .requiresManualResolution = resolution {
                return true
            }
            return false

        default:
            return false
        }
    }

    /// The operation ID associated with this error, if any
    public var operationId: UUID? {
        switch self {
        case .operationFailed(let id, _),
             .maxRetriesExceeded(let id, _),
             .payloadDecodingFailed(let id, _),
             .conflictDetected(let id, _),
             .manualResolutionRequired(let id, _, _),
             .resourceNotFound(let id, _):
            return id

        case .serverError(let id, _, _):
            return id

        default:
            return nil
        }
    }
}

// MARK: - Sync Result

/// Result of a sync operation
public struct SyncResult: Sendable {
    /// Number of operations successfully synced
    public let successCount: Int

    /// Number of operations that failed
    public let failureCount: Int

    /// Number of operations skipped (e.g., conflicts needing manual resolution)
    public let skippedCount: Int

    /// Errors that occurred during sync
    public let errors: [SyncError]

    /// Whether the sync completed without any failures
    public var isSuccess: Bool {
        failureCount == 0 && errors.isEmpty
    }

    /// Total number of operations processed
    public var totalProcessed: Int {
        successCount + failureCount + skippedCount
    }

    /// Whether there are operations requiring user attention
    public var requiresUserAttention: Bool {
        errors.contains { $0.requiresUserAction }
    }

    public init(
        successCount: Int = 0,
        failureCount: Int = 0,
        skippedCount: Int = 0,
        errors: [SyncError] = []
    ) {
        self.successCount = successCount
        self.failureCount = failureCount
        self.skippedCount = skippedCount
        self.errors = errors
    }

    /// Create a successful result
    public static func success(count: Int) -> SyncResult {
        SyncResult(successCount: count)
    }

    /// Create a failed result
    public static func failure(_ error: SyncError) -> SyncResult {
        SyncResult(failureCount: 1, errors: [error])
    }

    /// Merge multiple results into one
    public static func combine(_ results: [SyncResult]) -> SyncResult {
        SyncResult(
            successCount: results.reduce(0) { $0 + $1.successCount },
            failureCount: results.reduce(0) { $0 + $1.failureCount },
            skippedCount: results.reduce(0) { $0 + $1.skippedCount },
            errors: results.flatMap { $0.errors }
        )
    }
}

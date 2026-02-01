//
//  AuditEntry.swift
//  TwinAct Field Companion
//
//  SwiftData model for audit trail entries
//

import Foundation
import SwiftData

// MARK: - Audit Action Type

/// Types of actions that can be audited
public enum AuditActionType: String, Codable, CaseIterable {
    // Service Request Actions
    case serviceRequestCreated
    case serviceRequestUpdated
    case serviceRequestSynced
    case serviceRequestDeleted

    // Voice Command Actions
    case voiceCommandExecuted
    case voiceCommandFailed

    // Document Actions
    case documentViewed
    case documentDownloaded
    case documentDeleted

    // Asset Actions
    case assetScanned
    case assetViewed

    // Sync Actions
    case syncStarted
    case syncCompleted
    case syncFailed

    // Authentication Actions
    case loginSuccess
    case loginFailed
    case sessionExpired
    case logoutSuccess

    // System Actions
    case appLaunched
    case appBackgrounded
    case errorOccurred
}

// MARK: - Audit Entry Model

/// Audit trail entry for tracking user actions
///
/// Provides comprehensive logging for compliance, debugging,
/// and operational analytics. All significant user actions
/// and system events are recorded.
@Model
public final class AuditEntry {

    // MARK: - Properties

    /// Unique identifier for this audit entry
    public var id: UUID

    /// When this action occurred
    public var timestamp: Date

    /// Type of action being audited
    public var actionType: AuditActionType

    /// Entity type involved (e.g., "ServiceRequest", "Document")
    public var entityType: String

    /// ID of the entity involved (if applicable)
    public var entityId: String?

    /// User ID who performed the action
    public var userId: String?

    /// Additional details about the action
    public var details: String?

    /// Speech-to-text result for voice commands
    public var transcription: String?

    /// Recognition confidence for voice commands (0.0 - 1.0)
    public var voiceConfidence: Double?

    /// Sync status for sync-related entries
    public var syncStatus: String?

    /// Error message for failed operations
    public var errorMessage: String?

    /// Device identifier for multi-device tracking
    public var deviceId: String?

    /// Session ID for grouping related actions
    public var sessionId: String?

    /// Duration of the action in seconds (for timed operations)
    public var duration: Double?

    // MARK: - Initialization

    public init(
        actionType: AuditActionType,
        entityType: String,
        entityId: String? = nil,
        details: String? = nil
    ) {
        self.id = UUID()
        self.timestamp = Date()
        self.actionType = actionType
        self.entityType = entityType
        self.entityId = entityId
        self.details = details
    }

    // MARK: - Convenience Initializers

    /// Create a voice command audit entry
    public convenience init(
        voiceCommand transcription: String,
        confidence: Double,
        entityType: String,
        success: Bool
    ) {
        self.init(
            actionType: success ? .voiceCommandExecuted : .voiceCommandFailed,
            entityType: entityType
        )
        self.transcription = transcription
        self.voiceConfidence = confidence
    }

    /// Create a sync audit entry
    public convenience init(
        syncAction: AuditActionType,
        entityType: String,
        entityId: String?,
        status: String?,
        error: String? = nil
    ) {
        self.init(
            actionType: syncAction,
            entityType: entityType,
            entityId: entityId
        )
        self.syncStatus = status
        self.errorMessage = error
    }

    /// Create an authentication audit entry
    public convenience init(
        authAction: AuditActionType,
        userId: String?,
        success: Bool,
        error: String? = nil
    ) {
        self.init(
            actionType: authAction,
            entityType: "Authentication"
        )
        self.userId = userId
        self.errorMessage = success ? nil : error
    }

    // MARK: - Methods

    /// Set session context
    public func setSessionContext(userId: String?, deviceId: String?, sessionId: String?) {
        self.userId = userId
        self.deviceId = deviceId
        self.sessionId = sessionId
    }
}

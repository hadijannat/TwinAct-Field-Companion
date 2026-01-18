//
//  OutboxOperation.swift
//  TwinAct Field Companion
//
//  SwiftData model for queued operations waiting to sync
//

import Foundation
import SwiftData

// MARK: - Outbox Operation Type

/// Types of operations that can be queued for sync
public enum OutboxOperationType: String, Codable {
    case create
    case update
    case delete
}

// MARK: - Outbox Status

/// Status of an outbox operation
public enum OutboxStatus: String, Codable {
    case pending
    case inProgress
    case failed
    case completed
}

// MARK: - Outbox Operation Model

/// Represents a pending operation to sync to server
///
/// Operations are queued locally when the device is offline and
/// synchronized when connectivity is restored. This enables
/// offline-first architecture for field operations.
@Model
public final class OutboxOperation {

    // MARK: - Properties

    /// Unique identifier for this operation
    public var id: UUID

    /// Type of operation (create, update, delete)
    @Attribute(.transformable(by: OutboxOperationTypeTransformer.self))
    public var operationType: OutboxOperationType

    /// Entity type being operated on (e.g., "ServiceRequest")
    public var entityType: String

    /// AAS element ID of the entity
    public var entityId: String

    /// Parent submodel ID
    public var submodelId: String

    /// JSON payload for the operation
    public var payload: Data

    /// When this operation was created
    public var createdAt: Date

    /// When the last sync attempt occurred
    public var lastAttemptAt: Date?

    /// Number of sync attempts made
    public var attemptCount: Int

    /// Error message from last failed attempt
    public var errorMessage: String?

    /// Current status of the operation
    @Attribute(.transformable(by: OutboxStatusTransformer.self))
    public var status: OutboxStatus

    /// Priority for retry ordering (higher = more important)
    public var priority: Int

    // MARK: - Initialization

    public init(
        operationType: OutboxOperationType,
        entityType: String,
        entityId: String,
        submodelId: String,
        payload: Data,
        priority: Int = 0
    ) {
        self.id = UUID()
        self.operationType = operationType
        self.entityType = entityType
        self.entityId = entityId
        self.submodelId = submodelId
        self.payload = payload
        self.createdAt = Date()
        self.attemptCount = 0
        self.status = .pending
        self.priority = priority
    }

    // MARK: - Computed Properties

    /// Whether this operation can be retried
    public var canRetry: Bool {
        status == .pending || status == .failed
    }

    /// Maximum retry attempts before giving up
    public static let maxRetryAttempts = 5

    /// Whether max retries have been exceeded
    public var hasExceededMaxRetries: Bool {
        attemptCount >= Self.maxRetryAttempts
    }

    // MARK: - Methods

    /// Mark operation as in progress
    public func markInProgress() {
        status = .inProgress
        lastAttemptAt = Date()
        attemptCount += 1
    }

    /// Mark operation as completed
    public func markCompleted() {
        status = .completed
        errorMessage = nil
    }

    /// Mark operation as failed with error
    public func markFailed(error: String) {
        status = .failed
        errorMessage = error
    }

    /// Reset to pending for retry
    public func resetForRetry() {
        status = .pending
    }
}

// MARK: - Value Transformers

/// Transformer for OutboxOperationType to store in SwiftData
@objc(OutboxOperationTypeTransformer)
final class OutboxOperationTypeTransformer: ValueTransformer {
    override class func transformedValueClass() -> AnyClass {
        NSString.self
    }

    override class func allowsReverseTransformation() -> Bool {
        true
    }

    override func transformedValue(_ value: Any?) -> Any? {
        guard let operationType = value as? OutboxOperationType else { return nil }
        return operationType.rawValue as NSString
    }

    override func reverseTransformedValue(_ value: Any?) -> Any? {
        guard let rawValue = value as? String else { return nil }
        return OutboxOperationType(rawValue: rawValue)
    }

    static func register() {
        ValueTransformer.setValueTransformer(
            OutboxOperationTypeTransformer(),
            forName: NSValueTransformerName("OutboxOperationTypeTransformer")
        )
    }
}

/// Transformer for OutboxStatus to store in SwiftData
@objc(OutboxStatusTransformer)
final class OutboxStatusTransformer: ValueTransformer {
    override class func transformedValueClass() -> AnyClass {
        NSString.self
    }

    override class func allowsReverseTransformation() -> Bool {
        true
    }

    override func transformedValue(_ value: Any?) -> Any? {
        guard let status = value as? OutboxStatus else { return nil }
        return status.rawValue as NSString
    }

    override func reverseTransformedValue(_ value: Any?) -> Any? {
        guard let rawValue = value as? String else { return nil }
        return OutboxStatus(rawValue: rawValue)
    }

    static func register() {
        ValueTransformer.setValueTransformer(
            OutboxStatusTransformer(),
            forName: NSValueTransformerName("OutboxStatusTransformer")
        )
    }
}

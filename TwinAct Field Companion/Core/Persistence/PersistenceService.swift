//
//  PersistenceService.swift
//  TwinAct Field Companion
//
//  Persistence service with repository pattern implementation
//

import Foundation
import SwiftData

// MARK: - Persistence Repository Protocol

/// Repository for persistence operations
///
/// Provides a clean interface for all persistence operations,
/// abstracting away SwiftData implementation details.
public protocol PersistenceRepositoryProtocol {

    // MARK: - Outbox Operations

    /// Add an operation to the outbox queue
    func addToOutbox(_ operation: OutboxOperation) async throws

    /// Get all pending operations ready for sync
    func getPendingOperations() async -> [OutboxOperation]

    /// Get pending operations for a specific entity type
    func getPendingOperations(entityType: String) async -> [OutboxOperation]

    /// Mark an operation as completed
    func markOperationComplete(_ id: UUID) async throws

    /// Mark an operation as failed with error message
    func markOperationFailed(_ id: UUID, error: String) async throws

    /// Delete completed operations older than a specified date
    func deleteCompletedOperations(olderThan date: Date) async throws

    /// Get outbox statistics
    func getOutboxStats() async -> OutboxStats

    // MARK: - Cache Operations

    /// Cache a submodel
    func cacheSubmodel(_ submodel: CachedSubmodel) async throws

    /// Get a cached submodel by ID
    func getCachedSubmodel(id: String) async -> CachedSubmodel?

    /// Get all cached submodels for an AAS
    func getCachedSubmodels(forAAS aasId: String) async -> [CachedSubmodel]

    /// Clear expired cache entries
    func clearExpiredCache() async throws

    /// Clear all cache
    func clearAllCache() async throws

    /// Get cache statistics
    func getCacheStats() async -> CacheStats

    // MARK: - Document Operations

    /// Cache a document
    func cacheDocument(_ document: CachedDocument) async throws

    /// Get a cached document by ID
    func getCachedDocument(id: String) async -> CachedDocument?

    /// Get all cached documents for an AAS
    func getCachedDocuments(forAAS aasId: String) async -> [CachedDocument]

    /// Get favorite documents
    func getFavoriteDocuments() async -> [CachedDocument]

    /// Delete a cached document (including file)
    func deleteCachedDocument(id: String) async throws

    /// Clean up orphaned document files
    func cleanupOrphanedDocuments() async throws

    // MARK: - Audit Operations

    /// Add an audit entry
    func addAuditEntry(_ entry: AuditEntry) async throws

    /// Get audit entries since a date
    func getAuditEntries(since: Date) async -> [AuditEntry]

    /// Get audit entries for a specific entity
    func getAuditEntries(entityType: String, entityId: String?) async -> [AuditEntry]

    /// Get audit entries by action type
    func getAuditEntries(actionType: AuditActionType) async -> [AuditEntry]

    /// Delete old audit entries
    func deleteAuditEntries(olderThan date: Date) async throws

    /// Get audit statistics
    func getAuditStats() async -> AuditStats
}

// MARK: - Statistics Structs

/// Outbox queue statistics
public struct OutboxStats {
    public let pendingCount: Int
    public let inProgressCount: Int
    public let failedCount: Int
    public let completedCount: Int

    public var totalPending: Int { pendingCount + failedCount }
}

/// Cache statistics
public struct CacheStats {
    public let submodelCount: Int
    public let documentCount: Int
    public let totalSizeBytes: Int
    public let expiredCount: Int

    public var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(totalSizeBytes), countStyle: .file)
    }
}

/// Audit statistics
public struct AuditStats {
    public let totalEntries: Int
    public let todayEntries: Int
    public let errorCount: Int
    public let syncCount: Int
}

// MARK: - Persistence Service Implementation

/// Main persistence service implementing the repository protocol
@MainActor
public final class PersistenceService: PersistenceRepositoryProtocol, ObservableObject {

    // MARK: - Properties

    private let controller: PersistenceController

    private var context: ModelContext {
        controller.context
    }

    // MARK: - Initialization

    public init(controller: PersistenceController = .shared) {
        self.controller = controller
    }

    // MARK: - Outbox Operations

    public func addToOutbox(_ operation: OutboxOperation) async throws {
        context.insert(operation)
        try context.save()
    }

    public func getPendingOperations() async -> [OutboxOperation] {
        let descriptor = FetchDescriptor<OutboxOperation>(
            predicate: #Predicate { $0.status == .pending || $0.status == .failed },
            sortBy: [
                SortDescriptor(\.priority, order: .reverse),
                SortDescriptor(\.createdAt, order: .forward)
            ]
        )

        return (try? context.fetch(descriptor)) ?? []
    }

    public func getPendingOperations(entityType: String) async -> [OutboxOperation] {
        let descriptor = FetchDescriptor<OutboxOperation>(
            predicate: #Predicate {
                ($0.status == .pending || $0.status == .failed) && $0.entityType == entityType
            },
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )

        return (try? context.fetch(descriptor)) ?? []
    }

    public func markOperationComplete(_ id: UUID) async throws {
        let descriptor = FetchDescriptor<OutboxOperation>(
            predicate: #Predicate { $0.id == id }
        )

        guard let operation = try context.fetch(descriptor).first else {
            throw PersistenceError.notFound("OutboxOperation with id \(id)")
        }

        operation.markCompleted()
        try context.save()
    }

    public func markOperationFailed(_ id: UUID, error: String) async throws {
        let descriptor = FetchDescriptor<OutboxOperation>(
            predicate: #Predicate { $0.id == id }
        )

        guard let operation = try context.fetch(descriptor).first else {
            throw PersistenceError.notFound("OutboxOperation with id \(id)")
        }

        operation.markFailed(error: error)
        try context.save()
    }

    public func deleteCompletedOperations(olderThan date: Date) async throws {
        let descriptor = FetchDescriptor<OutboxOperation>(
            predicate: #Predicate { $0.status == .completed && $0.createdAt < date }
        )

        let operations = try context.fetch(descriptor)
        operations.forEach { context.delete($0) }
        try context.save()
    }

    public func getOutboxStats() async -> OutboxStats {
        let all = (try? context.fetch(FetchDescriptor<OutboxOperation>())) ?? []

        return OutboxStats(
            pendingCount: all.filter { $0.status == .pending }.count,
            inProgressCount: all.filter { $0.status == .inProgress }.count,
            failedCount: all.filter { $0.status == .failed }.count,
            completedCount: all.filter { $0.status == .completed }.count
        )
    }

    // MARK: - Cache Operations

    public func cacheSubmodel(_ submodel: CachedSubmodel) async throws {
        // Check if already exists
        if let existing = await getCachedSubmodel(id: submodel.id) {
            existing.updateData(submodel.data, ttlSeconds: submodel.expiresAt?.timeIntervalSince(Date()) ?? 3600)
            existing.semanticId = submodel.semanticId
            existing.idShort = submodel.idShort
            existing.version = submodel.version
        } else {
            context.insert(submodel)
        }
        try context.save()
    }

    public func getCachedSubmodel(id: String) async -> CachedSubmodel? {
        let descriptor = FetchDescriptor<CachedSubmodel>(
            predicate: #Predicate { $0.id == id }
        )

        guard let submodel = try? context.fetch(descriptor).first else {
            return nil
        }

        // Record access
        submodel.recordAccess()
        return submodel
    }

    public func getCachedSubmodels(forAAS aasId: String) async -> [CachedSubmodel] {
        let descriptor = FetchDescriptor<CachedSubmodel>(
            predicate: #Predicate { $0.aasId == aasId },
            sortBy: [SortDescriptor(\.idShort)]
        )

        return (try? context.fetch(descriptor)) ?? []
    }

    public func clearExpiredCache() async throws {
        let now = Date()
        let submodelDescriptor = FetchDescriptor<CachedSubmodel>(
            predicate: #Predicate { $0.expiresAt != nil && $0.expiresAt! < now }
        )

        let expiredSubmodels = try context.fetch(submodelDescriptor)
        expiredSubmodels.forEach { context.delete($0) }

        try context.save()
    }

    public func clearAllCache() async throws {
        try context.delete(model: CachedSubmodel.self)
        try context.delete(model: CachedDocument.self)
        try context.save()
    }

    public func getCacheStats() async -> CacheStats {
        let submodels = (try? context.fetch(FetchDescriptor<CachedSubmodel>())) ?? []
        let documents = (try? context.fetch(FetchDescriptor<CachedDocument>())) ?? []

        let submodelSize = submodels.reduce(0) { $0 + $1.dataSize }
        let documentSize = documents.reduce(0) { $0 + $1.fileSize }
        let expiredCount = submodels.filter { $0.isExpired }.count

        return CacheStats(
            submodelCount: submodels.count,
            documentCount: documents.count,
            totalSizeBytes: submodelSize + documentSize,
            expiredCount: expiredCount
        )
    }

    // MARK: - Document Operations

    public func cacheDocument(_ document: CachedDocument) async throws {
        // Check if already exists
        if let existing = await getCachedDocument(id: document.id) {
            // Update existing
            existing.title = document.title
            existing.fileType = document.fileType
            existing.fileSize = document.fileSize
            existing.localPath = document.localPath
            existing.remoteURL = document.remoteURL
            existing.downloadedAt = Date()
        } else {
            context.insert(document)
        }
        try context.save()
    }

    public func getCachedDocument(id: String) async -> CachedDocument? {
        let descriptor = FetchDescriptor<CachedDocument>(
            predicate: #Predicate { $0.id == id }
        )

        return try? context.fetch(descriptor).first
    }

    public func getCachedDocuments(forAAS aasId: String) async -> [CachedDocument] {
        let descriptor = FetchDescriptor<CachedDocument>(
            predicate: #Predicate { $0.aasId == aasId },
            sortBy: [SortDescriptor(\.title)]
        )

        return (try? context.fetch(descriptor)) ?? []
    }

    public func getFavoriteDocuments() async -> [CachedDocument] {
        let descriptor = FetchDescriptor<CachedDocument>(
            predicate: #Predicate { $0.isFavorite == true },
            sortBy: [SortDescriptor(\.lastAccessedAt, order: .reverse)]
        )

        return (try? context.fetch(descriptor)) ?? []
    }

    public func deleteCachedDocument(id: String) async throws {
        guard let document = await getCachedDocument(id: id) else {
            throw PersistenceError.notFound("CachedDocument with id \(id)")
        }

        // Delete the local file
        try? document.deleteLocalFile()

        // Delete the record
        context.delete(document)
        try context.save()
    }

    public func cleanupOrphanedDocuments() async throws {
        let documents = try context.fetch(FetchDescriptor<CachedDocument>())

        for document in documents {
            if !document.localFileExists {
                context.delete(document)
            }
        }

        try context.save()
    }

    // MARK: - Audit Operations

    public func addAuditEntry(_ entry: AuditEntry) async throws {
        context.insert(entry)
        try context.save()
    }

    public func getAuditEntries(since date: Date) async -> [AuditEntry] {
        let descriptor = FetchDescriptor<AuditEntry>(
            predicate: #Predicate { $0.timestamp >= date },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )

        return (try? context.fetch(descriptor)) ?? []
    }

    public func getAuditEntries(entityType: String, entityId: String?) async -> [AuditEntry] {
        let descriptor: FetchDescriptor<AuditEntry>

        if let entityId = entityId {
            descriptor = FetchDescriptor<AuditEntry>(
                predicate: #Predicate { $0.entityType == entityType && $0.entityId == entityId },
                sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
            )
        } else {
            descriptor = FetchDescriptor<AuditEntry>(
                predicate: #Predicate { $0.entityType == entityType },
                sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
            )
        }

        return (try? context.fetch(descriptor)) ?? []
    }

    public func getAuditEntries(actionType: AuditActionType) async -> [AuditEntry] {
        // Note: We need to fetch all and filter because SwiftData predicates
        // don't support transformable types directly in predicates
        let descriptor = FetchDescriptor<AuditEntry>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )

        let all = (try? context.fetch(descriptor)) ?? []
        return all.filter { $0.actionType == actionType }
    }

    public func deleteAuditEntries(olderThan date: Date) async throws {
        let descriptor = FetchDescriptor<AuditEntry>(
            predicate: #Predicate { $0.timestamp < date }
        )

        let entries = try context.fetch(descriptor)
        entries.forEach { context.delete($0) }
        try context.save()
    }

    public func getAuditStats() async -> AuditStats {
        let all = (try? context.fetch(FetchDescriptor<AuditEntry>())) ?? []

        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())

        let todayEntries = all.filter { $0.timestamp >= startOfToday }
        let errorEntries = all.filter { $0.errorMessage != nil }
        let syncEntries = all.filter {
            $0.actionType == .syncStarted ||
            $0.actionType == .syncCompleted ||
            $0.actionType == .syncFailed
        }

        return AuditStats(
            totalEntries: all.count,
            todayEntries: todayEntries.count,
            errorCount: errorEntries.count,
            syncCount: syncEntries.count
        )
    }

    // MARK: - Convenience Methods

    /// Log an action and return the audit entry
    @discardableResult
    public func logAction(
        _ actionType: AuditActionType,
        entityType: String,
        entityId: String? = nil,
        details: String? = nil,
        userId: String? = nil
    ) async throws -> AuditEntry {
        let entry = AuditEntry(
            actionType: actionType,
            entityType: entityType,
            entityId: entityId,
            details: details
        )
        entry.userId = userId

        try await addAuditEntry(entry)
        return entry
    }

    /// Queue an operation for sync
    @discardableResult
    public func queueForSync(
        operationType: OutboxOperationType,
        entityType: String,
        entityId: String,
        submodelId: String,
        payload: Encodable,
        priority: Int = 0
    ) async throws -> OutboxOperation {
        let encoder = JSONEncoder()
        let data = try encoder.encode(AnyEncodable(payload))

        let operation = OutboxOperation(
            operationType: operationType,
            entityType: entityType,
            entityId: entityId,
            submodelId: submodelId,
            payload: data,
            priority: priority
        )

        try await addToOutbox(operation)

        // Also log the action
        try await logAction(
            operationType == .create ? .serviceRequestCreated : .serviceRequestUpdated,
            entityType: entityType,
            entityId: entityId,
            details: "Queued for sync (\(operationType.rawValue))"
        )

        return operation
    }
}

// MARK: - Persistence Errors

/// Errors that can occur during persistence operations
public enum PersistenceError: LocalizedError {
    case notFound(String)
    case saveFailed(Error)
    case deleteFailed(Error)
    case invalidData(String)

    public var errorDescription: String? {
        switch self {
        case .notFound(let entity):
            return "Entity not found: \(entity)"
        case .saveFailed(let error):
            return "Failed to save: \(error.localizedDescription)"
        case .deleteFailed(let error):
            return "Failed to delete: \(error.localizedDescription)"
        case .invalidData(let reason):
            return "Invalid data: \(reason)"
        }
    }
}

// MARK: - AnyEncodable Helper

/// Type-erased encodable wrapper
private struct AnyEncodable: Encodable {
    private let encodeFunc: (Encoder) throws -> Void

    init<T: Encodable>(_ value: T) {
        encodeFunc = value.encode
    }

    func encode(to encoder: Encoder) throws {
        try encodeFunc(encoder)
    }
}

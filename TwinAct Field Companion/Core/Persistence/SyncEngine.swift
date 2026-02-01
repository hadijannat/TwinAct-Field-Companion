//
//  SyncEngine.swift
//  TwinAct Field Companion
//
//  Coordinates offline-first sync operations with the AAS server
//

import Foundation
import SwiftData
import Combine
import UIKit
import os.log
import BackgroundTasks

// MARK: - Sync Engine

/// Coordinates offline-first sync operations
@MainActor
public final class SyncEngine: ObservableObject {

    // MARK: - Published State

    /// Whether sync is currently in progress
    @Published public private(set) var isSyncing: Bool = false

    /// Date of the last successful sync
    @Published public private(set) var lastSyncDate: Date?

    /// Number of pending operations in the outbox
    @Published public private(set) var pendingOperationCount: Int = 0

    /// The last sync error that occurred
    @Published public private(set) var lastError: SyncError?

    /// Current sync progress (0.0 - 1.0)
    @Published public private(set) var syncProgress: Double = 0.0

    /// Detailed sync status message
    @Published public private(set) var statusMessage: String = "Ready"

    // MARK: - Dependencies

    private let persistence: PersistenceRepositoryProtocol
    private let networkMonitor: NetworkMonitor
    private let repositoryService: RepositoryServiceProtocol
    private let conflictResolver: ConflictResolver
    private let config: AppConfiguration.OfflineSync.Type
    private let logger: Logger

    // MARK: - Sync Control

    private var syncTask: Task<SyncResult, Never>?
    private var backgroundTaskId: UIBackgroundTaskIdentifier = .invalid
    private var automaticSyncCancellable: AnyCancellable?
    private var networkStatusCancellable: AnyCancellable?

    // MARK: - Background Task Identifier

    /// Background task identifier for BGTaskScheduler
    public static let backgroundTaskIdentifier = "com.twinact.fieldcompanion.sync"
    private static var isBackgroundTaskRegistered = false
    private static weak var activeInstance: SyncEngine?

    // MARK: - Initialization

    /// Initialize the sync engine
    /// - Parameters:
    ///   - persistence: The persistence repository
    ///   - networkMonitor: The network monitor
    ///   - repositoryService: The AAS repository service
    ///   - conflictResolver: The conflict resolver
    public init(
        persistence: PersistenceRepositoryProtocol,
        networkMonitor: NetworkMonitor = .shared,
        repositoryService: RepositoryServiceProtocol,
        conflictResolver: ConflictResolver? = nil
    ) {
        self.persistence = persistence
        self.networkMonitor = networkMonitor
        self.repositoryService = repositoryService
        self.conflictResolver = conflictResolver ?? ConflictResolver()
        self.config = AppConfiguration.OfflineSync.self
        self.logger = Logger(
            subsystem: AppConfiguration.AppInfo.bundleIdentifier,
            category: "SyncEngine"
        )

        Self.activeInstance = self

        setupObservers()
        Task { await updatePendingCount() }
    }

    deinit {
        automaticSyncCancellable?.cancel()
        networkStatusCancellable?.cancel()
    }

    // MARK: - Setup

    private func setupObservers() {
        // Monitor network status changes
        networkStatusCancellable = networkMonitor.statusPublisher
            .removeDuplicates()
            .sink { [weak self] status in
                Task { @MainActor [weak self] in
                    self?.handleNetworkStatusChange(status)
                }
            }

        // Setup automatic sync timer
        setupAutomaticSync()
    }

    private func setupAutomaticSync() {
        automaticSyncCancellable?.cancel()

        let interval = config.syncIntervalSeconds
        automaticSyncCancellable = Timer.publish(every: interval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    await self?.triggerSync()
                }
            }

        logger.debug("Automatic sync scheduled every \(interval) seconds")
    }

    private func handleNetworkStatusChange(_ status: NetworkStatus) {
        if status.isConnected && status.shouldAllowSync {
            logger.info("Network connected - checking for pending operations")
            Task {
                await updatePendingCount()
                if pendingOperationCount > 0 {
                    await triggerSync()
                }
            }
        } else {
            logger.debug("Network status changed: connected=\(status.isConnected), allowSync=\(status.shouldAllowSync)")
        }
    }

    // MARK: - Public API

    /// Start sync if conditions allow
    public func triggerSync() async {
        // Don't sync if already syncing
        guard !isSyncing else {
            logger.debug("Sync already in progress, skipping")
            return
        }

        // Check network
        guard networkMonitor.isConnected else {
            logger.debug("No network connection, skipping sync")
            return
        }

        guard networkMonitor.status.shouldAllowSync else {
            logger.debug("Network requirements not met for sync")
            return
        }

        // Check if there's anything to sync
        await updatePendingCount()
        guard pendingOperationCount > 0 else {
            logger.debug("No pending operations, skipping sync")
            return
        }

        // Start sync
        let task = Task { await performSync() }
        syncTask = task
        defer { syncTask = nil }

        let result = await task.value

        if result.isSuccess {
            logger.info("Sync completed successfully: \(result.successCount) operations")
        } else {
            logger.warning("Sync completed with issues: \(result.successCount) success, \(result.failureCount) failed")
        }
    }

    /// Force sync regardless of conditions (user-initiated)
    public func forceSync() async throws -> SyncResult {
        // Check if already syncing
        guard !isSyncing else {
            throw SyncError.syncInProgress
        }

        // Check network
        guard networkMonitor.isConnected else {
            throw SyncError.notConnected
        }

        if !networkMonitor.status.shouldAllowSync {
            let reason = config.syncOnlyOnWiFi ? "Wi-Fi required" : "Network constrained"
            throw SyncError.networkRequirementsNotMet(reason: reason)
        }

        let task = Task { await performSync() }
        syncTask = task
        defer { syncTask = nil }

        return await task.value
    }

    /// Stop any in-progress sync
    public func cancelSync() {
        guard isSyncing else { return }

        logger.info("Cancelling sync")
        syncTask?.cancel()
        isSyncing = false
        statusMessage = "Sync cancelled"
        lastError = .cancelled
    }

    /// Schedule background sync using BGTaskScheduler
    public func scheduleBackgroundSync() {
        guard Self.isBackgroundTaskRegistered else {
            logger.warning("Background task not registered; skipping schedule")
            return
        }

        let request = BGProcessingTaskRequest(identifier: Self.backgroundTaskIdentifier)
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false

        // Schedule for when device is likely to be idle
        request.earliestBeginDate = Date(timeIntervalSinceNow: config.syncIntervalSeconds)

        do {
            try BGTaskScheduler.shared.submit(request)
            logger.info("Background sync scheduled for \(request.earliestBeginDate?.description ?? "soon")")
        } catch {
            logger.error("Failed to schedule background sync: \(error.localizedDescription)")
        }
    }

    /// Update the pending operation count
    public func updatePendingCount() async {
        let stats = await persistence.getOutboxStats()
        pendingOperationCount = stats.totalPending
    }

    // MARK: - Core Sync Logic

    private func performSync() async -> SyncResult {
        // Begin background task for iOS
        beginBackgroundTask()
        defer { endBackgroundTask() }

        isSyncing = true
        lastError = nil
        syncProgress = 0.0
        statusMessage = "Starting sync..."

        // Log sync start
        await logSyncEvent(.syncStarted, details: "Starting sync of pending operations")

        // Fetch pending operations
        let operations = await persistence.getPendingOperations()

        guard !operations.isEmpty else {
            isSyncing = false
            statusMessage = "No pending operations"
            return SyncResult()
        }

        logger.info("Processing \(operations.count) pending operations")
        statusMessage = "Processing \(operations.count) operations..."

        var successCount = 0
        var failureCount = 0
        var skippedCount = 0
        var errors: [SyncError] = []

        for (index, operation) in operations.enumerated() {
            // Check for cancellation
            if Task.isCancelled {
                logger.debug("Sync cancelled at operation \(index)")
                await logSyncEvent(.syncFailed, details: "Sync cancelled")
                isSyncing = false
                return SyncResult(
                    successCount: successCount,
                    failureCount: failureCount,
                    skippedCount: operations.count - index,
                    errors: [.cancelled]
                )
            }

            // Update progress
            syncProgress = Double(index) / Double(operations.count)
            statusMessage = "Syncing \(index + 1) of \(operations.count)..."

            // Process the operation
            let result = await processOperation(operation)

            switch result {
            case .success:
                successCount += 1
                logger.debug("Operation \(operation.id) synced successfully")

            case .failure(let error):
                if error.requiresUserAction {
                    skippedCount += 1
                    errors.append(error)
                    logger.warning("Operation \(operation.id) skipped: \(error.localizedDescription)")
                } else {
                    failureCount += 1
                    errors.append(error)
                    logger.error("Operation \(operation.id) failed: \(error.localizedDescription)")
                }
            }

            // Small delay between operations to avoid overwhelming the server
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }

        // Update state
        syncProgress = 1.0
        isSyncing = false
        lastSyncDate = Date()
        await updatePendingCount()

        // Create result
        let result = SyncResult(
            successCount: successCount,
            failureCount: failureCount,
            skippedCount: skippedCount,
            errors: errors
        )

        // Update status message
        if result.isSuccess {
            statusMessage = "Sync completed: \(successCount) synced"
            await logSyncEvent(.syncCompleted, details: "Synced \(successCount) operations")
        } else {
            statusMessage = "Sync completed: \(successCount) synced, \(failureCount) failed"
            lastError = errors.first
            await logSyncEvent(.syncFailed, details: "Synced \(successCount), failed \(failureCount)")
        }

        // Clean up old completed operations
        await cleanupCompletedOperations()

        // Schedule next background sync
        scheduleBackgroundSync()

        return result
    }

    // MARK: - Operation Processing

    private func processOperation(_ operation: OutboxOperation) async -> Result<Void, SyncError> {
        // Mark as in progress
        operation.markInProgress()
        try? await persistence.addToOutbox(operation)

        // Check retry count
        if operation.hasExceededMaxRetries {
            let error = SyncError.maxRetriesExceeded(
                operationId: operation.id,
                attempts: operation.attemptCount
            )
            try? await persistence.markOperationFailed(operation.id, error: error.localizedDescription)
            return .failure(error)
        }

        do {
            switch operation.operationType {
            case .create:
                try await processCreateOperation(operation)

            case .update:
                try await processUpdateOperation(operation)

            case .delete:
                try await processDeleteOperation(operation)
            }

            // Success - mark complete
            try await persistence.markOperationComplete(operation.id)

            // Log success
            await logSyncEvent(
                .serviceRequestSynced,
                entityType: operation.entityType,
                entityId: operation.entityId,
                details: "Operation \(operation.operationType.rawValue) synced"
            )

            return .success(())

        } catch let syncError as SyncError {
            try? await persistence.markOperationFailed(operation.id, error: syncError.localizedDescription)
            return .failure(syncError)

        } catch let aasError as AASError {
            let syncError = mapAASError(aasError, operationId: operation.id)

            // For not found errors on delete, consider it success
            if operation.operationType == .delete && aasError.isNotFound {
                try? await persistence.markOperationComplete(operation.id)
                return .success(())
            }

            try? await persistence.markOperationFailed(operation.id, error: syncError.localizedDescription)
            return .failure(syncError)

        } catch {
            let syncError = SyncError.operationFailed(operationId: operation.id, underlying: error)
            try? await persistence.markOperationFailed(operation.id, error: error.localizedDescription)
            return .failure(syncError)
        }
    }

    private func processCreateOperation(_ operation: OutboxOperation) async throws {
        logger.debug("Processing CREATE for \(operation.entityType): \(operation.entityId)")

        // Decode the payload
        guard let element = try? decodeSubmodelElement(from: operation.payload) else {
            throw SyncError.payloadDecodingFailed(operationId: operation.id, underlying: DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Invalid payload")))
        }

        // Create on server
        try await repositoryService.createSubmodelElement(
            submodelId: operation.submodelId,
            element: element
        )

        logger.debug("CREATE completed for \(operation.entityId)")
    }

    private func processUpdateOperation(_ operation: OutboxOperation) async throws {
        logger.debug("Processing UPDATE for \(operation.entityType): \(operation.entityId)")

        // First, check for conflicts by fetching current server version
        let serverElement: SubmodelElement
        do {
            serverElement = try await repositoryService.getSubmodelElement(
                submodelId: operation.submodelId,
                idShortPath: operation.entityId
            )
        } catch let error as AASError where error.isNotFound {
            // Element doesn't exist on server - convert to create
            logger.debug("Element not found on server, converting to create")
            return try await processCreateOperation(operation)
        }

        // Decode local payload
        guard let localElement = try? decodeSubmodelElement(from: operation.payload) else {
            throw SyncError.payloadDecodingFailed(operationId: operation.id, underlying: DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Invalid payload")))
        }

        // Check for conflict by comparing versions/timestamps
        if hasConflict(local: localElement, server: serverElement) {
            let resolution = resolveConflict(
                operation: operation,
                localElement: localElement,
                serverElement: serverElement
            )

            switch resolution {
            case .useServer:
                // Discard local changes
                logger.debug("Conflict resolved: using server version")
                return

            case .useClient(let data):
                // Update with local version
                guard let resolvedElement = try? decodeSubmodelElement(from: data) else {
                    throw SyncError.payloadDecodingFailed(operationId: operation.id, underlying: DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Invalid resolved data")))
                }
                try await repositoryService.updateSubmodelElement(
                    submodelId: operation.submodelId,
                    idShortPath: operation.entityId,
                    element: resolvedElement
                )

            case .merged(let data):
                // Update with merged version
                guard let mergedElement = try? decodeSubmodelElement(from: data) else {
                    throw SyncError.payloadDecodingFailed(operationId: operation.id, underlying: DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Invalid merged data")))
                }
                try await repositoryService.updateSubmodelElement(
                    submodelId: operation.submodelId,
                    idShortPath: operation.entityId,
                    element: mergedElement
                )

            case .requiresManualResolution(let local, let server):
                throw SyncError.manualResolutionRequired(
                    operationId: operation.id,
                    localVersion: String(data: local, encoding: .utf8) ?? "",
                    serverVersion: String(data: server, encoding: .utf8) ?? ""
                )
            }
        } else {
            // No conflict - proceed with update
            try await repositoryService.updateSubmodelElement(
                submodelId: operation.submodelId,
                idShortPath: operation.entityId,
                element: localElement
            )
        }

        logger.debug("UPDATE completed for \(operation.entityId)")
    }

    private func processDeleteOperation(_ operation: OutboxOperation) async throws {
        logger.debug("Processing DELETE for \(operation.entityType): \(operation.entityId)")

        try await repositoryService.deleteSubmodelElement(
            submodelId: operation.submodelId,
            idShortPath: operation.entityId
        )

        logger.debug("DELETE completed for \(operation.entityId)")
    }

    // MARK: - Conflict Detection and Resolution

    private func hasConflict(local: SubmodelElement, server: SubmodelElement) -> Bool {
        // Compare based on element type
        // In a real implementation, you'd compare version numbers or ETags

        // For now, we'll use a simple comparison of the encoded data
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys

        guard let localData = try? encoder.encode(local),
              let serverData = try? encoder.encode(server) else {
            return true // Can't compare, assume conflict
        }

        return localData != serverData
    }

    private func resolveConflict(
        operation: OutboxOperation,
        localElement: SubmodelElement,
        serverElement: SubmodelElement
    ) -> ConflictResolver.Resolution {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        let localData = (try? encoder.encode(localElement)) ?? Data()
        let serverData = (try? encoder.encode(serverElement)) ?? Data()

        // Get timestamps if available
        let localTimestamp = operation.lastAttemptAt ?? operation.createdAt
        let serverTimestamp: Date? = nil // Would come from server metadata

        let resolution = conflictResolver.resolve(
            localData: localData,
            serverData: serverData,
            localTimestamp: localTimestamp,
            serverTimestamp: serverTimestamp
        )

        // Log the conflict
        logger.info("Conflict detected for \(operation.entityId), resolution: \(resolution.description)")

        return resolution
    }

    // MARK: - Helper Methods

    private func decodeSubmodelElement(from data: Data) throws -> SubmodelElement {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(SubmodelElement.self, from: data)
    }

    private func mapAASError(_ error: AASError, operationId: UUID) -> SyncError {
        if error.isNotFound {
            return .resourceNotFound(operationId: operationId, entityId: "unknown")
        }

        if let statusCode = error.statusCode {
            return .serverError(
                operationId: operationId,
                statusCode: statusCode,
                message: error.localizedDescription
            )
        }

        return .operationFailed(operationId: operationId, underlying: error)
    }

    private func cleanupCompletedOperations() async {
        // Delete completed operations older than 24 hours
        let cutoffDate = Date().addingTimeInterval(-24 * 60 * 60)
        try? await persistence.deleteCompletedOperations(olderThan: cutoffDate)
    }

    // MARK: - Audit Logging

    private func logSyncEvent(
        _ actionType: AuditActionType,
        entityType: String = "Sync",
        entityId: String? = nil,
        details: String? = nil
    ) async {
        let entry = AuditEntry(
            syncAction: actionType,
            entityType: entityType,
            entityId: entityId,
            status: statusMessage,
            error: lastError?.localizedDescription
        )

        if let details = details {
            entry.details = details
        }

        try? await persistence.addAuditEntry(entry)
    }

    // MARK: - Background Task Management

    private func beginBackgroundTask() {
        guard backgroundTaskId == .invalid else { return }

        backgroundTaskId = UIApplication.shared.beginBackgroundTask(withName: "SyncEngine") { [weak self] in
            self?.handleBackgroundTaskExpiration()
        }

        logger.debug("Background task started: \(self.backgroundTaskId.rawValue)")
    }

    private func endBackgroundTask() {
        guard backgroundTaskId != .invalid else { return }

        UIApplication.shared.endBackgroundTask(backgroundTaskId)
        logger.debug("Background task ended: \(self.backgroundTaskId.rawValue)")
        backgroundTaskId = .invalid
    }

    private func handleBackgroundTaskExpiration() {
        logger.warning("Background task expiring, cancelling sync")
        cancelSync()
        lastError = .backgroundTaskExpired
        endBackgroundTask()
    }
}

// MARK: - Background Fetch Support

extension SyncEngine {

    /// Handle a background fetch request
    /// - Returns: The fetch result
    public func handleBackgroundFetch() async -> UIBackgroundFetchResult {
        logger.info("Handling background fetch")

        guard networkMonitor.isConnected else {
            logger.debug("No network for background fetch")
            return .noData
        }

        await updatePendingCount()

        guard pendingOperationCount > 0 else {
            logger.debug("No pending operations for background fetch")
            return .noData
        }

        do {
            let result = try await forceSync()

            if result.isSuccess {
                logger.info("Background fetch completed successfully")
                return .newData
            } else {
                logger.warning("Background fetch completed with errors")
                return result.errors.isEmpty ? .noData : .failed
            }
        } catch {
            logger.error("Background fetch failed: \(error.localizedDescription)")
            return .failed
        }
    }

    /// Register the background task with BGTaskScheduler
    public static func registerBackgroundTask() {
        guard !isBackgroundTaskRegistered else { return }

        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: backgroundTaskIdentifier,
            using: nil
        ) { task in
            guard let processingTask = task as? BGProcessingTask else {
                task.setTaskCompleted(success: false)
                return
            }

            Task { @MainActor in
                let engine = activeInstance ?? SyncEngine(
                    persistence: PersistenceService(),
                    repositoryService: RepositoryService()
                )
                engine.handleBackgroundProcessingTask(processingTask)
            }
        }

        isBackgroundTaskRegistered = true
    }
}

// MARK: - Background Processing Support

extension SyncEngine {
    /// Handle a BGProcessingTask for background sync.
    public func handleBackgroundProcessingTask(_ task: BGProcessingTask) {
        task.expirationHandler = { [weak self] in
            Task { @MainActor in
                self?.cancelSync()
            }
        }

        Task { @MainActor [weak self] in
            guard let self else {
                task.setTaskCompleted(success: false)
                return
            }

            do {
                let result = try await self.forceSync()
                task.setTaskCompleted(success: result.isSuccess)
            } catch {
                self.logger.error("Background sync failed: \(error.localizedDescription)")
                task.setTaskCompleted(success: false)
            }
        }
    }
}

// MARK: - Combine Publishers

extension SyncEngine {

    /// Publisher for sync state changes
    public var syncStatePublisher: AnyPublisher<Bool, Never> {
        $isSyncing.eraseToAnyPublisher()
    }

    /// Publisher for pending operation count changes
    public var pendingCountPublisher: AnyPublisher<Int, Never> {
        $pendingOperationCount.eraseToAnyPublisher()
    }

    /// Publisher for sync errors
    public var errorPublisher: AnyPublisher<SyncError?, Never> {
        $lastError.eraseToAnyPublisher()
    }

    /// Publisher for sync progress
    public var progressPublisher: AnyPublisher<Double, Never> {
        $syncProgress.eraseToAnyPublisher()
    }
}

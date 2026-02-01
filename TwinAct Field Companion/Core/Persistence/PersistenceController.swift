//
//  PersistenceController.swift
//  TwinAct Field Companion
//
//  Main SwiftData persistence controller
//

import Foundation
import SwiftData
import SwiftUI
import Combine
import os.log

/// Logger for persistence operations
private let persistenceLogger = Logger(subsystem: "com.twinact.fieldcompanion", category: "Persistence")

// MARK: - Persistence Controller

/// Main persistence controller for SwiftData
///
/// Manages the SwiftData ModelContainer and provides access to the
/// main ModelContext. Supports both production and in-memory (preview/testing)
/// configurations.
@MainActor
public final class PersistenceController: ObservableObject {

    // MARK: - Shared Instance

    /// Shared singleton instance for production use
    public static let shared = PersistenceController()

    // MARK: - Properties

    /// The SwiftData model container
    public let container: ModelContainer

    /// Main context for database operations
    public var context: ModelContext {
        container.mainContext
    }

    // MARK: - Preview Instance

    /// Preview instance with in-memory storage and sample data
    public static var preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)

        // Add sample data for previews
        Task { @MainActor in
            controller.addSampleData()
        }

        return controller
    }()

    // MARK: - Initialization

    /// Initialize the persistence controller
    /// - Parameter inMemory: If true, uses in-memory storage (for testing/previews)
    public init(inMemory: Bool = false) {
        // Define the schema with all models
        let schema = Schema([
            OutboxOperation.self,
            AuditEntry.self,
            CachedSubmodel.self,
            CachedDocument.self
        ])

        // Configure storage
        let config: ModelConfiguration
        if inMemory {
            config = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: true
            )
        } else {
            config = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                allowsSave: true
            )
        }

        do {
            container = try ModelContainer(for: schema, configurations: [config])

            // Configure auto-save
            container.mainContext.autosaveEnabled = true

        } catch {
            persistenceLogger.error("Failed to create ModelContainer: \(error.localizedDescription)")

            let fallbackConfig = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: true
            )

            do {
                container = try ModelContainer(for: schema, configurations: [fallbackConfig])
                container.mainContext.autosaveEnabled = true
                persistenceLogger.info("Using in-memory storage as a fallback for persistence.")
            } catch {
                persistenceLogger.fault("Failed to create fallback in-memory ModelContainer: \(error.localizedDescription)")
                preconditionFailure("PersistenceController could not initialize storage.")
            }
        }
    }

    // MARK: - Sample Data

    /// Add sample data for previews and testing
    private func addSampleData() {
        // Sample outbox operation
        let outboxOp = OutboxOperation(
            operationType: .create,
            entityType: "ServiceRequest",
            entityId: "sr-001",
            submodelId: "urn:example:submodel:service-requests",
            payload: "{}".data(using: .utf8)!,
            priority: 1
        )
        context.insert(outboxOp)

        // Sample audit entries
        let auditEntries = [
            AuditEntry(
                actionType: .loginSuccess,
                entityType: "Authentication",
                details: "User logged in successfully"
            ),
            AuditEntry(
                actionType: .assetScanned,
                entityType: "Asset",
                entityId: "urn:example:aas:pump-001",
                details: "QR code scanned"
            ),
            AuditEntry(
                actionType: .serviceRequestCreated,
                entityType: "ServiceRequest",
                entityId: "sr-001",
                details: "New service request created offline"
            )
        ]
        auditEntries.forEach { context.insert($0) }

        // Sample cached submodel
        let sampleSubmodelData = """
        {
            "idShort": "TechnicalData",
            "id": "urn:example:submodel:technical-data",
            "semanticId": {
                "keys": [{"value": "https://admin-shell.io/ZVEI/TechnicalData/Submodel/1/2"}]
            }
        }
        """.data(using: .utf8)!

        let cachedSubmodel = CachedSubmodel(
            id: "urn:example:submodel:technical-data",
            aasId: "urn:example:aas:pump-001",
            semanticId: "https://admin-shell.io/ZVEI/TechnicalData/Submodel/1/2",
            idShort: "TechnicalData",
            data: sampleSubmodelData,
            ttlSeconds: CachedSubmodel.TTL.staticData
        )
        context.insert(cachedSubmodel)

        // Sample cached document
        let cachedDoc = CachedDocument(
            id: "doc-001",
            aasId: "urn:example:aas:pump-001",
            submodelId: "urn:example:submodel:documentation",
            title: "Installation Manual.pdf",
            fileType: "application/pdf",
            fileSize: 2_500_000,
            localPath: "doc_doc-001.pdf",
            remoteURL: "https://example.com/docs/installation-manual.pdf"
        )
        context.insert(cachedDoc)

        // Save the context
        do {
            try context.save()
        } catch {
            persistenceLogger.error("Failed to save sample data: \(error.localizedDescription)")
        }
    }

    // MARK: - Utility Methods

    /// Save the context if there are changes
    public func saveIfNeeded() throws {
        if context.hasChanges {
            try context.save()
        }
    }

    /// Reset the database (for testing purposes)
    public func resetDatabase() throws {
        // Delete all entities
        try context.delete(model: OutboxOperation.self)
        try context.delete(model: AuditEntry.self)
        try context.delete(model: CachedSubmodel.self)
        try context.delete(model: CachedDocument.self)

        try context.save()
    }

    /// Get database statistics
    public func getDatabaseStats() async -> DatabaseStats {
        let outboxCount = (try? context.fetchCount(FetchDescriptor<OutboxOperation>())) ?? 0
        let auditCount = (try? context.fetchCount(FetchDescriptor<AuditEntry>())) ?? 0
        let submodelCount = (try? context.fetchCount(FetchDescriptor<CachedSubmodel>())) ?? 0
        let documentCount = (try? context.fetchCount(FetchDescriptor<CachedDocument>())) ?? 0

        return DatabaseStats(
            outboxOperationCount: outboxCount,
            auditEntryCount: auditCount,
            cachedSubmodelCount: submodelCount,
            cachedDocumentCount: documentCount
        )
    }
}

// MARK: - Database Stats

/// Statistics about the database contents
public struct DatabaseStats {
    public let outboxOperationCount: Int
    public let auditEntryCount: Int
    public let cachedSubmodelCount: Int
    public let cachedDocumentCount: Int

    public var totalRecords: Int {
        outboxOperationCount + auditEntryCount + cachedSubmodelCount + cachedDocumentCount
    }
}

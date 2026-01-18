//
//  ConflictResolver.swift
//  TwinAct Field Companion
//
//  Domain-specific conflict resolution for offline-first sync
//

import Foundation

// MARK: - Timestamped Protocol

/// Protocol for entities that track modification timestamps
public protocol Timestamped {
    /// The last modification date of the entity
    var lastModified: Date { get }
}

// MARK: - Versioned Protocol

/// Protocol for entities that track version information
public protocol Versioned {
    /// The version string of the entity
    var version: String? { get }
}

// MARK: - Conflict Resolver

/// Handles merge conflicts between local and server data
public struct ConflictResolver: Sendable {

    // MARK: - Resolution Types

    /// The result of conflict resolution
    public enum Resolution: Sendable {
        /// Use the server version, discarding local changes
        case useServer(Data)

        /// Use the local/client version, overwriting server
        case useClient(Data)

        /// Use a merged version combining both
        case merged(Data)

        /// Conflict cannot be auto-resolved, requires user input
        case requiresManualResolution(local: Data, server: Data)
    }

    // MARK: - Properties

    /// The strategy to use for resolving conflicts
    public let strategy: AppConfiguration.OfflineSync.ConflictResolutionStrategy

    // MARK: - Initialization

    public init(strategy: AppConfiguration.OfflineSync.ConflictResolutionStrategy = AppConfiguration.OfflineSync.conflictResolutionStrategy) {
        self.strategy = strategy
    }

    // MARK: - Generic Resolution

    /// Resolve conflict based on configured strategy
    /// - Parameters:
    ///   - localData: The local version data
    ///   - serverData: The server version data
    ///   - localTimestamp: When local version was last modified
    ///   - serverTimestamp: When server version was last modified
    /// - Returns: The resolution decision
    public func resolve(
        localData: Data,
        serverData: Data,
        localTimestamp: Date?,
        serverTimestamp: Date?
    ) -> Resolution {
        switch strategy {
        case .serverWins:
            return .useServer(serverData)

        case .clientWins:
            return .useClient(localData)

        case .lastWriteWins:
            return resolveByTimestamp(
                localData: localData,
                serverData: serverData,
                localTimestamp: localTimestamp,
                serverTimestamp: serverTimestamp
            )

        case .manualResolution:
            return .requiresManualResolution(local: localData, server: serverData)
        }
    }

    /// Resolve conflict based on timestamps
    /// - Parameters:
    ///   - localData: The local version data
    ///   - serverData: The server version data
    ///   - localTimestamp: When local version was last modified
    ///   - serverTimestamp: When server version was last modified
    /// - Returns: The resolution decision
    public func resolveByTimestamp(
        localData: Data,
        serverData: Data,
        localTimestamp: Date?,
        serverTimestamp: Date?
    ) -> Resolution {
        // If both timestamps are available, compare them
        if let local = localTimestamp, let server = serverTimestamp {
            if local > server {
                return .useClient(localData)
            } else {
                return .useServer(serverData)
            }
        }

        // If only one timestamp is available, prefer that version
        if localTimestamp != nil && serverTimestamp == nil {
            return .useClient(localData)
        }

        if serverTimestamp != nil && localTimestamp == nil {
            return .useServer(serverData)
        }

        // No timestamps available - default to server wins
        return .useServer(serverData)
    }

    /// Resolve conflict for timestamped entities
    /// - Parameters:
    ///   - local: The local version
    ///   - server: The server version
    /// - Returns: The resolution decision
    public func resolveByTimestamp<T: Timestamped & Encodable>(
        local: T,
        server: T
    ) -> Resolution {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        do {
            let localData = try encoder.encode(local)
            let serverData = try encoder.encode(server)

            return resolveByTimestamp(
                localData: localData,
                serverData: serverData,
                localTimestamp: local.lastModified,
                serverTimestamp: server.lastModified
            )
        } catch {
            // Encoding failed - require manual resolution
            return .requiresManualResolution(local: Data(), server: Data())
        }
    }

    // MARK: - ServiceRequest Resolution

    /// Resolve conflict for ServiceRequest entities
    /// - Parameters:
    ///   - local: The local service request
    ///   - server: The server service request
    /// - Returns: The resolution decision
    public func resolveServiceRequest(
        local: ServiceRequest,
        server: ServiceRequest
    ) -> Resolution {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        guard let localData = try? encoder.encode(local),
              let serverData = try? encoder.encode(server) else {
            return .requiresManualResolution(local: Data(), server: Data())
        }

        switch strategy {
        case .serverWins:
            return .useServer(serverData)

        case .clientWins:
            return .useClient(localData)

        case .lastWriteWins:
            // For ServiceRequest, use requestDate as the timestamp
            // In a real scenario, you'd want a dedicated lastModified field
            return resolveByTimestamp(
                localData: localData,
                serverData: serverData,
                localTimestamp: local.requestDate,
                serverTimestamp: server.requestDate
            )

        case .manualResolution:
            return .requiresManualResolution(local: localData, server: serverData)
        }
    }

    /// Attempt to merge ServiceRequest changes
    /// This is a domain-specific merge that tries to combine non-conflicting changes
    /// - Parameters:
    ///   - local: The local service request
    ///   - server: The server service request
    ///   - base: The original version before changes (if available)
    /// - Returns: The merged result, or nil if merge is not possible
    public func mergeServiceRequest(
        local: ServiceRequest,
        server: ServiceRequest,
        base: ServiceRequest? = nil
    ) -> ServiceRequest? {
        // If IDs don't match, cannot merge
        guard local.id == server.id else { return nil }

        // Start with server as base
        var merged = server

        // Apply local changes that don't conflict with server
        // This is a simplified merge - in production you'd want field-level tracking

        // If local status is more advanced, keep it
        if local.status.sortOrder > server.status.sortOrder {
            merged.status = local.status
        }

        // Merge notes from both
        var allNotes: [ServiceNote] = []
        if let serverNotes = server.notes {
            allNotes.append(contentsOf: serverNotes)
        }
        if let localNotes = local.notes {
            // Add local notes that aren't already in server notes
            for note in localNotes {
                let isDuplicate = allNotes.contains { existing in
                    existing.timestamp == note.timestamp &&
                    existing.author == note.author &&
                    existing.text == note.text
                }
                if !isDuplicate {
                    allNotes.append(note)
                }
            }
        }
        if !allNotes.isEmpty {
            merged.notes = allNotes.sorted { $0.timestamp < $1.timestamp }
        }

        // Merge attachments from both
        var allAttachments: [URL] = []
        if let serverAttachments = server.attachments {
            allAttachments.append(contentsOf: serverAttachments)
        }
        if let localAttachments = local.attachments {
            for attachment in localAttachments {
                if !allAttachments.contains(attachment) {
                    allAttachments.append(attachment)
                }
            }
        }
        if !allAttachments.isEmpty {
            merged.attachments = allAttachments
        }

        // Use the most recent dates
        if let localScheduled = local.scheduledDate,
           let serverScheduled = server.scheduledDate,
           localScheduled > serverScheduled {
            merged.scheduledDate = localScheduled
        } else if let localScheduled = local.scheduledDate, server.scheduledDate == nil {
            merged.scheduledDate = localScheduled
        }

        if let localCompleted = local.completedDate,
           server.completedDate == nil {
            merged.completedDate = localCompleted
        }

        // Keep assignment if set locally but not on server
        if let localAssigned = local.assignedTo, server.assignedTo == nil {
            merged.assignedTo = localAssigned
        }

        return merged
    }
}

// MARK: - ServiceRequestStatus Sort Order

extension ServiceRequestStatus {
    /// Numeric value for status progression (higher = more advanced)
    var sortOrder: Int {
        switch self {
        case .new: return 0
        case .inProgress: return 1
        case .onHold: return 2
        case .resolved: return 3
        case .closed: return 4
        }
    }
}

// MARK: - Conflict Info

/// Information about a detected conflict
public struct ConflictInfo: Sendable {
    /// The operation that caused the conflict
    public let operationId: UUID

    /// The entity type
    public let entityType: String

    /// The entity ID
    public let entityId: String

    /// Local version data
    public let localData: Data

    /// Server version data
    public let serverData: Data

    /// Local modification timestamp
    public let localTimestamp: Date?

    /// Server modification timestamp
    public let serverTimestamp: Date?

    /// The resolution strategy that was applied
    public let appliedStrategy: AppConfiguration.OfflineSync.ConflictResolutionStrategy

    /// The resolution result
    public let resolution: ConflictResolver.Resolution

    /// When the conflict was detected
    public let detectedAt: Date

    public init(
        operationId: UUID,
        entityType: String,
        entityId: String,
        localData: Data,
        serverData: Data,
        localTimestamp: Date? = nil,
        serverTimestamp: Date? = nil,
        appliedStrategy: AppConfiguration.OfflineSync.ConflictResolutionStrategy,
        resolution: ConflictResolver.Resolution
    ) {
        self.operationId = operationId
        self.entityType = entityType
        self.entityId = entityId
        self.localData = localData
        self.serverData = serverData
        self.localTimestamp = localTimestamp
        self.serverTimestamp = serverTimestamp
        self.appliedStrategy = appliedStrategy
        self.resolution = resolution
        self.detectedAt = Date()
    }

    /// Human-readable description of the conflict
    public var description: String {
        var desc = "Conflict in \(entityType) (\(entityId))"

        if let local = localTimestamp, let server = serverTimestamp {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .short
            desc += " - Local: \(formatter.localizedString(for: local, relativeTo: Date()))"
            desc += ", Server: \(formatter.localizedString(for: server, relativeTo: Date()))"
        }

        return desc
    }
}

// MARK: - Conflict Resolution Extension for Data

extension ConflictResolver.Resolution {
    /// Get the resolved data if available
    public var resolvedData: Data? {
        switch self {
        case .useServer(let data), .useClient(let data), .merged(let data):
            return data
        case .requiresManualResolution:
            return nil
        }
    }

    /// Whether this resolution was automatic
    public var isAutomatic: Bool {
        switch self {
        case .useServer, .useClient, .merged:
            return true
        case .requiresManualResolution:
            return false
        }
    }

    /// Human-readable description of the resolution
    public var description: String {
        switch self {
        case .useServer:
            return "Using server version"
        case .useClient:
            return "Using local version"
        case .merged:
            return "Using merged version"
        case .requiresManualResolution:
            return "Requires manual resolution"
        }
    }
}

//
//  CachedSubmodel.swift
//  TwinAct Field Companion
//
//  SwiftData model for cached submodel data
//

import Foundation
import SwiftData

// MARK: - Cached Submodel Model

/// Cached submodel data for offline access
///
/// Stores AAS submodel data locally to enable offline browsing
/// of asset information. Includes TTL-based expiration and
/// version tracking for conflict detection during sync.
@Model
public final class CachedSubmodel {

    // MARK: - Properties

    /// Submodel ID (primary identifier)
    @Attribute(.unique)
    public var id: String

    /// Parent AAS ID
    public var aasId: String

    /// IDTA template semantic ID (e.g., "https://admin-shell.io/ZVEI/TechnicalData/1/2")
    public var semanticId: String?

    /// Short identifier for the submodel
    public var idShort: String?

    /// JSON serialized submodel data
    public var data: Data

    /// When this cache entry was created/updated
    public var fetchedAt: Date

    /// When this cache entry expires
    public var expiresAt: Date?

    /// Version string for conflict detection
    public var version: String?

    /// ETag from server response (if available)
    public var etag: String?

    /// Last-Modified header from server (if available)
    public var lastModified: Date?

    /// Size of the cached data in bytes
    public var dataSize: Int

    /// Number of times this cache entry has been accessed
    public var accessCount: Int

    /// Last time this cache entry was accessed
    public var lastAccessedAt: Date

    // MARK: - Initialization

    public init(
        id: String,
        aasId: String,
        semanticId: String?,
        idShort: String?,
        data: Data,
        ttlSeconds: TimeInterval = 3600     // 1 hour default
    ) {
        self.id = id
        self.aasId = aasId
        self.semanticId = semanticId
        self.idShort = idShort
        self.data = data
        self.fetchedAt = Date()
        self.expiresAt = Date().addingTimeInterval(ttlSeconds)
        self.dataSize = data.count
        self.accessCount = 0
        self.lastAccessedAt = Date()
    }

    // MARK: - Computed Properties

    /// Whether this cache entry has expired
    public var isExpired: Bool {
        guard let expiresAt = expiresAt else { return false }
        return Date() > expiresAt
    }

    /// Whether this cache entry is still valid
    public var isValid: Bool {
        !isExpired && !data.isEmpty
    }

    /// Age of the cache entry in seconds
    public var age: TimeInterval {
        Date().timeIntervalSince(fetchedAt)
    }

    /// Time until expiration in seconds (negative if expired)
    public var timeUntilExpiration: TimeInterval? {
        guard let expiresAt = expiresAt else { return nil }
        return expiresAt.timeIntervalSince(Date())
    }

    // MARK: - Methods

    /// Record an access to this cache entry
    public func recordAccess() {
        accessCount += 1
        lastAccessedAt = Date()
    }

    /// Update the cached data
    public func updateData(_ newData: Data, ttlSeconds: TimeInterval = 3600) {
        self.data = newData
        self.dataSize = newData.count
        self.fetchedAt = Date()
        self.expiresAt = Date().addingTimeInterval(ttlSeconds)
    }

    /// Extend the TTL without updating data
    public func extendTTL(by seconds: TimeInterval) {
        if let currentExpiration = expiresAt {
            expiresAt = currentExpiration.addingTimeInterval(seconds)
        } else {
            expiresAt = Date().addingTimeInterval(seconds)
        }
    }

    /// Invalidate this cache entry
    public func invalidate() {
        expiresAt = Date()
    }

    // MARK: - Decoding

    /// Decode the cached data to a specific type
    public func decode<T: Decodable>(as type: T.Type) throws -> T {
        let decoder = JSONDecoder()
        return try decoder.decode(type, from: data)
    }
}

// MARK: - TTL Constants

public extension CachedSubmodel {
    /// Default TTL values for different submodel types
    enum TTL {
        /// Static data like nameplate, technical data (24 hours)
        public static let staticData: TimeInterval = 86400

        /// Semi-static data like documentation (4 hours)
        public static let semiStaticData: TimeInterval = 14400

        /// Dynamic data like operational data (15 minutes)
        public static let dynamicData: TimeInterval = 900

        /// Frequently changing data (5 minutes)
        public static let frequentData: TimeInterval = 300

        /// Default TTL (1 hour)
        public static let `default`: TimeInterval = 3600
    }
}

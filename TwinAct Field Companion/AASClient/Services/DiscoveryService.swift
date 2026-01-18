//
//  DiscoveryService.swift
//  TwinAct Field Companion
//
//  AAS Discovery Service - finds shells by asset ID.
//  Implements the AAS API v3 Discovery interface.
//

import Foundation
import os.log

// MARK: - Discovery Service Protocol

/// AAS Discovery Service protocol for finding shells by asset identifiers.
public protocol DiscoveryServiceProtocol: Sendable {
    /// Lookup AAS identifiers by asset identifiers.
    /// - Parameter assetIds: Array of specific asset IDs to search for
    /// - Returns: Array of matching AAS identifiers
    func lookupShells(assetIds: [SpecificAssetId]) async throws -> [String]

    /// Lookup AAS identifiers by a single asset ID (convenience method).
    /// - Parameters:
    ///   - name: Asset ID name (e.g., "serialNumber", "partNumber")
    ///   - value: Asset ID value
    /// - Returns: Array of matching AAS identifiers
    func lookupShells(name: String, value: String) async throws -> [String]

    /// Get all linked AAS identifiers for a specific AAS.
    /// - Parameter aasId: The AAS identifier
    /// - Returns: Array of all asset IDs linked to this AAS
    func getAllLinkedAssetIds(aasId: String) async throws -> [SpecificAssetId]

    /// Link asset IDs to an AAS (if supported by server).
    /// - Parameters:
    ///   - aasId: The AAS identifier
    ///   - assetIds: Asset IDs to link
    func linkAssetIds(aasId: String, assetIds: [SpecificAssetId]) async throws

    /// Unlink asset IDs from an AAS (if supported by server).
    /// - Parameters:
    ///   - aasId: The AAS identifier
    ///   - assetIds: Asset IDs to unlink
    func unlinkAssetIds(aasId: String, assetIds: [SpecificAssetId]) async throws
}

// MARK: - Discovery Service Implementation

/// Implementation of AAS Discovery Service.
public final class DiscoveryService: DiscoveryServiceProtocol, @unchecked Sendable {

    // MARK: - Properties

    private let httpClient: HTTPClient
    private let logger: Logger

    // MARK: - Initialization

    /// Initialize with an HTTP client.
    /// - Parameter httpClient: Pre-configured HTTP client for discovery service
    public init(httpClient: HTTPClient) {
        self.httpClient = httpClient
        self.logger = Logger(
            subsystem: AppConfiguration.AppInfo.bundleIdentifier,
            category: "DiscoveryService"
        )
    }

    /// Initialize with default discovery service configuration.
    /// - Parameter tokenProvider: Optional token provider for authentication
    public convenience init(tokenProvider: TokenProvider? = nil) {
        self.init(httpClient: HTTPClient.forDiscovery(tokenProvider: tokenProvider))
    }

    // MARK: - DiscoveryServiceProtocol Implementation

    public func lookupShells(assetIds: [SpecificAssetId]) async throws -> [String] {
        logger.debug("Looking up shells for \(assetIds.count) asset IDs")

        // AAS Discovery API: POST /lookup/shells
        // Body contains the asset IDs to search for
        let endpoint = try Endpoint.post(
            "/lookup/shells",
            body: assetIds
        )

        do {
            let response: AssetIdLookupResponse = try await httpClient.request(endpoint)
            logger.debug("Found \(response.result.count) matching shells")
            return response.result
        } catch let error as HTTPError {
            throw AASError.from(error, context: "asset lookup")
        }
    }

    public func lookupShells(name: String, value: String) async throws -> [String] {
        let assetId = SpecificAssetId(name: name, value: value)
        return try await lookupShells(assetIds: [assetId])
    }

    public func getAllLinkedAssetIds(aasId: String) async throws -> [SpecificAssetId] {
        logger.debug("Getting linked asset IDs for AAS: \(aasId)")

        // Encode the AAS ID for URL path
        let encodedId = aasB64Url(aasId)

        // AAS Discovery API: GET /lookup/shells/{aasIdentifier}
        let endpoint = Endpoint.get("/lookup/shells/\(encodedId)")

        do {
            let response: [SpecificAssetId] = try await httpClient.request(endpoint)
            logger.debug("Found \(response.count) linked asset IDs")
            return response
        } catch let error as HTTPError {
            if case .notFound = error {
                throw AASError.shellNotFound(identifier: aasId)
            }
            throw AASError.from(error, context: aasId)
        }
    }

    public func linkAssetIds(aasId: String, assetIds: [SpecificAssetId]) async throws {
        logger.debug("Linking \(assetIds.count) asset IDs to AAS: \(aasId)")

        // Encode the AAS ID for URL path
        let encodedId = aasB64Url(aasId)

        // AAS Discovery API: POST /lookup/shells/{aasIdentifier}
        let endpoint = try Endpoint.post(
            "/lookup/shells/\(encodedId)",
            body: assetIds
        )

        do {
            _ = try await httpClient.request(endpoint)
            logger.debug("Successfully linked asset IDs")
        } catch let error as HTTPError {
            if case .notFound = error {
                throw AASError.shellNotFound(identifier: aasId)
            }
            throw AASError.from(error, context: aasId)
        }
    }

    public func unlinkAssetIds(aasId: String, assetIds: [SpecificAssetId]) async throws {
        logger.debug("Unlinking \(assetIds.count) asset IDs from AAS: \(aasId)")

        // Encode the AAS ID for URL path
        let encodedId = aasB64Url(aasId)

        // AAS Discovery API: DELETE /lookup/shells/{aasIdentifier}
        // Note: Asset IDs to unlink are typically sent as query parameters
        // This varies by implementation - some use request body
        var queryItems: [URLQueryItem] = []
        for assetId in assetIds {
            queryItems.append(URLQueryItem(name: "assetIds", value: "\(assetId.name)=\(assetId.value)"))
        }

        let endpoint = Endpoint.delete(
            "/lookup/shells/\(encodedId)",
            queryItems: queryItems
        )

        do {
            _ = try await httpClient.request(endpoint)
            logger.debug("Successfully unlinked asset IDs")
        } catch let error as HTTPError {
            if case .notFound = error {
                throw AASError.shellNotFound(identifier: aasId)
            }
            throw AASError.from(error, context: aasId)
        }
    }
}

// MARK: - Discovery Service Extensions

extension DiscoveryService {
    /// Search for shells by serial number.
    /// - Parameter serialNumber: The serial number to search for
    /// - Returns: Array of matching AAS identifiers
    public func lookupBySerialNumber(_ serialNumber: String) async throws -> [String] {
        try await lookupShells(name: "serialNumber", value: serialNumber)
    }

    /// Search for shells by part number.
    /// - Parameter partNumber: The part number to search for
    /// - Returns: Array of matching AAS identifiers
    public func lookupByPartNumber(_ partNumber: String) async throws -> [String] {
        try await lookupShells(name: "partNumber", value: partNumber)
    }

    /// Search for shells by global asset ID.
    /// - Parameter globalAssetId: The global asset ID to search for
    /// - Returns: Array of matching AAS identifiers
    public func lookupByGlobalAssetId(_ globalAssetId: String) async throws -> [String] {
        try await lookupShells(name: "globalAssetId", value: globalAssetId)
    }

    /// Search for shells by manufacturer part ID (commonly used in DPP).
    /// - Parameter manufacturerPartId: The manufacturer part ID
    /// - Returns: Array of matching AAS identifiers
    public func lookupByManufacturerPartId(_ manufacturerPartId: String) async throws -> [String] {
        try await lookupShells(name: "manufacturerPartId", value: manufacturerPartId)
    }

    /// Search for shells by batch ID.
    /// - Parameter batchId: The batch ID
    /// - Returns: Array of matching AAS identifiers
    public func lookupByBatchId(_ batchId: String) async throws -> [String] {
        try await lookupShells(name: "batchId", value: batchId)
    }
}

//
//  RegistryService.swift
//  TwinAct Field Companion
//
//  AAS Registry Service - gets shell/submodel descriptors.
//  Implements the AAS API v3 Registry interface.
//

import Foundation
import os.log

// MARK: - Registry Service Protocol

/// AAS Registry Service protocol for managing shell and submodel descriptors.
public protocol RegistryServiceProtocol: Sendable {
    /// Get all AAS descriptors (paginated).
    /// - Parameter cursor: Optional cursor for pagination
    /// - Returns: Paginated result of AAS descriptors
    func getAllShellDescriptors(cursor: String?) async throws -> PagedResult<AASDescriptor>

    /// Get specific AAS descriptor by ID.
    /// - Parameter aasId: The AAS identifier
    /// - Returns: The AAS descriptor
    func getShellDescriptor(aasId: String) async throws -> AASDescriptor

    /// Get submodel descriptors for an AAS.
    /// - Parameter aasId: The AAS identifier
    /// - Returns: Array of submodel descriptors
    func getSubmodelDescriptors(aasId: String) async throws -> [SubmodelDescriptor]

    /// Get a specific submodel descriptor.
    /// - Parameters:
    ///   - aasId: The AAS identifier
    ///   - submodelId: The submodel identifier
    /// - Returns: The submodel descriptor
    func getSubmodelDescriptor(aasId: String, submodelId: String) async throws -> SubmodelDescriptor

    /// Search shells by idShort.
    /// - Parameter idShort: The idShort to search for
    /// - Returns: Array of matching AAS descriptors
    func searchShells(idShort: String) async throws -> [AASDescriptor]

    /// Search shells with query parameters.
    /// - Parameter query: Search query parameters
    /// - Returns: Paginated result of matching AAS descriptors
    func searchShells(query: ShellSearchQuery) async throws -> PagedResult<AASDescriptor>

    // MARK: - Write Operations (if supported)

    /// Register a new AAS descriptor.
    /// - Parameter descriptor: The AAS descriptor to register
    func registerShell(descriptor: AASDescriptor) async throws

    /// Update an existing AAS descriptor.
    /// - Parameters:
    ///   - aasId: The AAS identifier
    ///   - descriptor: The updated descriptor
    func updateShellDescriptor(aasId: String, descriptor: AASDescriptor) async throws

    /// Delete an AAS descriptor.
    /// - Parameter aasId: The AAS identifier
    func deleteShellDescriptor(aasId: String) async throws

    /// Register a submodel descriptor for an AAS.
    /// - Parameters:
    ///   - aasId: The AAS identifier
    ///   - descriptor: The submodel descriptor
    func registerSubmodelDescriptor(aasId: String, descriptor: SubmodelDescriptor) async throws

    /// Delete a submodel descriptor.
    /// - Parameters:
    ///   - aasId: The AAS identifier
    ///   - submodelId: The submodel identifier
    func deleteSubmodelDescriptor(aasId: String, submodelId: String) async throws
}

// MARK: - Registry Service Implementation

/// Implementation of AAS Registry Service.
public final class RegistryService: RegistryServiceProtocol, @unchecked Sendable {

    // MARK: - Properties

    private let httpClient: HTTPClient
    private let logger: Logger

    // MARK: - Initialization

    /// Initialize with an HTTP client.
    /// - Parameter httpClient: Pre-configured HTTP client for registry service
    public init(httpClient: HTTPClient) {
        self.httpClient = httpClient
        self.logger = Logger(
            subsystem: AppConfiguration.AppInfo.bundleIdentifier,
            category: "RegistryService"
        )
    }

    /// Initialize with default registry service configuration.
    /// - Parameter tokenProvider: Optional token provider for authentication
    public convenience init(tokenProvider: TokenProvider? = nil) {
        self.init(httpClient: HTTPClient.forRegistry(tokenProvider: tokenProvider))
    }

    // MARK: - Read Operations

    public func getAllShellDescriptors(cursor: String? = nil) async throws -> PagedResult<AASDescriptor> {
        logger.debug("Fetching all shell descriptors")

        var queryItems: [URLQueryItem] = []
        if let cursor = cursor {
            queryItems.append(URLQueryItem(name: "cursor", value: cursor))
        }

        // AAS Registry API: GET /shell-descriptors
        let endpoint = Endpoint.get(
            "/shell-descriptors",
            queryItems: queryItems.isEmpty ? nil : queryItems
        )

        do {
            let response: PagedResult<AASDescriptor> = try await httpClient.request(endpoint)
            logger.debug("Fetched \(response.result.count) shell descriptors")
            return response
        } catch let error as HTTPError {
            throw AASError.from(error)
        }
    }

    public func getShellDescriptor(aasId: String) async throws -> AASDescriptor {
        logger.debug("Fetching shell descriptor for: \(aasId)")

        // Encode the AAS ID for URL path
        let encodedId = aasB64Url(aasId)

        // AAS Registry API: GET /shell-descriptors/{aasIdentifier}
        let endpoint = Endpoint.get("/shell-descriptors/\(encodedId)")

        do {
            let descriptor: AASDescriptor = try await httpClient.request(endpoint)
            logger.debug("Fetched shell descriptor: \(descriptor.idShort ?? "unknown")")
            return descriptor
        } catch let error as HTTPError {
            if case .notFound = error {
                throw AASError.shellNotFound(identifier: aasId)
            }
            throw AASError.from(error, context: aasId)
        }
    }

    public func getSubmodelDescriptors(aasId: String) async throws -> [SubmodelDescriptor] {
        logger.debug("Fetching submodel descriptors for AAS: \(aasId)")

        // Encode the AAS ID for URL path
        let encodedId = aasB64Url(aasId)

        // AAS Registry API: GET /shell-descriptors/{aasIdentifier}/submodel-descriptors
        let endpoint = Endpoint.get("/shell-descriptors/\(encodedId)/submodel-descriptors")

        do {
            let response: PagedResult<SubmodelDescriptor> = try await httpClient.request(endpoint)
            logger.debug("Fetched \(response.result.count) submodel descriptors")
            return response.result
        } catch let error as HTTPError {
            if case .notFound = error {
                throw AASError.shellNotFound(identifier: aasId)
            }
            throw AASError.from(error, context: aasId)
        }
    }

    public func getSubmodelDescriptor(aasId: String, submodelId: String) async throws -> SubmodelDescriptor {
        logger.debug("Fetching submodel descriptor: \(submodelId) for AAS: \(aasId)")

        // Encode IDs for URL path
        let encodedAasId = aasB64Url(aasId)
        let encodedSubmodelId = aasB64Url(submodelId)

        // AAS Registry API: GET /shell-descriptors/{aasIdentifier}/submodel-descriptors/{submodelIdentifier}
        let endpoint = Endpoint.get("/shell-descriptors/\(encodedAasId)/submodel-descriptors/\(encodedSubmodelId)")

        do {
            let descriptor: SubmodelDescriptor = try await httpClient.request(endpoint)
            logger.debug("Fetched submodel descriptor: \(descriptor.idShort ?? "unknown")")
            return descriptor
        } catch let error as HTTPError {
            if case .notFound = error {
                throw AASError.submodelNotFound(identifier: submodelId)
            }
            throw AASError.from(error, context: submodelId)
        }
    }

    public func searchShells(idShort: String) async throws -> [AASDescriptor] {
        let query = ShellSearchQuery(idShort: idShort)
        let result = try await searchShells(query: query)
        return result.result
    }

    public func searchShells(query: ShellSearchQuery) async throws -> PagedResult<AASDescriptor> {
        logger.debug("Searching shells with query")

        // AAS Registry API: GET /shell-descriptors with query parameters
        let endpoint = Endpoint.get(
            "/shell-descriptors",
            queryItems: query.asQueryItems()
        )

        do {
            let response: PagedResult<AASDescriptor> = try await httpClient.request(endpoint)
            logger.debug("Search returned \(response.result.count) results")
            return response
        } catch let error as HTTPError {
            throw AASError.from(error)
        }
    }

    // MARK: - Write Operations

    public func registerShell(descriptor: AASDescriptor) async throws {
        logger.debug("Registering shell: \(descriptor.idShort ?? descriptor.id)")

        // AAS Registry API: POST /shell-descriptors
        let endpoint = try Endpoint.post("/shell-descriptors", body: descriptor)

        do {
            _ = try await httpClient.request(endpoint)
            logger.debug("Successfully registered shell")
        } catch let error as HTTPError {
            if case .httpError(let statusCode, _) = error, statusCode == 409 {
                throw AASError.conflict(identifier: descriptor.id)
            }
            throw AASError.from(error, context: descriptor.id)
        }
    }

    public func updateShellDescriptor(aasId: String, descriptor: AASDescriptor) async throws {
        logger.debug("Updating shell descriptor: \(aasId)")

        // Encode the AAS ID for URL path
        let encodedId = aasB64Url(aasId)

        // AAS Registry API: PUT /shell-descriptors/{aasIdentifier}
        let endpoint = try Endpoint.put("/shell-descriptors/\(encodedId)", body: descriptor)

        do {
            _ = try await httpClient.request(endpoint)
            logger.debug("Successfully updated shell descriptor")
        } catch let error as HTTPError {
            if case .notFound = error {
                throw AASError.shellNotFound(identifier: aasId)
            }
            throw AASError.from(error, context: aasId)
        }
    }

    public func deleteShellDescriptor(aasId: String) async throws {
        logger.debug("Deleting shell descriptor: \(aasId)")

        // Encode the AAS ID for URL path
        let encodedId = aasB64Url(aasId)

        // AAS Registry API: DELETE /shell-descriptors/{aasIdentifier}
        let endpoint = Endpoint.delete("/shell-descriptors/\(encodedId)")

        do {
            _ = try await httpClient.request(endpoint)
            logger.debug("Successfully deleted shell descriptor")
        } catch let error as HTTPError {
            if case .notFound = error {
                throw AASError.shellNotFound(identifier: aasId)
            }
            throw AASError.from(error, context: aasId)
        }
    }

    public func registerSubmodelDescriptor(aasId: String, descriptor: SubmodelDescriptor) async throws {
        logger.debug("Registering submodel descriptor for AAS: \(aasId)")

        // Encode the AAS ID for URL path
        let encodedId = aasB64Url(aasId)

        // AAS Registry API: POST /shell-descriptors/{aasIdentifier}/submodel-descriptors
        let endpoint = try Endpoint.post(
            "/shell-descriptors/\(encodedId)/submodel-descriptors",
            body: descriptor
        )

        do {
            _ = try await httpClient.request(endpoint)
            logger.debug("Successfully registered submodel descriptor")
        } catch let error as HTTPError {
            if case .notFound = error {
                throw AASError.shellNotFound(identifier: aasId)
            }
            if case .httpError(let statusCode, _) = error, statusCode == 409 {
                throw AASError.conflict(identifier: descriptor.id)
            }
            throw AASError.from(error, context: descriptor.id)
        }
    }

    public func deleteSubmodelDescriptor(aasId: String, submodelId: String) async throws {
        logger.debug("Deleting submodel descriptor: \(submodelId)")

        // Encode IDs for URL path
        let encodedAasId = aasB64Url(aasId)
        let encodedSubmodelId = aasB64Url(submodelId)

        // AAS Registry API: DELETE /shell-descriptors/{aasIdentifier}/submodel-descriptors/{submodelIdentifier}
        let endpoint = Endpoint.delete(
            "/shell-descriptors/\(encodedAasId)/submodel-descriptors/\(encodedSubmodelId)"
        )

        do {
            _ = try await httpClient.request(endpoint)
            logger.debug("Successfully deleted submodel descriptor")
        } catch let error as HTTPError {
            if case .notFound = error {
                throw AASError.submodelNotFound(identifier: submodelId)
            }
            throw AASError.from(error, context: submodelId)
        }
    }
}

// MARK: - Registry Service Extensions

extension RegistryService {
    /// Fetch all shell descriptors by iterating through pages.
    /// - Parameter limit: Maximum number of items per page
    /// - Returns: All AAS descriptors
    public func getAllShellDescriptorsUnpaged(pageLimit: Int = 100) async throws -> [AASDescriptor] {
        var allDescriptors: [AASDescriptor] = []
        var cursor: String? = nil

        repeat {
            let query = ShellSearchQuery(limit: pageLimit, cursor: cursor)
            let result = try await searchShells(query: query)
            allDescriptors.append(contentsOf: result.result)
            cursor = result.nextCursor
        } while cursor != nil

        return allDescriptors
    }

    /// Get all submodels of a specific semantic type for an AAS.
    /// - Parameters:
    ///   - aasId: The AAS identifier
    ///   - semanticId: The semantic ID to filter by
    /// - Returns: Array of matching submodel descriptors
    public func getSubmodelDescriptors(aasId: String, withSemanticId semanticId: String) async throws -> [SubmodelDescriptor] {
        let descriptors = try await getSubmodelDescriptors(aasId: aasId)
        return descriptors.filter { descriptor in
            guard let descSemanticId = descriptor.semanticId else { return false }
            return descSemanticId.keys.contains { $0.value == semanticId }
        }
    }

    /// Find endpoint URL for an AAS.
    /// - Parameters:
    ///   - aasId: The AAS identifier
    ///   - interface: The interface type to look for (default: "AAS-3.0")
    /// - Returns: The endpoint URL if found
    public func getEndpointURL(aasId: String, interface: String = "AAS-3.0") async throws -> URL? {
        let descriptor = try await getShellDescriptor(aasId: aasId)
        return descriptor.endpoints?
            .first { $0.interface == interface }
            .flatMap { URL(string: $0.protocolInformation.href) }
    }
}

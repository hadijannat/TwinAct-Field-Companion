//
//  AssetRepository.swift
//  TwinAct Field Companion
//
//  Repository abstraction for Asset Administration Shell descriptors.
//

import Foundation
import os.log

// MARK: - Asset Repository Protocol

/// Repository for fetching AAS descriptors and related metadata.
public protocol AssetRepositoryProtocol: Sendable {
    /// List all AAS descriptors (paginated).
    func listDescriptors(cursor: String?) async throws -> PagedResult<AASDescriptor>

    /// Search AAS descriptors using a query.
    func searchDescriptors(query: ShellSearchQuery) async throws -> PagedResult<AASDescriptor>

    /// Fetch a single AAS descriptor by AAS identifier.
    func getDescriptor(aasId: String) async throws -> AASDescriptor
}

// MARK: - Asset Repository

public final class AssetRepository: AssetRepositoryProtocol, @unchecked Sendable {

    private let registryService: RegistryServiceProtocol
    private let logger: Logger

    public init(registryService: RegistryServiceProtocol) {
        self.registryService = registryService
        self.logger = Logger(
            subsystem: AppConfiguration.AppInfo.bundleIdentifier,
            category: "AssetRepository"
        )
    }

    public convenience init(tokenProvider: TokenProvider? = nil) {
        self.init(registryService: RegistryService(tokenProvider: tokenProvider))
    }

    public func listDescriptors(cursor: String? = nil) async throws -> PagedResult<AASDescriptor> {
        logger.debug("Listing AAS descriptors")
        return try await registryService.getAllShellDescriptors(cursor: cursor)
    }

    public func searchDescriptors(query: ShellSearchQuery) async throws -> PagedResult<AASDescriptor> {
        logger.debug("Searching AAS descriptors")
        return try await registryService.searchShells(query: query)
    }

    public func getDescriptor(aasId: String) async throws -> AASDescriptor {
        logger.debug("Fetching AAS descriptor for \(aasId)")
        return try await registryService.getShellDescriptor(aasId: aasId)
    }
}

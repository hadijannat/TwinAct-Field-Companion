//
//  AssetService.swift
//  TwinAct Field Companion
//
//  Domain service for high-level asset discovery and browsing.
//

import Foundation
import os.log

// MARK: - Asset Page

/// Paginated list of asset summaries for browse/search experiences.
public struct AssetPage: Sendable {
    public let items: [AssetSummary]
    public let nextCursor: String?

    public init(items: [AssetSummary], nextCursor: String?) {
        self.items = items
        self.nextCursor = nextCursor
    }
}

// MARK: - Asset Service Protocol

public protocol AssetServiceProtocol: Sendable {
    /// Browse assets (paginated).
    func browseAssets(cursor: String?, filter: AssetFilter?) async throws -> AssetPage

    /// Search assets by text (idShort or name).
    func searchAssets(text: String, cursor: String?) async throws -> AssetPage

    /// Fetch a full asset descriptor and map to domain Asset.
    func getAsset(aasId: String) async throws -> Asset
}

// MARK: - Asset Service

public final class AssetService: AssetServiceProtocol, @unchecked Sendable {

    private let repository: AssetRepositoryProtocol
    private let logger: Logger

    public init(repository: AssetRepositoryProtocol) {
        self.repository = repository
        self.logger = Logger(
            subsystem: AppConfiguration.AppInfo.bundleIdentifier,
            category: "AssetService"
        )
    }

    public func browseAssets(cursor: String? = nil, filter: AssetFilter? = nil) async throws -> AssetPage {
        if AppConfiguration.isDemoMode {
            return AssetPage(items: [AssetSummary(from: DemoData.asset)], nextCursor: nil)
        }

        logger.debug("Browsing assets (cursor: \(cursor ?? "nil", privacy: .public))")
        let result = try await repository.listDescriptors(cursor: cursor)
        let mapped = mapDescriptors(result.result)
        let filtered = applyFilter(filter, to: mapped)
        return AssetPage(items: filtered, nextCursor: result.nextCursor)
    }

    public func searchAssets(text: String, cursor: String? = nil) async throws -> AssetPage {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return try await browseAssets(cursor: cursor, filter: nil)
        }

        logger.debug("Searching assets for '\(trimmed, privacy: .public)'")
        let query = ShellSearchQuery(idShort: trimmed, limit: 50, cursor: cursor)
        let result = try await repository.searchDescriptors(query: query)
        let mapped = mapDescriptors(result.result)
        return AssetPage(items: mapped, nextCursor: result.nextCursor)
    }

    public func getAsset(aasId: String) async throws -> Asset {
        let descriptor = try await repository.getDescriptor(aasId: aasId)
        return Asset(from: descriptor, nameplate: nil)
    }

    // MARK: - Mapping & Filtering

    private func mapDescriptors(_ descriptors: [AASDescriptor]) -> [AssetSummary] {
        descriptors.map { descriptor in
            let name = descriptor.idShort
                ?? descriptor.displayName?.englishText
                ?? descriptor.globalAssetId
                ?? descriptor.id

            return AssetSummary(
                id: descriptor.globalAssetId ?? descriptor.id,
                aasId: descriptor.id,
                globalAssetId: descriptor.globalAssetId,
                name: name,
                manufacturer: nil,
                model: nil,
                thumbnailURL: nil,
                submodelCount: descriptor.submodelDescriptors?.count ?? 0
            )
        }
    }

    private func applyFilter(_ filter: AssetFilter?, to items: [AssetSummary]) -> [AssetSummary] {
        guard let filter else { return items }

        return items.filter { summary in
            if let searchText = filter.searchText, !searchText.isEmpty {
                let lowercased = searchText.lowercased()
                let matches = summary.name.lowercased().contains(lowercased)
                    || summary.displayId.lowercased().contains(lowercased)
                if !matches { return false }
            }
            if let manufacturer = filter.manufacturer,
               summary.manufacturer?.lowercased() != manufacturer.lowercased() {
                return false
            }
            if let serialNumber = filter.serialNumber,
               summary.displayId.lowercased() != serialNumber.lowercased() {
                return false
            }
            return true
        }
    }
}

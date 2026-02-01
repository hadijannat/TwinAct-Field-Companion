//
//  DiscoveryViewModel.swift
//  TwinAct Field Companion
//
//  Coordinates QR scan to AAS discovery flow.
//  Handles lookup, registry queries, and submodel loading.
//

import Foundation
import Combine
import os.log

// MARK: - Discovery State

/// State of the asset discovery process.
public enum DiscoveryState: Equatable {
    case idle
    case scanning
    case lookingUp(progress: String)
    case loadingDescriptor
    case loadingSubmodels(progress: String)
    case found(Asset)
    case notFound(reason: String)
    case error(String)
    case offline(cachedAsset: Asset?)

    public static func == (lhs: DiscoveryState, rhs: DiscoveryState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle),
             (.scanning, .scanning),
             (.loadingDescriptor, .loadingDescriptor):
            return true
        case (.lookingUp(let a), .lookingUp(let b)),
             (.loadingSubmodels(let a), .loadingSubmodels(let b)),
             (.notFound(let a), .notFound(let b)),
             (.error(let a), .error(let b)):
            return a == b
        case (.found(let a), .found(let b)):
            return a.id == b.id
        case (.offline(let a), .offline(let b)):
            return a?.id == b?.id
        default:
            return false
        }
    }

    /// User-friendly description of current state.
    public var description: String {
        switch self {
        case .idle:
            return "Ready to scan"
        case .scanning:
            return "Scanning..."
        case .lookingUp(let progress):
            return progress
        case .loadingDescriptor:
            return "Loading asset information..."
        case .loadingSubmodels(let progress):
            return progress
        case .found:
            return "Asset found"
        case .notFound(let reason):
            return reason
        case .error(let message):
            return message
        case .offline(let cached):
            return cached != nil ? "Offline - showing cached data" : "Offline - no cached data available"
        }
    }

    /// Whether the state represents an active loading process.
    public var isLoading: Bool {
        switch self {
        case .lookingUp, .loadingDescriptor, .loadingSubmodels:
            return true
        default:
            return false
        }
    }
}

// MARK: - Discovery Result

/// Result of an asset discovery operation.
public struct DiscoveryResult: Sendable {
    public let asset: Asset
    public let nameplate: DigitalNameplate?
    public let availableSubmodels: [SubmodelType]
    public let discoveryTime: TimeInterval
    public let source: DiscoverySource

    public enum DiscoverySource: Sendable {
        case online
        case cached
        case demo
    }
}

// MARK: - Discovery ViewModel

/// ViewModel coordinating the QR scan to AAS discovery flow.
@MainActor
public final class DiscoveryViewModel: ObservableObject {

    // MARK: - Published Properties

    /// Current discovery state
    @Published public var state: DiscoveryState = .idle

    /// Discovered asset (if found)
    @Published public var discoveredAsset: Asset?

    /// Loaded digital nameplate (if available)
    @Published public var nameplate: DigitalNameplate?

    /// Recent discovery history
    @Published public var recentDiscoveries: [AssetSummary] = []

    /// Current error
    @Published public var error: Error?

    /// Network availability
    @Published public var isOnline: Bool = true

    // MARK: - Services

    private let discoveryService: DiscoveryServiceProtocol
    private let registryService: RegistryServiceProtocol
    private let submodelService: SubmodelServiceProtocol

    // MARK: - Private Properties

    private let logger = Logger(
        subsystem: AppConfiguration.AppInfo.bundleIdentifier,
        category: "DiscoveryViewModel"
    )

    private var cancellables = Set<AnyCancellable>()
    private var discoveryStartTime: Date?

    /// Cache for recently discovered assets
    private var assetCache: [String: Asset] = [:]

    // MARK: - Initialization

    /// Initialize with service dependencies.
    public init(
        discoveryService: DiscoveryServiceProtocol,
        registryService: RegistryServiceProtocol,
        submodelService: SubmodelServiceProtocol
    ) {
        self.discoveryService = discoveryService
        self.registryService = registryService
        self.submodelService = submodelService

        setupNetworkMonitoring()
    }

    /// Initialize with default services.
    public convenience init(tokenProvider: TokenProvider? = nil) {
        if AppConfiguration.isDemoMode {
            self.init(
                discoveryService: MockDiscoveryService(),
                registryService: MockRegistryService(),
                submodelService: MockSubmodelService()
            )
            return
        }
        if let tokenProvider = tokenProvider {
            self.init(
                discoveryService: DiscoveryService(tokenProvider: tokenProvider),
                registryService: RegistryService(tokenProvider: tokenProvider),
                submodelService: SubmodelService(tokenProvider: tokenProvider)
            )
        } else {
            let container = DependencyContainer.shared
            self.init(
                discoveryService: container.discoveryService,
                registryService: container.registryService,
                submodelService: container.submodelService
            )
        }
    }

    // MARK: - Public API

    /// Process a scanned identification link.
    /// - Parameter link: The parsed identification link from QR scanner
    public func processIdentificationLink(_ link: AssetIdentificationLink) async {
        logger.info("Processing identification link: \(link.linkType.rawValue)")
        discoveryStartTime = Date()

        // Reset state
        error = nil
        discoveredAsset = nil
        nameplate = nil

        // Check for direct AAS link
        if let aasId = link.aasId {
            await discoverByAASId(aasId, link: link)
            return
        }

        // Check for asset IDs to lookup
        let assetIds = link.lookupQuery
        guard !assetIds.isEmpty else {
            state = .notFound(reason: "No identifiers found in QR code")
            return
        }

        await discoverByAssetIds(assetIds, link: link)
    }

    /// Process a raw scanned code (attempts parsing first).
    /// - Parameter code: Raw QR code content
    public func processScannedCode(_ code: String) async {
        if let link = IdentificationLinkParser.parse(code) {
            await processIdentificationLink(link)
        } else {
            // Try as serial number lookup
            let link = AssetIdentificationLink(
                originalURL: nil,
                originalString: code,
                linkType: .unknown,
                serialNumber: code,
                specificAssetIds: [SpecificAssetId(name: "serialNumber", value: code)],
                confidence: 0.5
            )
            await processIdentificationLink(link)
        }
    }

    /// Lookup asset by serial number.
    /// - Parameter serialNumber: The serial number to search for
    public func lookupBySerialNumber(_ serialNumber: String) async {
        let assetId = SpecificAssetId(name: "serialNumber", value: serialNumber)
        let link = AssetIdentificationLink(
            originalURL: nil,
            originalString: serialNumber,
            linkType: .unknown,
            serialNumber: serialNumber,
            specificAssetIds: [assetId],
            confidence: 0.7
        )
        await processIdentificationLink(link)
    }

    /// Lookup asset by global asset ID.
    /// - Parameter globalAssetId: The global asset ID
    public func lookupByGlobalAssetId(_ globalAssetId: String) async {
        let assetId = SpecificAssetId(name: "globalAssetId", value: globalAssetId)
        await discoverByAssetIds([assetId], link: nil)
    }

    /// Clear current discovery and reset to idle.
    public func reset() {
        state = .idle
        discoveredAsset = nil
        nameplate = nil
        error = nil
    }

    /// Retry the last failed discovery.
    public func retry() async {
        // Implementation depends on storing last query
        // For now, just reset
        reset()
    }

    // MARK: - Discovery by AAS ID

    private func discoverByAASId(_ aasId: String, link: AssetIdentificationLink?) async {
        state = .loadingDescriptor

        do {
            // Get AAS descriptor
            let descriptor = try await registryService.getShellDescriptor(aasId: aasId)
            logger.debug("Found AAS descriptor: \(descriptor.idShort ?? descriptor.id)")

            // Load nameplate and build asset
            await loadAssetDetails(from: descriptor, link: link)

        } catch {
            handleDiscoveryError(error, context: "loading AAS descriptor")
        }
    }

    // MARK: - Discovery by Asset IDs

    private func discoverByAssetIds(_ assetIds: [SpecificAssetId], link: AssetIdentificationLink?) async {
        state = .lookingUp(progress: "Looking up asset in registry...")

        do {
            // Step 1: Lookup AAS IDs from asset IDs
            let aasIds = try await discoveryService.lookupShells(assetIds: assetIds)

            guard let primaryAasId = aasIds.first else {
                state = .notFound(reason: "No asset found with the scanned identifiers")
                logger.info("No AAS found for asset IDs: \(assetIds.map { "\($0.name)=\($0.value)" })")
                return
            }

            if aasIds.count > 1 {
                logger.warning("Multiple AAS found (\(aasIds.count)), using first: \(primaryAasId)")
            }

            logger.debug("Found AAS ID: \(primaryAasId)")

            // Step 2: Get AAS descriptor
            state = .loadingDescriptor
            let descriptor = try await registryService.getShellDescriptor(aasId: primaryAasId)
            logger.debug("Loaded AAS descriptor: \(descriptor.idShort ?? "unnamed")")

            // Step 3: Load details and build asset
            await loadAssetDetails(from: descriptor, link: link)

        } catch {
            handleDiscoveryError(error, context: "asset lookup")
        }
    }

    // MARK: - Load Asset Details

    private func loadAssetDetails(from descriptor: AASDescriptor, link: AssetIdentificationLink?) async {
        state = .loadingSubmodels(progress: "Loading asset details...")

        do {
            // Try to load Digital Nameplate first (for display info)
            var loadedNameplate: DigitalNameplate?

            if let nameplateSubmodel = try await submodelService.getSubmodelBySemanticId(
                aasId: descriptor.id,
                semanticId: IDTASemanticId.digitalNameplate
            ) {
                loadedNameplate = parseDigitalNameplate(from: nameplateSubmodel)
                nameplate = loadedNameplate
                logger.debug("Loaded Digital Nameplate for \(descriptor.idShort ?? descriptor.id)")
            }

            // Build the Asset model
            let asset = buildAsset(
                from: descriptor,
                nameplate: loadedNameplate,
                link: link
            )

            // Update state
            discoveredAsset = asset
            state = .found(asset)

            // Log discovery time
            if let startTime = discoveryStartTime {
                let duration = Date().timeIntervalSince(startTime)
                logger.info("Discovery completed in \(String(format: "%.2f", duration))s")
            }

            // Add to recent discoveries
            addToRecentDiscoveries(asset)

            // Cache the asset
            assetCache[asset.id] = asset

        } catch {
            // Even if submodel loading fails, we can still show basic asset info
            let basicAsset = Asset(from: descriptor, nameplate: nil)
            discoveredAsset = basicAsset
            state = .found(basicAsset)

            logger.warning("Partial discovery - submodel loading failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Asset Building

    private func buildAsset(
        from descriptor: AASDescriptor,
        nameplate: DigitalNameplate?,
        link: AssetIdentificationLink?
    ) -> Asset {
        // Combine information from descriptor, nameplate, and scanned link
        let id = descriptor.globalAssetId ?? descriptor.id
        let name = descriptor.idShort ?? descriptor.displayName?.englishText ?? "Unknown Asset"

        // Determine manufacturer
        let manufacturer = nameplate?.manufacturerName ?? link?.manufacturer

        // Determine serial number
        let serialNumber = nameplate?.serialNumber ?? link?.serialNumber

        // Determine model/product designation
        let model = nameplate?.manufacturerProductDesignation ?? link?.productFamily

        // Get thumbnail URL
        let thumbnailURL = nameplate?.productImage

        // Determine available submodels
        var availableSubmodels: Set<SubmodelType> = []
        for submodelDescriptor in descriptor.submodelDescriptors ?? [] {
            if let type = SubmodelType.from(semanticId: submodelDescriptor.semanticId) {
                availableSubmodels.insert(type)
            }
        }

        return Asset(
            id: id,
            aasId: descriptor.id,
            globalAssetId: descriptor.globalAssetId,
            name: name,
            assetType: descriptor.assetKind?.rawValue,
            manufacturer: manufacturer,
            serialNumber: serialNumber,
            model: model,
            thumbnailURL: thumbnailURL,
            aasDescriptor: descriptor,
            availableSubmodels: availableSubmodels
        )
    }

    // MARK: - Nameplate Parsing

    private func parseDigitalNameplate(from submodel: Submodel) -> DigitalNameplate? {
        // Use the SubmodelElementParser or manual extraction
        // This is a simplified version - full implementation would use SubmodelElementParser

        var manufacturerName: String?
        var productDesignation: String?
        var productFamily: String?
        var serialNumber: String?
        var orderCode: String?

        for element in submodel.submodelElements ?? [] {
            switch element {
            case .property(let prop):
                switch prop.idShort {
                case "ManufacturerName":
                    manufacturerName = prop.value
                case "ManufacturerProductDesignation":
                    productDesignation = prop.value
                case "ManufacturerProductFamily":
                    productFamily = prop.value
                case "SerialNumber":
                    serialNumber = prop.value
                case "ManufacturerOrderCode", "OrderCode":
                    orderCode = prop.value
                default:
                    break
                }

            case .multiLanguageProperty(let mlp):
                switch mlp.idShort {
                case "ManufacturerName":
                    manufacturerName = mlp.value?.englishText
                case "ManufacturerProductDesignation":
                    productDesignation = mlp.value?.englishText
                case "ManufacturerProductFamily":
                    productFamily = mlp.value?.englishText
                default:
                    break
                }

            case .submodelElementCollection:
                // Recurse into collections (e.g., "ContactInformation")
                // Simplified - full implementation would handle nested structures
                break

            default:
                break
            }
        }

        return DigitalNameplate(
            manufacturerName: manufacturerName,
            manufacturerProductDesignation: productDesignation,
            manufacturerProductFamily: productFamily,
            orderCode: orderCode,
            serialNumber: serialNumber
        )
    }

    // MARK: - Error Handling

    private func handleDiscoveryError(_ error: Error, context: String) {
        self.error = error
        logger.error("Discovery error during \(context): \(error.localizedDescription)")

        if let aasError = error as? AASError {
            switch aasError {
            case .shellNotFound:
                state = .notFound(reason: "Asset not found in the system")
            case .networkError:
                state = .offline(cachedAsset: nil)
            case .unauthorized, .forbidden:
                state = .error("Access denied. Please check your credentials.")
            default:
                state = .error(aasError.localizedDescription)
            }
        } else {
            state = .error("Discovery failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Recent Discoveries

    private func addToRecentDiscoveries(_ asset: Asset) {
        let summary = AssetSummary(from: asset)

        // Remove if already exists
        recentDiscoveries.removeAll { $0.id == summary.id }

        // Add to front
        recentDiscoveries.insert(summary, at: 0)

        // Keep max 10
        if recentDiscoveries.count > 10 {
            recentDiscoveries = Array(recentDiscoveries.prefix(10))
        }
    }

    // MARK: - Network Monitoring

    private func setupNetworkMonitoring() {
        // Monitor network availability
        // This would integrate with NetworkMonitor from Core/Networking
        // For now, assume online
        isOnline = true
    }

    // MARK: - Cache Access

    /// Get cached asset by ID.
    public func getCachedAsset(id: String) -> Asset? {
        assetCache[id]
    }

    /// Clear asset cache.
    public func clearCache() {
        assetCache.removeAll()
    }
}

// MARK: - Discovery View Model Extensions

extension DiscoveryViewModel {

    /// Load all submodels for the discovered asset.
    public func loadAllSubmodels() async -> [Submodel] {
        guard let asset = discoveredAsset,
              let aasId = asset.aasDescriptor?.id else {
            return []
        }

        do {
            return try await submodelService.getSubmodelsForShell(aasId: aasId)
        } catch {
            logger.error("Failed to load submodels: \(error.localizedDescription)")
            return []
        }
    }

    /// Load a specific submodel type for the discovered asset.
    public func loadSubmodel(_ type: SubmodelType) async -> Submodel? {
        guard let asset = discoveredAsset,
              let aasId = asset.aasDescriptor?.id else {
            return nil
        }

        do {
            return try await submodelService.getSubmodelBySemanticId(
                aasId: aasId,
                semanticId: type.semanticId
            )
        } catch {
            logger.error("Failed to load \(type.displayName) submodel: \(error.localizedDescription)")
            return nil
        }
    }
}

// MARK: - Preview Helpers

#if DEBUG
extension DiscoveryViewModel {
    /// Create a preview instance with mock data.
    static var preview: DiscoveryViewModel {
        let viewModel = DiscoveryViewModel(
            discoveryService: MockDiscoveryService(),
            registryService: MockRegistryService(),
            submodelService: MockSubmodelService()
        )
        return viewModel
    }

    /// Create a preview instance with discovered asset.
    static func preview(withAsset asset: Asset) -> DiscoveryViewModel {
        let viewModel = DiscoveryViewModel(
            discoveryService: MockDiscoveryService(),
            registryService: MockRegistryService(),
            submodelService: MockSubmodelService()
        )
        viewModel.discoveredAsset = asset
        viewModel.state = .found(asset)
        return viewModel
    }
}

// Mock services for previews
private struct DiscoveryPreviewSubmodelService: SubmodelServiceProtocol {
    func getSubmodel(submodelId: String) async throws -> Submodel {
        Submodel(id: submodelId, idShort: "Mock Submodel")
    }
    func getElementValue<T: Decodable>(submodelId: String, path: String) async throws -> T {
        throw AASError.submodelNotFound(identifier: submodelId)
    }
    func setElementValue<T: Encodable>(submodelId: String, path: String, value: T) async throws {}
    func getPropertyValue(submodelId: String, path: String) async throws -> String? { nil }
    func setPropertyValue(submodelId: String, path: String, value: String) async throws {}
    func getSubmodelBySemanticId(aasId: String, semanticId: String) async throws -> Submodel? { nil }
    func getSubmodelsForShell(aasId: String) async throws -> [Submodel] { [] }
}
#endif

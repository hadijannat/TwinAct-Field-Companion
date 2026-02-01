//
//  DemoDataProvider.swift
//  TwinAct Field Companion
//
//  Provides bundled demo data for App Store review and offline showcase.
//  Loads demo assets from bundled JSON files for demo mode operation.
//

import Foundation
import os.log

// MARK: - Demo Data Provider

/// Provides bundled demo data for App Store review and offline showcase.
/// This enables the app to function without a real backend connection.
public final class DemoDataProvider: @unchecked Sendable {

    // MARK: - Shared Instance

    public static let shared = DemoDataProvider()

    // MARK: - Properties

    private let logger = Logger(
        subsystem: AppConfiguration.AppInfo.bundleIdentifier,
        category: "DemoDataProvider"
    )

    /// JSON decoder configured for AAS date formats
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    // MARK: - Cached Data

    private var cachedAASDescriptor: AASDescriptor?
    private var cachedNameplate: DigitalNameplate?
    private var cachedCarbonFootprint: CarbonFootprint?
    private var cachedServiceRequests: [ServiceRequest]?
    private var cachedDocumentation: HandoverDocumentation?
    private var cachedTimeSeriesData: TimeSeriesData?
    private var cachedMaintenanceInstructions: MaintenanceInstructions?

    // MARK: - Initialization

    private init() {
        logger.debug("DemoDataProvider initialized")
    }

    // MARK: - Asset Data

    /// Get the complete demo asset with all available data.
    public func getDemoAsset() throws -> Asset {
        let descriptor = try loadAASDescriptor()

        return Asset(
            id: descriptor.globalAssetId ?? descriptor.id,
            aasId: descriptor.id,
            globalAssetId: descriptor.globalAssetId,
            name: descriptor.idShort ?? "Demo Asset",
            assetType: descriptor.assetKind?.rawValue,
            manufacturer: try? loadDigitalNameplate().manufacturerName,
            serialNumber: try? loadDigitalNameplate().serialNumber,
            model: try? loadDigitalNameplate().manufacturerProductDesignation,
            thumbnailURL: try? loadDigitalNameplate().productImage,
            aasDescriptor: descriptor,
            availableSubmodels: [
                .digitalNameplate,
                .handoverDocumentation,
                .maintenanceInstructions,
                .serviceRequest,
                .timeSeriesData,
                .carbonFootprint,
                .technicalData
            ]
        )
    }

    // MARK: - AAS Descriptor

    /// Load the demo AAS descriptor from bundled JSON.
    public func loadAASDescriptor() throws -> AASDescriptor {
        if let cached = cachedAASDescriptor {
            return cached
        }

        logger.debug("Loading demo AAS descriptor from bundle")
        let data = try loadBundledJSON("demo-aas")

        do {
            let descriptor = try decoder.decode(AASDescriptor.self, from: data)
            cachedAASDescriptor = descriptor
            logger.debug("Loaded AAS descriptor: \(descriptor.idShort ?? descriptor.id)")
            return descriptor
        } catch {
            logger.error("Failed to decode AAS descriptor: \(error.localizedDescription)")
            throw DemoDataError.decodingFailed("demo-aas", error)
        }
    }

    // MARK: - Digital Nameplate

    /// Load the demo digital nameplate from bundled JSON.
    public func loadDigitalNameplate() throws -> DigitalNameplate {
        if let cached = cachedNameplate {
            return cached
        }

        logger.debug("Loading demo digital nameplate from bundle")
        let data = try loadBundledJSON("demo-nameplate")

        do {
            let nameplate = try decoder.decode(DigitalNameplate.self, from: data)
            cachedNameplate = nameplate
            logger.debug("Loaded nameplate for: \(nameplate.manufacturerProductDesignation ?? "unknown")")
            return nameplate
        } catch {
            logger.error("Failed to decode nameplate: \(error.localizedDescription)")
            throw DemoDataError.decodingFailed("demo-nameplate", error)
        }
    }

    // MARK: - Carbon Footprint

    /// Load the demo carbon footprint data from bundled JSON.
    public func loadCarbonFootprint() throws -> CarbonFootprint {
        if let cached = cachedCarbonFootprint {
            return cached
        }

        logger.debug("Loading demo carbon footprint from bundle")
        let data = try loadBundledJSON("demo-carbon-footprint")

        do {
            let footprint = try decoder.decode(CarbonFootprint.self, from: data)
            cachedCarbonFootprint = footprint
            logger.debug("Loaded carbon footprint: \(footprint.formattedTotalCO2 ?? "unknown") total")
            return footprint
        } catch {
            logger.error("Failed to decode carbon footprint: \(error.localizedDescription)")
            throw DemoDataError.decodingFailed("demo-carbon-footprint", error)
        }
    }

    // MARK: - Service Requests

    /// Load demo service requests from bundled JSON.
    public func loadServiceRequests() throws -> [ServiceRequest] {
        if let cached = cachedServiceRequests {
            return cached
        }

        logger.debug("Loading demo service requests from bundle")
        let data = try loadBundledJSON("demo-service-requests")

        do {
            let requests = try decoder.decode([ServiceRequest].self, from: data)
            cachedServiceRequests = requests
            logger.debug("Loaded \(requests.count) demo service requests")
            return requests
        } catch {
            logger.error("Failed to decode service requests: \(error.localizedDescription)")
            throw DemoDataError.decodingFailed("demo-service-requests", error)
        }
    }

    /// Get service requests filtered by status.
    public func loadServiceRequests(status: ServiceRequestStatus) throws -> [ServiceRequest] {
        let all = try loadServiceRequests()
        return all.filter { $0.status == status }
    }

    /// Get open service requests.
    public func loadOpenServiceRequests() throws -> [ServiceRequest] {
        let all = try loadServiceRequests()
        return all.filter { $0.isOpen }
    }

    // MARK: - Documentation

    /// Load demo handover documentation from bundled JSON.
    public func loadDocumentation() throws -> HandoverDocumentation {
        if let cached = cachedDocumentation {
            return cached
        }

        logger.debug("Loading demo documentation from bundle")
        let data = try loadBundledJSON("demo-documentation")

        do {
            let docs = try decoder.decode(HandoverDocumentation.self, from: data)
            cachedDocumentation = docs
            logger.debug("Loaded \(docs.documents.count) demo documents")
            return docs
        } catch {
            logger.error("Failed to decode documentation: \(error.localizedDescription)")
            throw DemoDataError.decodingFailed("demo-documentation", error)
        }
    }

    /// Get documents of a specific class.
    public func loadDocuments(ofClass documentClass: DocumentClass) throws -> [Document] {
        let docs = try loadDocumentation()
        return docs.documents.filter { $0.documentClass == documentClass }
    }

    // MARK: - Time Series Data

    /// Load demo time series data from bundled JSON.
    public func loadTimeSeriesData() throws -> TimeSeriesData {
        if let cached = cachedTimeSeriesData {
            return cached
        }

        logger.debug("Loading demo time series data from bundle")
        let data = try loadBundledJSON("demo-timeseries")

        do {
            let timeSeries = try decoder.decode(TimeSeriesData.self, from: data)
            cachedTimeSeriesData = timeSeries
            logger.debug("Loaded \(timeSeries.records.count) time series records")
            return timeSeries
        } catch {
            logger.error("Failed to decode time series data: \(error.localizedDescription)")
            throw DemoDataError.decodingFailed("demo-timeseries", error)
        }
    }

    // MARK: - Maintenance Instructions

    /// Load demo maintenance instructions from bundled JSON.
    public func loadMaintenanceInstructions() throws -> MaintenanceInstructions {
        if let cached = cachedMaintenanceInstructions {
            return cached
        }

        logger.debug("Loading demo maintenance instructions from bundle")
        let data = try loadBundledJSON("demo-maintenance")

        do {
            let maintenance = try decoder.decode(MaintenanceInstructions.self, from: data)
            cachedMaintenanceInstructions = maintenance
            logger.debug("Loaded \(maintenance.instructions.count) maintenance instructions")
            return maintenance
        } catch {
            logger.error("Failed to decode maintenance instructions: \(error.localizedDescription)")
            throw DemoDataError.decodingFailed("demo-maintenance", error)
        }
    }

    // MARK: - Demo Asset Identifiers

    /// The demo asset's AAS ID.
    public var demoAASId: String {
        (try? loadAASDescriptor().id) ?? "urn:demo:aas:smartpump001"
    }

    /// The demo asset's global asset ID.
    public var demoGlobalAssetId: String {
        (try? loadAASDescriptor().globalAssetId) ?? "urn:demo:asset:pump:serial:SP500-2025-0042"
    }

    /// The demo asset's serial number.
    public var demoSerialNumber: String {
        (try? loadDigitalNameplate().serialNumber) ?? "SP500-2025-0042"
    }

    // MARK: - Cache Management

    /// Clear all cached data.
    public func clearCache() {
        logger.debug("Clearing DemoDataProvider cache")
        cachedAASDescriptor = nil
        cachedNameplate = nil
        cachedCarbonFootprint = nil
        cachedServiceRequests = nil
        cachedDocumentation = nil
        cachedTimeSeriesData = nil
        cachedMaintenanceInstructions = nil
    }

    /// Preload all demo data into cache.
    public func preloadAllData() {
        logger.debug("Preloading all demo data")
        _ = try? loadAASDescriptor()
        _ = try? loadDigitalNameplate()
        _ = try? loadCarbonFootprint()
        _ = try? loadServiceRequests()
        _ = try? loadDocumentation()
        _ = try? loadTimeSeriesData()
        _ = try? loadMaintenanceInstructions()
        logger.debug("Demo data preload complete")
    }

    // MARK: - Helpers

    /// Load JSON data from the app bundle.
    private func loadBundledJSON(_ filename: String) throws -> Data {
        // Try main bundle first
        if let url = Bundle.main.url(forResource: filename, withExtension: "json") {
            return try Data(contentsOf: url)
        }

        // Try module bundle (for SwiftUI previews)
        #if DEBUG
        let bundlePaths = [
            Bundle.main.bundlePath,
            Bundle.main.bundlePath + "/Resources",
            Bundle.main.resourcePath ?? ""
        ]

        for path in bundlePaths {
            let filePath = (path as NSString).appendingPathComponent("\(filename).json")
            if FileManager.default.fileExists(atPath: filePath) {
                let url = URL(fileURLWithPath: filePath)
                return try Data(contentsOf: url)
            }
        }
        #endif

        logger.error("Demo resource not found: \(filename).json")
        throw DemoDataError.resourceNotFound(filename)
    }
}

// MARK: - Demo Data Error

/// Errors that can occur when loading demo data.
public enum DemoDataError: Error, LocalizedError {
    /// The requested resource file was not found in the bundle.
    case resourceNotFound(String)

    /// Failed to decode the JSON data.
    case decodingFailed(String, Error)

    /// The demo data is invalid or corrupted.
    case invalidData(String)

    public var errorDescription: String? {
        switch self {
        case .resourceNotFound(let filename):
            return "Demo resource '\(filename).json' not found in app bundle."
        case .decodingFailed(let filename, let error):
            return "Failed to decode demo data from '\(filename).json': \(error.localizedDescription)"
        case .invalidData(let message):
            return "Invalid demo data: \(message)"
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .resourceNotFound:
            return "Ensure the demo data files are included in the app bundle."
        case .decodingFailed:
            return "Check that the JSON file format matches the expected model structure."
        case .invalidData:
            return "Verify the demo data content is valid."
        }
    }
}

// MARK: - Preview Support

#if DEBUG
extension DemoDataProvider {
    /// Get a sample asset for SwiftUI previews.
    static var previewAsset: Asset {
        (try? shared.getDemoAsset()) ?? Asset(
            id: "preview-asset",
            name: "Preview Asset",
            assetType: "Instance",
            manufacturer: "Preview Manufacturer",
            serialNumber: "PREVIEW-001",
            model: "Preview Model"
        )
    }

    /// Get sample service requests for SwiftUI previews.
    static var previewServiceRequests: [ServiceRequest] {
        (try? shared.loadServiceRequests()) ?? []
    }

    /// Get a sample nameplate for SwiftUI previews.
    static var previewNameplate: DigitalNameplate? {
        try? shared.loadDigitalNameplate()
    }

    /// Get sample carbon footprint for SwiftUI previews.
    static var previewCarbonFootprint: CarbonFootprint? {
        try? shared.loadCarbonFootprint()
    }
}
#endif

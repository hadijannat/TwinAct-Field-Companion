//
//  PassportViewModel.swift
//  TwinAct Field Companion
//
//  View model for Digital Product Passport data loading and management.
//  Implements cache-first pattern for offline support.
//

import Foundation
import SwiftUI
import os.log
import Combine

// MARK: - Passport View Model

/// View model for the Digital Product Passport view.
/// Handles loading and caching of passport-related submodels.
@MainActor
public final class PassportViewModel: ObservableObject {

    // MARK: - Published Properties

    /// Loading state
    @Published public var isLoading: Bool = false

    /// The loaded asset
    @Published public var asset: Asset?

    /// Digital Nameplate data
    @Published public var digitalNameplate: DigitalNameplate?

    /// Carbon Footprint (DPP sustainability) data
    @Published public var carbonFootprint: CarbonFootprint?

    /// Handover documentation
    @Published public var documents: [Document] = []

    /// Technical data summary
    @Published public var technicalData: TechnicalDataSummary?

    /// Error state
    @Published public var error: PassportError?

    /// Whether data was loaded from cache
    @Published public var isFromCache: Bool = false

    /// Last refresh timestamp
    @Published public var lastRefreshed: Date?

    // MARK: - Private Properties

    private let assetId: String
    private let submodelService: SubmodelServiceProtocol
    private let persistenceService: PersistenceRepositoryProtocol
    private let logger: Logger

    // MARK: - Initialization

    /// Initialize with asset ID and services.
    /// - Parameters:
    ///   - assetId: The asset/AAS identifier
    ///   - submodelService: Service for loading submodel data
    ///   - persistenceService: Service for caching data
    public init(
        assetId: String,
        submodelService: SubmodelServiceProtocol,
        persistenceService: PersistenceRepositoryProtocol
    ) {
        self.assetId = assetId
        self.submodelService = submodelService
        self.persistenceService = persistenceService
        self.logger = Logger(
            subsystem: AppConfiguration.AppInfo.bundleIdentifier,
            category: "PassportViewModel"
        )
    }

    /// Convenience initializer with default services.
    /// - Parameter assetId: The asset/AAS identifier
    public convenience init(assetId: String) {
        self.init(
            assetId: assetId,
            submodelService: SubmodelService(),
            persistenceService: PersistenceService()
        )
    }

    // MARK: - Public Methods

    /// Load all passport data for the asset.
    public func loadAsset() async {
        guard !isLoading else { return }

        isLoading = true
        error = nil

        defer { isLoading = false }

        logger.debug("Loading passport data for asset: \(self.assetId)")

        if AppConfiguration.isDemoMode, assetId == DemoData.asset.aasId {
            applyPassportData(
                PassportData(
                    asset: DemoData.asset,
                    nameplate: DemoData.nameplate,
                    carbonFootprint: DemoData.carbonFootprint,
                    documents: DemoData.documents,
                    technicalData: DemoData.technicalSummary
                )
            )
            isFromCache = false
            lastRefreshed = Date()
            return
        }

        do {
            // Try to load from cache first for immediate display
            if let cached = await loadFromCache() {
                logger.debug("Loaded passport data from cache")
                applyPassportData(cached)
                isFromCache = true
            }

            // Then refresh from server
            let fresh = try await loadFromServer()
            applyPassportData(fresh)
            isFromCache = false
            lastRefreshed = Date()

            // Update cache
            await updateCache(with: fresh)

            logger.debug("Successfully loaded passport data from server")

        } catch {
            self.error = PassportError.from(error)
            logger.error("Failed to load passport data: \(error.localizedDescription)")

            // If we have cached data, continue showing it
            if asset != nil {
                logger.debug("Continuing to show cached data after server error")
            }
        }
    }

    /// Refresh passport data from the server.
    public func refresh() async {
        await loadAsset()
    }

    // MARK: - Private Methods - Cache Loading

    /// Load passport data from cache.
    private func loadFromCache() async -> PassportData? {
        // Load cached submodels for this AAS
        let cachedSubmodels = await persistenceService.getCachedSubmodels(forAAS: assetId)

        guard !cachedSubmodels.isEmpty else { return nil }

        var data = PassportData()

        for cached in cachedSubmodels where cached.isValid {
            do {
                if let semanticId = cached.semanticId {
                    if semanticId.contains("nameplate") || semanticId.contains("Nameplate") {
                        data.nameplate = try cached.decode(as: DigitalNameplate.self)
                    } else if semanticId.contains("CarbonFootprint") || semanticId.contains("sustainability") {
                        data.carbonFootprint = try cached.decode(as: CarbonFootprint.self)
                    } else if semanticId.contains("Documentation") || semanticId.contains("HandoverDocumentation") {
                        let handover = try cached.decode(as: HandoverDocumentation.self)
                        data.documents = handover.documents
                    } else if semanticId.contains("TechnicalData") {
                        data.technicalData = try cached.decode(as: TechnicalDataSummary.self)
                    }
                }
            } catch {
                logger.warning("Failed to decode cached submodel \(cached.id): \(error.localizedDescription)")
            }
        }

        // Create asset from nameplate if available
        if let nameplate = data.nameplate {
            data.asset = Asset(
                id: assetId,
                name: nameplate.manufacturerProductDesignation ?? nameplate.manufacturerName ?? "Unknown Asset",
                manufacturer: nameplate.manufacturerName,
                serialNumber: nameplate.serialNumber,
                model: nameplate.manufacturerProductType,
                thumbnailURL: nameplate.productImage
            )
        }

        return data.hasAnyData ? data : nil
    }

    // MARK: - Private Methods - Server Loading

    /// Load passport data from the server.
    private func loadFromServer() async throws -> PassportData {
        var data = PassportData()

        // Load submodels in parallel
        await withTaskGroup(of: Void.self) { group in
            // Load Digital Nameplate
            group.addTask { @MainActor in
                do {
                    if let submodel = try await self.submodelService.getSubmodelBySemanticId(
                        aasId: self.assetId,
                        semanticId: IDTASemanticId.digitalNameplate
                    ) {
                        data.nameplate = self.parseNameplate(from: submodel)
                    }
                } catch {
                    self.logger.warning("Failed to load Digital Nameplate: \(error.localizedDescription)")
                }
            }

            // Load Carbon Footprint
            group.addTask { @MainActor in
                do {
                    if let submodel = try await self.submodelService.getSubmodelBySemanticId(
                        aasId: self.assetId,
                        semanticId: IDTASemanticId.carbonFootprint
                    ) {
                        data.carbonFootprint = self.parseCarbonFootprint(from: submodel)
                    }
                } catch {
                    self.logger.warning("Failed to load Carbon Footprint: \(error.localizedDescription)")
                }
            }

            // Load Documentation
            group.addTask { @MainActor in
                do {
                    if let submodel = try await self.submodelService.getSubmodelBySemanticId(
                        aasId: self.assetId,
                        semanticId: IDTASemanticId.documentation
                    ) {
                        data.documents = self.parseDocumentation(from: submodel)
                    }
                } catch {
                    self.logger.warning("Failed to load Documentation: \(error.localizedDescription)")
                }
            }

            // Load Technical Data
            group.addTask { @MainActor in
                do {
                    if let submodel = try await self.submodelService.getSubmodelBySemanticId(
                        aasId: self.assetId,
                        semanticId: IDTASemanticId.technicalData
                    ) {
                        data.technicalData = self.parseTechnicalData(from: submodel)
                    }
                } catch {
                    self.logger.warning("Failed to load Technical Data: \(error.localizedDescription)")
                }
            }
        }

        // Create asset from nameplate
        if let nameplate = data.nameplate {
            data.asset = Asset(
                id: assetId,
                name: nameplate.manufacturerProductDesignation ?? nameplate.manufacturerName ?? "Unknown Asset",
                manufacturer: nameplate.manufacturerName,
                serialNumber: nameplate.serialNumber,
                model: nameplate.manufacturerProductType,
                thumbnailURL: nameplate.productImage
            )
        } else {
            // Create minimal asset
            data.asset = Asset(id: assetId, name: "Asset \(assetId.suffix(8))")
        }

        return data
    }

    // MARK: - Private Methods - Parsing

    /// Parse Digital Nameplate from submodel.
    private func parseNameplate(from submodel: Submodel) -> DigitalNameplate {
        let elements = submodel.flattenedElements()
        var propertyValues: [String: String] = [:]

        for (path, element) in elements {
            if case .property(let property) = element {
                propertyValues[path] = property.value
            } else if case .multiLanguageProperty(let mlp) = element {
                propertyValues[path] = mlp.value?.englishText
            }
        }

        return DigitalNameplate(
            manufacturerName: propertyValues["ManufacturerName"],
            manufacturerProductDesignation: propertyValues["ManufacturerProductDesignation"],
            manufacturerProductFamily: propertyValues["ManufacturerProductFamily"],
            manufacturerProductType: propertyValues["ManufacturerProductType"],
            orderCode: propertyValues["OrderCode"],
            serialNumber: propertyValues["SerialNumber"],
            batchNumber: propertyValues["BatchNumber"],
            productionDate: parseDate(propertyValues["DateOfManufacture"]),
            countryOfOrigin: propertyValues["CountryOfOrigin"],
            yearOfConstruction: Int(propertyValues["YearOfConstruction"] ?? ""),
            hardwareVersion: propertyValues["HardwareVersion"],
            firmwareVersion: propertyValues["FirmwareVersion"],
            softwareVersion: propertyValues["SoftwareVersion"],
            manufacturerLogo: URL(string: propertyValues["CompanyLogo"] ?? ""),
            productImage: URL(string: propertyValues["ProductImage"] ?? "")
        )
    }

    /// Parse Carbon Footprint from submodel.
    private func parseCarbonFootprint(from submodel: Submodel) -> CarbonFootprint {
        let elements = submodel.flattenedElements()
        var propertyValues: [String: String] = [:]

        for (path, element) in elements {
            if case .property(let property) = element {
                propertyValues[path] = property.value
            }
        }

        return CarbonFootprint(
            pcfCO2eq: Double(propertyValues["PCFCO2eq"] ?? ""),
            pcfReferenceUnitForCalculation: propertyValues["PCFReferenceValueForCalculation"],
            pcfCalculationMethod: propertyValues["PCFCalculationMethod"],
            tcfCO2eq: Double(propertyValues["TCFCO2eq"] ?? ""),
            ucfCO2eq: Double(propertyValues["UCFCO2eq"] ?? ""),
            eolCO2eq: Double(propertyValues["EOLCO2eq"] ?? ""),
            verificationStatement: URL(string: propertyValues["PCFVerificationStatement"] ?? ""),
            validityPeriodStart: parseDate(propertyValues["PCFValidityPeriodStart"]),
            validityPeriodEnd: parseDate(propertyValues["PCFValidityPeriodEnd"]),
            verifierName: propertyValues["PCFVerifierName"]
        )
    }

    /// Parse documentation from submodel.
    private func parseDocumentation(from submodel: Submodel) -> [Document] {
        var documents: [Document] = []

        guard let elements = submodel.submodelElements else { return documents }

        for element in elements {
            if case .submodelElementCollection(let collection) = element,
               let docElements = collection.value {

                var title: [LangString] = []
                var summary: [LangString] = []
                var documentClassValue: String?
                var version: String?
                var files: [DigitalFile] = []

                for docElement in docElements {
                    switch docElement {
                    case .multiLanguageProperty(let mlp) where mlp.idShort.contains("Title"):
                        title = mlp.value ?? []

                    case .multiLanguageProperty(let mlp) where mlp.idShort.contains("Summary"):
                        summary = mlp.value ?? []

                    case .property(let prop) where prop.idShort.contains("DocumentClassId"):
                        documentClassValue = prop.value

                    case .property(let prop) where prop.idShort.contains("Version"):
                        version = prop.value

                    case .file(let file):
                        if let urlString = file.value, let url = URL(string: urlString) {
                            files.append(DigitalFile(
                                fileFormat: file.contentType,
                                file: url
                            ))
                        }

                    default:
                        break
                    }
                }

                if !title.isEmpty || !files.isEmpty {
                    let docClass = DocumentClass(rawValue: documentClassValue ?? "") ?? .other

                    let document = Document(
                        id: collection.idShort,
                        title: title.isEmpty ? [LangString(language: "en", text: collection.idShort)] : title,
                        summary: summary.isEmpty ? nil : summary,
                        documentClass: docClass,
                        documentVersion: version,
                        digitalFile: files.isEmpty ? nil : files
                    )
                    documents.append(document)
                }
            }
        }

        return documents
    }

    /// Parse technical data summary from submodel.
    private func parseTechnicalData(from submodel: Submodel) -> TechnicalDataSummary {
        let elements = submodel.flattenedElements()
        var properties: [TechnicalProperty] = []

        for (path, element) in elements {
            switch element {
            case .property(let property):
                if let value = property.value {
                    properties.append(TechnicalProperty(
                        name: property.idShort,
                        path: path,
                        value: value,
                        unit: nil
                    ))
                }

            case .range(let range):
                let rangeValue = "\(range.min ?? "?") - \(range.max ?? "?")"
                properties.append(TechnicalProperty(
                    name: range.idShort,
                    path: path,
                    value: rangeValue,
                    unit: nil
                ))

            default:
                break
            }
        }

        return TechnicalDataSummary(
            submodelId: submodel.id,
            idShort: submodel.idShort,
            properties: properties
        )
    }

    /// Parse date from string.
    private func parseDate(_ string: String?) -> Date? {
        guard let string = string else { return nil }

        let formatters = [
            ISO8601DateFormatter(),
        ]

        for formatter in formatters {
            if let date = formatter.date(from: string) {
                return date
            }
        }

        // Try simple date format
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        return dateFormatter.date(from: string)
    }

    // MARK: - Private Methods - Apply Data

    /// Apply loaded passport data to published properties.
    private func applyPassportData(_ data: PassportData) {
        self.asset = data.asset
        self.digitalNameplate = data.nameplate
        self.carbonFootprint = data.carbonFootprint
        self.documents = data.documents
        self.technicalData = data.technicalData
    }

    // MARK: - Private Methods - Cache Update

    /// Update the cache with fresh data.
    private func updateCache(with data: PassportData) async {
        let encoder = JSONEncoder()

        // Cache nameplate
        if let nameplate = data.nameplate,
           let encodedData = try? encoder.encode(nameplate) {
            let cached = CachedSubmodel(
                id: "\(assetId)-nameplate",
                aasId: assetId,
                semanticId: IDTASemanticId.digitalNameplate,
                idShort: "DigitalNameplate",
                data: encodedData,
                ttlSeconds: CachedSubmodel.TTL.staticData
            )
            try? await persistenceService.cacheSubmodel(cached)
        }

        // Cache carbon footprint
        if let carbonFootprint = data.carbonFootprint,
           let encodedData = try? encoder.encode(carbonFootprint) {
            let cached = CachedSubmodel(
                id: "\(assetId)-carbonfootprint",
                aasId: assetId,
                semanticId: IDTASemanticId.carbonFootprint,
                idShort: "CarbonFootprint",
                data: encodedData,
                ttlSeconds: CachedSubmodel.TTL.semiStaticData
            )
            try? await persistenceService.cacheSubmodel(cached)
        }

        // Cache documentation
        if !data.documents.isEmpty,
           let encodedData = try? encoder.encode(HandoverDocumentation(documents: data.documents)) {
            let cached = CachedSubmodel(
                id: "\(assetId)-documentation",
                aasId: assetId,
                semanticId: IDTASemanticId.documentation,
                idShort: "HandoverDocumentation",
                data: encodedData,
                ttlSeconds: CachedSubmodel.TTL.semiStaticData
            )
            try? await persistenceService.cacheSubmodel(cached)
        }

        // Cache technical data
        if let technicalData = data.technicalData,
           let encodedData = try? encoder.encode(technicalData) {
            let cached = CachedSubmodel(
                id: "\(assetId)-technicaldata",
                aasId: assetId,
                semanticId: IDTASemanticId.technicalData,
                idShort: "TechnicalData",
                data: encodedData,
                ttlSeconds: CachedSubmodel.TTL.staticData
            )
            try? await persistenceService.cacheSubmodel(cached)
        }
    }
}

// MARK: - Passport Data

/// Container for passport-related data.
private struct PassportData {
    var asset: Asset?
    var nameplate: DigitalNameplate?
    var carbonFootprint: CarbonFootprint?
    var documents: [Document] = []
    var technicalData: TechnicalDataSummary?

    var hasAnyData: Bool {
        nameplate != nil || carbonFootprint != nil || !documents.isEmpty || technicalData != nil
    }
}

// MARK: - Technical Data Summary

/// Summary of technical data properties.
public struct TechnicalDataSummary: Codable, Sendable {
    public let submodelId: String
    public let idShort: String?
    public let properties: [TechnicalProperty]

    public init(submodelId: String, idShort: String?, properties: [TechnicalProperty]) {
        self.submodelId = submodelId
        self.idShort = idShort
        self.properties = properties
    }
}

/// A single technical property.
public struct TechnicalProperty: Codable, Sendable, Identifiable {
    public var id: String { path }
    public let name: String
    public let path: String
    public let value: String
    public let unit: String?

    public init(name: String, path: String, value: String, unit: String?) {
        self.name = name
        self.path = path
        self.value = value
        self.unit = unit
    }

    /// Formatted value with unit.
    public var formattedValue: String {
        if let unit = unit {
            return "\(value) \(unit)"
        }
        return value
    }
}

// MARK: - Passport Error

/// Errors that can occur during passport loading.
public enum PassportError: LocalizedError {
    case networkError(String)
    case parseError(String)
    case notFound
    case unauthorized
    case unknown(Error)

    public var errorDescription: String? {
        switch self {
        case .networkError:
            return "Unable to load asset data. Please check your connection and try again."
        case .parseError:
            return "The asset data could not be read. Please try again later."
        case .notFound:
            return "This asset could not be found. It may have been removed or the link is invalid."
        case .unauthorized:
            return "You don't have permission to view this asset. Please sign in or contact your administrator."
        case .unknown(let error):
            let description = error.localizedDescription
            return description.isEmpty ? "An unexpected error occurred. Please try again." : description
        }
    }

    /// Create from generic error.
    public static func from(_ error: Error) -> PassportError {
        if let passportError = error as? PassportError {
            return passportError
        }

        if let aasError = error as? AASError {
            if aasError.isNotFound {
                return .notFound
            }
            if aasError.isAuthError {
                return .unauthorized
            }
            switch aasError {
            case .networkError(let underlying):
                return .networkError(underlying.localizedDescription)
            case .decodingError(let message, _):
                return .parseError(message)
            default:
                return .unknown(error)
            }
        }

        return .unknown(error)
    }
}

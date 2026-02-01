//
//  AASXPassportExtractor.swift
//  TwinAct Field Companion
//
//  Extracts Digital Product Passport data from AASX package JSON.
//  Parses submodels to extract Nameplate, Carbon Footprint, and Technical Data.
//

import Foundation
import os.log

// MARK: - AASX Passport Extractor

/// Extracts passport-related data from AASX package JSON structure.
public final class AASXPassportExtractor {

    // MARK: - Singleton

    public static let shared = AASXPassportExtractor()

    // MARK: - Properties

    private let logger = Logger(
        subsystem: AppConfiguration.AppInfo.bundleIdentifier,
        category: "AASXPassportExtractor"
    )

    // MARK: - Public Types

    /// Extracted passport data from AASX
    public struct ExtractedPassportData {
        public var assetName: String?
        public var assetId: String?
        public var nameplate: DigitalNameplate?
        public var carbonFootprint: CarbonFootprint?
        public var technicalData: TechnicalDataSummary?
        public var documents: [Document]

        public init(
            assetName: String? = nil,
            assetId: String? = nil,
            nameplate: DigitalNameplate? = nil,
            carbonFootprint: CarbonFootprint? = nil,
            technicalData: TechnicalDataSummary? = nil,
            documents: [Document] = []
        ) {
            self.assetName = assetName
            self.assetId = assetId
            self.nameplate = nameplate
            self.carbonFootprint = carbonFootprint
            self.technicalData = technicalData
            self.documents = documents
        }

        /// Whether any passport data was extracted
        public var hasData: Bool {
            nameplate != nil || carbonFootprint != nil || technicalData != nil || !documents.isEmpty
        }
    }

    // MARK: - Public Methods

    /// Extract passport data from AASX content store.
    /// - Parameter assetId: Asset identifier in the content store
    /// - Returns: Extracted passport data, or nil if no data found
    public func extractPassportData(for assetId: String) -> ExtractedPassportData? {
        guard let json = AASXContentStore.shared.aasJSON(for: assetId) else {
            logger.debug("No AAS JSON found for asset: \(assetId)")
            return nil
        }

        return extractFromJSON(json, assetId: assetId)
    }

    /// Extract passport data from raw JSON dictionary.
    /// - Parameters:
    ///   - json: AAS JSON dictionary
    ///   - assetId: Asset identifier (for logging)
    /// - Returns: Extracted passport data
    public func extractFromJSON(_ json: [String: Any], assetId: String) -> ExtractedPassportData {
        var data = ExtractedPassportData()

        // Extract asset info from AAS shells
        if let shells = json["assetAdministrationShells"] as? [[String: Any]],
           let firstShell = shells.first {
            data.assetName = firstShell["idShort"] as? String
            data.assetId = firstShell["id"] as? String

            // Try to get asset info
            if let assetInfo = firstShell["assetInformation"] as? [String: Any] {
                if let globalAssetId = assetInfo["globalAssetId"] as? String {
                    data.assetId = globalAssetId
                }
            }
        }

        // Extract submodels
        if let submodels = json["submodels"] as? [[String: Any]] {
            for submodel in submodels {
                processSubmodel(submodel, into: &data)
            }
        }

        logger.debug("Extracted passport data for \(assetId): nameplate=\(data.nameplate != nil), carbon=\(data.carbonFootprint != nil), tech=\(data.technicalData != nil)")

        return data
    }

    // MARK: - Private Methods

    /// Process a single submodel and extract relevant data.
    private func processSubmodel(_ submodel: [String: Any], into data: inout ExtractedPassportData) {
        let idShort = (submodel["idShort"] as? String)?.lowercased() ?? ""
        let semanticId = extractSemanticId(from: submodel)

        // Determine submodel type by semantic ID or idShort
        if isNameplateSubmodel(semanticId: semanticId, idShort: idShort) {
            data.nameplate = extractNameplate(from: submodel)
        } else if isCarbonFootprintSubmodel(semanticId: semanticId, idShort: idShort) {
            data.carbonFootprint = extractCarbonFootprint(from: submodel)
        } else if isTechnicalDataSubmodel(semanticId: semanticId, idShort: idShort) {
            data.technicalData = extractTechnicalData(from: submodel)
        } else if isDocumentationSubmodel(semanticId: semanticId, idShort: idShort) {
            data.documents = extractDocuments(from: submodel)
        }
    }

    /// Extract semantic ID from submodel.
    private func extractSemanticId(from submodel: [String: Any]) -> String? {
        if let semanticId = submodel["semanticId"] as? [String: Any] {
            if let keys = semanticId["keys"] as? [[String: Any]],
               let firstKey = keys.first,
               let value = firstKey["value"] as? String {
                return value
            }
        }
        return nil
    }

    // MARK: - Submodel Type Detection

    private func isNameplateSubmodel(semanticId: String?, idShort: String) -> Bool {
        if let sem = semanticId?.lowercased() {
            if sem.contains("nameplate") { return true }
        }
        return idShort.contains("nameplate") || idShort.contains("identification")
    }

    private func isCarbonFootprintSubmodel(semanticId: String?, idShort: String) -> Bool {
        if let sem = semanticId?.lowercased() {
            if sem.contains("carbonfootprint") || sem.contains("sustainability") { return true }
        }
        return idShort.contains("carbon") || idShort.contains("sustainability") || idShort.contains("footprint")
    }

    private func isTechnicalDataSubmodel(semanticId: String?, idShort: String) -> Bool {
        if let sem = semanticId?.lowercased() {
            if sem.contains("technicaldata") || sem.contains("technical_data") { return true }
        }
        return idShort.contains("technical") || idShort.contains("specification")
    }

    private func isDocumentationSubmodel(semanticId: String?, idShort: String) -> Bool {
        if let sem = semanticId?.lowercased() {
            if sem.contains("documentation") || sem.contains("handover") { return true }
        }
        return idShort.contains("document") || idShort.contains("handover")
    }

    // MARK: - Nameplate Extraction

    private func extractNameplate(from submodel: [String: Any]) -> DigitalNameplate {
        let properties = flattenProperties(from: submodel)

        return DigitalNameplate(
            manufacturerName: properties["ManufacturerName"] ?? properties["manufacturerName"] ?? properties["Manufacturer"],
            manufacturerProductDesignation: properties["ManufacturerProductDesignation"] ?? properties["ProductDesignation"] ?? properties["ProductName"],
            manufacturerProductFamily: properties["ManufacturerProductFamily"] ?? properties["ProductFamily"],
            manufacturerProductType: properties["ManufacturerProductType"] ?? properties["ProductType"] ?? properties["ModelNumber"],
            orderCode: properties["OrderCode"] ?? properties["OrderNumber"] ?? properties["ArticleNumber"],
            serialNumber: properties["SerialNumber"] ?? properties["serialNumber"],
            batchNumber: properties["BatchNumber"] ?? properties["LotNumber"],
            productionDate: parseDate(properties["DateOfManufacture"] ?? properties["ManufacturingDate"]),
            countryOfOrigin: properties["CountryOfOrigin"],
            yearOfConstruction: Int(properties["YearOfConstruction"] ?? ""),
            hardwareVersion: properties["HardwareVersion"],
            firmwareVersion: properties["FirmwareVersion"],
            softwareVersion: properties["SoftwareVersion"],
            manufacturerLogo: URL(string: properties["CompanyLogo"] ?? properties["ManufacturerLogo"] ?? ""),
            productImage: URL(string: properties["ProductImage"] ?? properties["AssetImage"] ?? "")
        )
    }

    // MARK: - Carbon Footprint Extraction

    private func extractCarbonFootprint(from submodel: [String: Any]) -> CarbonFootprint {
        let properties = flattenProperties(from: submodel)

        return CarbonFootprint(
            pcfCO2eq: Double(properties["PCFCO2eq"] ?? properties["PCFCarbonFootprint"] ?? properties["ProductCarbonFootprint"] ?? ""),
            pcfReferenceUnitForCalculation: properties["PCFReferenceValueForCalculation"] ?? properties["ReferenceUnit"],
            pcfCalculationMethod: properties["PCFCalculationMethod"] ?? properties["CalculationMethod"],
            tcfCO2eq: Double(properties["TCFCO2eq"] ?? properties["TransportCarbonFootprint"] ?? ""),
            ucfCO2eq: Double(properties["UCFCO2eq"] ?? properties["UsePhaseCarbonFootprint"] ?? ""),
            eolCO2eq: Double(properties["EOLCO2eq"] ?? properties["EndOfLifeCarbonFootprint"] ?? ""),
            verificationStatement: URL(string: properties["PCFVerificationStatement"] ?? ""),
            validityPeriodStart: parseDate(properties["PCFValidityPeriodStart"]),
            validityPeriodEnd: parseDate(properties["PCFValidityPeriodEnd"]),
            verifierName: properties["PCFVerifierName"] ?? properties["VerifierName"]
        )
    }

    // MARK: - Technical Data Extraction

    private func extractTechnicalData(from submodel: [String: Any]) -> TechnicalDataSummary {
        let properties = flattenProperties(from: submodel)
        let submodelId = submodel["id"] as? String ?? "unknown"
        let idShort = submodel["idShort"] as? String

        let technicalProperties = properties.map { (key, value) in
            TechnicalProperty(
                name: formatPropertyName(key),
                path: key,
                value: value,
                unit: extractUnit(from: key, properties: properties)
            )
        }

        return TechnicalDataSummary(
            submodelId: submodelId,
            idShort: idShort,
            properties: technicalProperties
        )
    }

    // MARK: - Documentation Extraction

    private func extractDocuments(from submodel: [String: Any]) -> [Document] {
        var documents: [Document] = []

        guard let elements = submodel["submodelElements"] as? [[String: Any]] else {
            return documents
        }

        for element in elements {
            if let modelType = element["modelType"] as? String,
               modelType == "SubmodelElementCollection" {
                if let doc = extractDocument(from: element) {
                    documents.append(doc)
                }
            }
        }

        return documents
    }

    private func extractDocument(from element: [String: Any]) -> Document? {
        let idShort = element["idShort"] as? String ?? "Document"
        var title = [LangString(language: "en", text: idShort)]
        var summary: [LangString]? = nil
        var documentClass: DocumentClass = .other
        var version: String? = nil
        var files: [DigitalFile] = []

        if let value = element["value"] as? [[String: Any]] {
            for item in value {
                let itemIdShort = (item["idShort"] as? String)?.lowercased() ?? ""

                if itemIdShort.contains("title") {
                    if let langStrings = extractMultiLanguageValue(from: item) {
                        title = langStrings
                    }
                } else if itemIdShort.contains("summary") || itemIdShort.contains("description") {
                    summary = extractMultiLanguageValue(from: item)
                } else if itemIdShort.contains("class") {
                    if let classValue = item["value"] as? String {
                        documentClass = DocumentClass(rawValue: classValue) ?? .other
                    }
                } else if itemIdShort.contains("version") {
                    version = item["value"] as? String
                } else if item["modelType"] as? String == "File" {
                    if let fileValue = item["value"] as? String,
                       let url = URL(string: fileValue) {
                        let contentType = item["contentType"] as? String ?? "application/octet-stream"
                        files.append(DigitalFile(fileFormat: contentType, file: url))
                    }
                }
            }
        }

        return Document(
            id: idShort,
            title: title,
            summary: summary,
            documentClass: documentClass,
            documentVersion: version,
            digitalFile: files.isEmpty ? nil : files
        )
    }

    private func extractMultiLanguageValue(from element: [String: Any]) -> [LangString]? {
        if let value = element["value"] as? [[String: Any]] {
            return value.compactMap { langItem in
                guard let lang = langItem["language"] as? String,
                      let text = langItem["text"] as? String else {
                    return nil
                }
                return LangString(language: lang, text: text)
            }
        }
        return nil
    }

    // MARK: - Property Flattening

    /// Flatten all properties from a submodel into a key-value dictionary.
    private func flattenProperties(from submodel: [String: Any]) -> [String: String] {
        var properties: [String: String] = [:]

        guard let elements = submodel["submodelElements"] as? [[String: Any]] else {
            return properties
        }

        flattenElements(elements, into: &properties, prefix: "")

        return properties
    }

    /// Recursively flatten submodel elements.
    private func flattenElements(_ elements: [[String: Any]], into properties: inout [String: String], prefix: String) {
        for element in elements {
            let idShort = element["idShort"] as? String ?? ""
            let key = prefix.isEmpty ? idShort : "\(prefix).\(idShort)"
            let modelType = element["modelType"] as? String ?? ""

            switch modelType {
            case "Property":
                if let value = element["value"] as? String {
                    properties[idShort] = value
                    if !prefix.isEmpty {
                        properties[key] = value
                    }
                }

            case "MultiLanguageProperty":
                if let langStrings = element["value"] as? [[String: Any]] {
                    // Prefer English, fallback to first
                    let englishText = langStrings.first { ($0["language"] as? String)?.lowercased().hasPrefix("en") == true }?["text"] as? String
                    let text = englishText ?? (langStrings.first?["text"] as? String)
                    if let text = text {
                        properties[idShort] = text
                        if !prefix.isEmpty {
                            properties[key] = text
                        }
                    }
                }

            case "SubmodelElementCollection":
                if let nestedElements = element["value"] as? [[String: Any]] {
                    flattenElements(nestedElements, into: &properties, prefix: key)
                }

            case "Range":
                let min = element["min"] as? String ?? "?"
                let max = element["max"] as? String ?? "?"
                properties[idShort] = "\(min) - \(max)"

            default:
                break
            }
        }
    }

    // MARK: - Helpers

    private func parseDate(_ string: String?) -> Date? {
        guard let string = string else { return nil }

        // Try ISO8601 first
        if let date = ISO8601DateFormatter().date(from: string) {
            return date
        }

        // Try common date formats
        let formatters: [DateFormatter] = {
            let dateOnly = DateFormatter()
            dateOnly.dateFormat = "yyyy-MM-dd"

            let dateTime = DateFormatter()
            dateTime.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"

            return [dateOnly, dateTime]
        }()

        for formatter in formatters {
            if let date = formatter.date(from: string) {
                return date
            }
        }

        return nil
    }

    private func formatPropertyName(_ key: String) -> String {
        // Convert camelCase to Title Case with spaces
        var result = ""
        for (index, char) in key.enumerated() {
            if char.isUppercase && index > 0 {
                result += " "
            }
            result += String(char)
        }
        return result.prefix(1).uppercased() + result.dropFirst()
    }

    private func extractUnit(from key: String, properties: [String: String]) -> String? {
        // Try to find a corresponding unit property
        let unitKey = key + "Unit"
        return properties[unitKey]
    }
}

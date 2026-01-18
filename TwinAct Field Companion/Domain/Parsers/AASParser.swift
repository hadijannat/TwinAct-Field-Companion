//
//  AASParser.swift
//  TwinAct Field Companion
//
//  Convenience parser for AAS JSON data.
//  Handles raw JSON parsing and conversion to AAS models.
//

import Foundation

// MARK: - AAS Parser

/// Parser for AAS JSON data from API responses.
public struct AASParser {

    // MARK: - JSON Decoding

    /// Shared JSON decoder configured for AAS data.
    public static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)

            // Try ISO 8601 with fractional seconds
            let isoFormatter = ISO8601DateFormatter()
            isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = isoFormatter.date(from: dateString) {
                return date
            }

            // Try ISO 8601 without fractional seconds
            isoFormatter.formatOptions = [.withInternetDateTime]
            if let date = isoFormatter.date(from: dateString) {
                return date
            }

            // Try date-only format
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            if let date = dateFormatter.date(from: dateString) {
                return date
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode date: \(dateString)"
            )
        }
        return decoder
    }()

    // MARK: - Submodel Parsing

    /// Parse a Submodel from JSON data.
    public static func parseSubmodel(from data: Data) throws -> Submodel {
        try decoder.decode(Submodel.self, from: data)
    }

    /// Parse a Submodel from JSON dictionary.
    public static func parseSubmodel(from json: [String: Any]) throws -> Submodel {
        let data = try JSONSerialization.data(withJSONObject: json)
        return try parseSubmodel(from: data)
    }

    /// Parse an array of Submodels from JSON data.
    public static func parseSubmodels(from data: Data) throws -> [Submodel] {
        try decoder.decode([Submodel].self, from: data)
    }

    // MARK: - AAS Parsing

    /// Parse an Asset Administration Shell from JSON data.
    public static func parseAAS(from data: Data) throws -> AssetAdministrationShell {
        try decoder.decode(AssetAdministrationShell.self, from: data)
    }

    /// Parse an AAS descriptor from JSON data.
    public static func parseAASDescriptor(from data: Data) throws -> AASDescriptor {
        try decoder.decode(AASDescriptor.self, from: data)
    }

    /// Parse an array of AAS descriptors from JSON data.
    public static func parseAASDescriptors(from data: Data) throws -> [AASDescriptor] {
        try decoder.decode([AASDescriptor].self, from: data)
    }

    // MARK: - Submodel Element Parsing

    /// Parse a SubmodelElement from JSON data.
    public static func parseSubmodelElement(from data: Data) throws -> SubmodelElement {
        try decoder.decode(SubmodelElement.self, from: data)
    }

    /// Parse an array of SubmodelElements from JSON data.
    public static func parseSubmodelElements(from data: Data) throws -> [SubmodelElement] {
        try decoder.decode([SubmodelElement].self, from: data)
    }

    // MARK: - Paged Results

    /// Parse a paged result of AAS descriptors.
    public static func parsePagedAASDescriptors(from data: Data) throws -> PagedResult<AASDescriptor> {
        try decoder.decode(PagedResult<AASDescriptor>.self, from: data)
    }

    /// Parse a paged result of Submodel descriptors.
    public static func parsePagedSubmodelDescriptors(from data: Data) throws -> PagedResult<SubmodelDescriptor> {
        try decoder.decode(PagedResult<SubmodelDescriptor>.self, from: data)
    }

    // MARK: - Domain Model Parsing

    /// Parse JSON data directly to a typed domain model.
    public static func parseToDomainModel<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        try decoder.decode(type, from: data)
    }

    /// Parse a Submodel and convert to the appropriate domain model based on semantic ID.
    public static func parseAndConvert(from data: Data) throws -> Any {
        let submodel = try parseSubmodel(from: data)
        return try convertToDomainModel(submodel)
    }

    /// Convert a Submodel to the appropriate domain model based on semantic ID.
    public static func convertToDomainModel(_ submodel: Submodel) throws -> Any {
        guard let semanticId = submodel.semanticId,
              let idValue = semanticId.keys.first?.value else {
            throw AASParserError.missingSemanticId
        }

        let lowercased = idValue.lowercased()

        if lowercased.contains("nameplate") {
            return try SubmodelElementParser.parseDigitalNameplate(from: submodel)
        }
        if lowercased.contains("handoverdocumentation") || lowercased.contains("documentation") {
            return try SubmodelElementParser.parseHandoverDocumentation(from: submodel)
        }
        if lowercased.contains("maintenance") {
            return try SubmodelElementParser.parseMaintenanceInstructions(from: submodel)
        }
        if lowercased.contains("servicerequest") {
            return try SubmodelElementParser.parseServiceRequest(from: submodel)
        }
        if lowercased.contains("timeseries") {
            return try SubmodelElementParser.parseTimeSeriesData(from: submodel)
        }
        if lowercased.contains("carbonfootprint") || lowercased.contains("sustainability") {
            return try SubmodelElementParser.parseCarbonFootprint(from: submodel)
        }

        throw AASParserError.unsupportedSubmodelType(idValue)
    }

    // MARK: - Validation

    /// Validate that data is valid AAS JSON.
    public static func validateJSON(_ data: Data) -> Bool {
        guard let _ = try? JSONSerialization.jsonObject(with: data) else {
            return false
        }
        return true
    }

    /// Check if a submodel matches a specific semantic ID.
    public static func submodelMatches(_ submodel: Submodel, semanticId: String) -> Bool {
        guard let submodelSemanticId = submodel.semanticId,
              let idValue = submodelSemanticId.keys.first?.value else {
            return false
        }
        return idValue.lowercased().contains(semanticId.lowercased())
    }
}

// MARK: - Parser Errors

/// Errors that can occur during AAS parsing.
public enum AASParserError: Error, LocalizedError {
    case invalidJSON
    case missingSemanticId
    case unsupportedSubmodelType(String)
    case decodingFailed(Error)

    public var errorDescription: String? {
        switch self {
        case .invalidJSON:
            return "Invalid JSON data"
        case .missingSemanticId:
            return "Submodel is missing semantic ID"
        case .unsupportedSubmodelType(let type):
            return "Unsupported submodel type: \(type)"
        case .decodingFailed(let error):
            return "Decoding failed: \(error.localizedDescription)"
        }
    }
}

// MARK: - Submodel Type Detection

extension AASParser {

    /// Detect the domain model type for a Submodel.
    public static func detectSubmodelType(_ submodel: Submodel) -> SubmodelType? {
        SubmodelType.from(semanticId: submodel.semanticId)
    }

    /// Detect the domain model type from a semantic ID string.
    public static func detectSubmodelType(fromSemanticId: String) -> SubmodelType? {
        SubmodelType.from(semanticIdString: fromSemanticId)
    }
}

// MARK: - JSON Helpers

extension AASParser {

    /// Pretty print JSON data for debugging.
    public static func prettyPrint(_ data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data),
              let prettyData = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted),
              let prettyString = String(data: prettyData, encoding: .utf8) else {
            return nil
        }
        return prettyString
    }

    /// Extract a specific property value from JSON data.
    public static func extractPropertyValue(from data: Data, path: String) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        let pathComponents = path.split(separator: "/").map(String.init)
        var current: Any = json

        for component in pathComponents {
            if let dict = current as? [String: Any] {
                if let next = dict[component] {
                    current = next
                } else if let submodelElements = dict["submodelElements"] as? [[String: Any]],
                          let element = submodelElements.first(where: { ($0["idShort"] as? String) == component }) {
                    current = element
                } else {
                    return nil
                }
            } else {
                return nil
            }
        }

        if let dict = current as? [String: Any] {
            return dict["value"] as? String
        }
        return current as? String
    }
}

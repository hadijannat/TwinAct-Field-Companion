//
//  AASWriter.swift
//  TwinAct Field Companion
//
//  Utilities for writing/serializing AAS data for API requests.
//  Currently only ServiceRequest is writable; other submodels are read-only.
//

import Foundation

// MARK: - AAS Writer

/// Writer for serializing AAS data to JSON for API requests.
public struct AASWriter {

    // MARK: - JSON Encoding

    /// Shared JSON encoder configured for AAS data.
    public static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()

    /// Encoder for pretty-printed output (debugging/logging).
    public static let prettyEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()

    // MARK: - Generic Encoding

    /// Encode any Codable value to JSON data.
    public static func encode<T: Encodable>(_ value: T) throws -> Data {
        try encoder.encode(value)
    }

    /// Encode any Codable value to a pretty-printed JSON string.
    public static func encodePretty<T: Encodable>(_ value: T) throws -> String {
        let data = try prettyEncoder.encode(value)
        return String(data: data, encoding: .utf8) ?? ""
    }

    // MARK: - Submodel Element Encoding

    /// Encode a SubmodelElement to JSON data.
    public static func encode(_ element: SubmodelElement) throws -> Data {
        try encoder.encode(element)
    }

    /// Encode an array of SubmodelElements to JSON data.
    public static func encode(_ elements: [SubmodelElement]) throws -> Data {
        try encoder.encode(elements)
    }

    // MARK: - Submodel Encoding

    /// Encode a Submodel to JSON data.
    public static func encode(_ submodel: Submodel) throws -> Data {
        try encoder.encode(submodel)
    }

    // MARK: - Property Value Encoding

    /// Create a property value update payload.
    public static func encodePropertyUpdate(value: String) throws -> Data {
        let update = PropertyValueUpdate(value: value)
        return try encoder.encode(update)
    }

    /// Create a property value update from any value.
    public static func encodePropertyUpdate<T>(_ value: T, type: DataTypeDefXsd) throws -> Data {
        let stringValue = AASValueConverter.toString(value, type: type)
        return try encodePropertyUpdate(value: stringValue)
    }

    // MARK: - Service Request Writing

    /// Note: ServiceRequest is the ONLY writable submodel type.
    /// Use ServiceRequestWriter for ServiceRequest-specific operations.

    /// Encode a ServiceRequest for API submission.
    public static func encode(_ request: ServiceRequest) throws -> Data {
        try ServiceRequestWriter.toAPIBody(request)
    }

    /// Encode a ServiceRequest as a complete Submodel.
    public static func encodeAsSubmodel(_ request: ServiceRequest, submodelId: String? = nil) throws -> Data {
        let submodel = ServiceRequestWriter.toSubmodel(request, submodelId: submodelId)
        return try encode(submodel)
    }

    // MARK: - Reference Creation

    /// Create a Reference to a submodel.
    public static func createSubmodelReference(submodelId: String) -> Reference {
        Reference(
            type: .modelReference,
            keys: [Key(type: .submodel, value: submodelId)]
        )
    }

    /// Create a Reference to a submodel element.
    public static func createElementReference(submodelId: String, elementPath: String) -> Reference {
        var keys = [Key(type: .submodel, value: submodelId)]

        let pathComponents = elementPath.split(separator: "/").map(String.init)
        for component in pathComponents {
            keys.append(Key(type: .submodelElement, value: component))
        }

        return Reference(type: .modelReference, keys: keys)
    }

    /// Create a global/external reference.
    public static func createGlobalReference(value: String) -> Reference {
        Reference.globalReference(value)
    }

    // MARK: - Property Creation

    /// Create a Property SubmodelElement.
    public static func createProperty(
        idShort: String,
        value: String,
        valueType: DataTypeDefXsd = .string,
        semanticId: String? = nil
    ) -> SubmodelElement {
        .property(Property(
            idShort: idShort,
            valueType: valueType,
            value: value,
            semanticId: semanticId.map { Reference.globalReference($0) }
        ))
    }

    /// Create a MultiLanguageProperty SubmodelElement.
    public static func createMultiLanguageProperty(
        idShort: String,
        values: [LangString],
        semanticId: String? = nil
    ) -> SubmodelElement {
        .multiLanguageProperty(MultiLanguageProperty(
            idShort: idShort,
            value: values,
            semanticId: semanticId.map { Reference.globalReference($0) }
        ))
    }

    /// Create a File SubmodelElement.
    public static func createFile(
        idShort: String,
        contentType: String,
        value: String,
        semanticId: String? = nil
    ) -> SubmodelElement {
        .file(AASFile(
            idShort: idShort,
            contentType: contentType,
            value: value,
            semanticId: semanticId.map { Reference.globalReference($0) }
        ))
    }

    /// Create a SubmodelElementCollection.
    public static func createCollection(
        idShort: String,
        elements: [SubmodelElement],
        semanticId: String? = nil
    ) -> SubmodelElement {
        .submodelElementCollection(SubmodelElementCollection(
            idShort: idShort,
            value: elements,
            semanticId: semanticId.map { Reference.globalReference($0) }
        ))
    }

    // MARK: - Validation

    /// Validate that a value is appropriate for the given data type.
    public static func validateValue(_ value: String, for type: DataTypeDefXsd) -> Bool {
        switch type {
        case .string, .anyURI:
            return true

        case .integer, .int, .long, .short, .byte,
             .nonNegativeInteger, .positiveInteger, .nonPositiveInteger, .negativeInteger:
            return Int(value) != nil

        case .unsignedLong, .unsignedInt, .unsignedShort, .unsignedByte:
            return UInt(value) != nil

        case .decimal, .double, .float:
            return Double(value) != nil

        case .boolean:
            let lower = value.lowercased()
            return lower == "true" || lower == "false" || lower == "1" || lower == "0"

        case .dateTime:
            return ISO8601DateFormatter().date(from: value) != nil

        case .date:
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter.date(from: value) != nil

        case .time:
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss"
            return formatter.date(from: value) != nil

        default:
            return true
        }
    }
}

// MARK: - Writer Errors

/// Errors that can occur during AAS writing.
public enum AASWriterError: Error, LocalizedError {
    case encodingFailed(Error)
    case invalidValue(String, DataTypeDefXsd)
    case readOnlySubmodel(String)

    public var errorDescription: String? {
        switch self {
        case .encodingFailed(let error):
            return "Encoding failed: \(error.localizedDescription)"
        case .invalidValue(let value, let type):
            return "Invalid value '\(value)' for type \(type.rawValue)"
        case .readOnlySubmodel(let type):
            return "Cannot write to read-only submodel: \(type)"
        }
    }
}

// MARK: - Submodel Creation

extension AASWriter {

    /// Create a new empty Submodel with the given parameters.
    public static func createSubmodel(
        id: String,
        idShort: String,
        semanticId: String,
        elements: [SubmodelElement] = []
    ) -> Submodel {
        Submodel(
            id: id,
            idShort: idShort,
            semanticId: Reference.globalReference(semanticId),
            kind: .instance,
            submodelElements: elements
        )
    }

    /// Check if a submodel type is writable.
    public static func isWritable(_ type: SubmodelType) -> Bool {
        type.isWritable
    }

    /// Get the list of writable submodel types.
    public static var writableSubmodelTypes: [SubmodelType] {
        SubmodelType.allCases.filter { $0.isWritable }
    }
}

// MARK: - Batch Operations

extension AASWriter {

    /// Encode multiple SubmodelElements for batch update.
    public static func encodeBatch(_ elements: [(path: String, element: SubmodelElement)]) throws -> Data {
        let updates = elements.map { (path: $0.path, element: $0.element) }
        return try encoder.encode(updates.map { $0.element })
    }
}

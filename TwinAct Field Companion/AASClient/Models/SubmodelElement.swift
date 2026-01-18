//
//  SubmodelElement.swift
//  TwinAct Field Companion
//
//  Submodel element models for AAS API v3.
//  Implements the polymorphic submodel element types using a discriminated enum.
//

import Foundation

// MARK: - Submodel Element (Discriminated Union)

/// Base for all submodel elements.
/// Uses a discriminated union pattern for type-safe handling.
public enum SubmodelElement: Codable, Sendable, Hashable {
    case property(Property)
    case multiLanguageProperty(MultiLanguageProperty)
    case submodelElementCollection(SubmodelElementCollection)
    case submodelElementList(SubmodelElementList)
    case file(AASFile)
    case blob(Blob)
    case referenceElement(ReferenceElement)
    case range(RangeElement)
    case entity(Entity)
    case relationshipElement(RelationshipElement)
    case annotatedRelationshipElement(AnnotatedRelationshipElement)
    case operation(Operation)
    case capability(Capability)
    case basicEventElement(BasicEventElement)

    /// Model type discriminator used in JSON encoding/decoding.
    private enum ModelType: String, Codable {
        case property = "Property"
        case multiLanguageProperty = "MultiLanguageProperty"
        case submodelElementCollection = "SubmodelElementCollection"
        case submodelElementList = "SubmodelElementList"
        case file = "File"
        case blob = "Blob"
        case referenceElement = "ReferenceElement"
        case range = "Range"
        case entity = "Entity"
        case relationshipElement = "RelationshipElement"
        case annotatedRelationshipElement = "AnnotatedRelationshipElement"
        case operation = "Operation"
        case capability = "Capability"
        case basicEventElement = "BasicEventElement"
    }

    private enum CodingKeys: String, CodingKey {
        case modelType
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let modelType = try container.decode(ModelType.self, forKey: .modelType)

        switch modelType {
        case .property:
            self = .property(try Property(from: decoder))
        case .multiLanguageProperty:
            self = .multiLanguageProperty(try MultiLanguageProperty(from: decoder))
        case .submodelElementCollection:
            self = .submodelElementCollection(try SubmodelElementCollection(from: decoder))
        case .submodelElementList:
            self = .submodelElementList(try SubmodelElementList(from: decoder))
        case .file:
            self = .file(try AASFile(from: decoder))
        case .blob:
            self = .blob(try Blob(from: decoder))
        case .referenceElement:
            self = .referenceElement(try ReferenceElement(from: decoder))
        case .range:
            self = .range(try RangeElement(from: decoder))
        case .entity:
            self = .entity(try Entity(from: decoder))
        case .relationshipElement:
            self = .relationshipElement(try RelationshipElement(from: decoder))
        case .annotatedRelationshipElement:
            self = .annotatedRelationshipElement(try AnnotatedRelationshipElement(from: decoder))
        case .operation:
            self = .operation(try Operation(from: decoder))
        case .capability:
            self = .capability(try Capability(from: decoder))
        case .basicEventElement:
            self = .basicEventElement(try BasicEventElement(from: decoder))
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .property(let value):
            try value.encode(to: encoder)
        case .multiLanguageProperty(let value):
            try value.encode(to: encoder)
        case .submodelElementCollection(let value):
            try value.encode(to: encoder)
        case .submodelElementList(let value):
            try value.encode(to: encoder)
        case .file(let value):
            try value.encode(to: encoder)
        case .blob(let value):
            try value.encode(to: encoder)
        case .referenceElement(let value):
            try value.encode(to: encoder)
        case .range(let value):
            try value.encode(to: encoder)
        case .entity(let value):
            try value.encode(to: encoder)
        case .relationshipElement(let value):
            try value.encode(to: encoder)
        case .annotatedRelationshipElement(let value):
            try value.encode(to: encoder)
        case .operation(let value):
            try value.encode(to: encoder)
        case .capability(let value):
            try value.encode(to: encoder)
        case .basicEventElement(let value):
            try value.encode(to: encoder)
        }
    }

    /// Get the idShort of any element type.
    public var idShort: String {
        switch self {
        case .property(let p): return p.idShort
        case .multiLanguageProperty(let p): return p.idShort
        case .submodelElementCollection(let p): return p.idShort
        case .submodelElementList(let p): return p.idShort
        case .file(let p): return p.idShort
        case .blob(let p): return p.idShort
        case .referenceElement(let p): return p.idShort
        case .range(let p): return p.idShort
        case .entity(let p): return p.idShort
        case .relationshipElement(let p): return p.idShort
        case .annotatedRelationshipElement(let p): return p.idShort
        case .operation(let p): return p.idShort
        case .capability(let p): return p.idShort
        case .basicEventElement(let p): return p.idShort
        }
    }

    /// Get the semantic ID of any element type.
    public var semanticId: Reference? {
        switch self {
        case .property(let p): return p.semanticId
        case .multiLanguageProperty(let p): return p.semanticId
        case .submodelElementCollection(let p): return p.semanticId
        case .submodelElementList(let p): return p.semanticId
        case .file(let p): return p.semanticId
        case .blob(let p): return p.semanticId
        case .referenceElement(let p): return p.semanticId
        case .range(let p): return p.semanticId
        case .entity(let p): return p.semanticId
        case .relationshipElement(let p): return p.semanticId
        case .annotatedRelationshipElement(let p): return p.semanticId
        case .operation(let p): return p.semanticId
        case .capability(let p): return p.semanticId
        case .basicEventElement(let p): return p.semanticId
        }
    }
}

// MARK: - Property

/// A single-value property element.
public struct Property: Codable, Sendable, Hashable {
    public let modelType: String
    public let idShort: String
    public let semanticId: Reference?
    public let supplementalSemanticIds: [Reference]?
    public let qualifiers: [Qualifier]?
    public let category: String?
    public let description: [LangString]?
    public let displayName: [LangString]?
    public let valueType: DataTypeDefXsd
    public let value: String?
    public let valueId: Reference?

    public init(
        idShort: String,
        valueType: DataTypeDefXsd,
        value: String? = nil,
        semanticId: Reference? = nil,
        supplementalSemanticIds: [Reference]? = nil,
        qualifiers: [Qualifier]? = nil,
        category: String? = nil,
        description: [LangString]? = nil,
        displayName: [LangString]? = nil,
        valueId: Reference? = nil
    ) {
        self.modelType = "Property"
        self.idShort = idShort
        self.valueType = valueType
        self.value = value
        self.semanticId = semanticId
        self.supplementalSemanticIds = supplementalSemanticIds
        self.qualifiers = qualifiers
        self.category = category
        self.description = description
        self.displayName = displayName
        self.valueId = valueId
    }
}

// MARK: - MultiLanguageProperty

/// A property with values in multiple languages.
public struct MultiLanguageProperty: Codable, Sendable, Hashable {
    public let modelType: String
    public let idShort: String
    public let semanticId: Reference?
    public let supplementalSemanticIds: [Reference]?
    public let qualifiers: [Qualifier]?
    public let category: String?
    public let description: [LangString]?
    public let displayName: [LangString]?
    public let value: [LangString]?
    public let valueId: Reference?

    public init(
        idShort: String,
        value: [LangString]? = nil,
        semanticId: Reference? = nil,
        supplementalSemanticIds: [Reference]? = nil,
        qualifiers: [Qualifier]? = nil,
        category: String? = nil,
        description: [LangString]? = nil,
        displayName: [LangString]? = nil,
        valueId: Reference? = nil
    ) {
        self.modelType = "MultiLanguageProperty"
        self.idShort = idShort
        self.value = value
        self.semanticId = semanticId
        self.supplementalSemanticIds = supplementalSemanticIds
        self.qualifiers = qualifiers
        self.category = category
        self.description = description
        self.displayName = displayName
        self.valueId = valueId
    }
}

// MARK: - SubmodelElementCollection

/// A collection of nested submodel elements.
public struct SubmodelElementCollection: Codable, Sendable, Hashable {
    public let modelType: String
    public let idShort: String
    public let semanticId: Reference?
    public let supplementalSemanticIds: [Reference]?
    public let qualifiers: [Qualifier]?
    public let category: String?
    public let description: [LangString]?
    public let displayName: [LangString]?
    public let value: [SubmodelElement]?

    public init(
        idShort: String,
        value: [SubmodelElement]? = nil,
        semanticId: Reference? = nil,
        supplementalSemanticIds: [Reference]? = nil,
        qualifiers: [Qualifier]? = nil,
        category: String? = nil,
        description: [LangString]? = nil,
        displayName: [LangString]? = nil
    ) {
        self.modelType = "SubmodelElementCollection"
        self.idShort = idShort
        self.value = value
        self.semanticId = semanticId
        self.supplementalSemanticIds = supplementalSemanticIds
        self.qualifiers = qualifiers
        self.category = category
        self.description = description
        self.displayName = displayName
    }

    /// Find a nested element by idShort.
    public func element(named idShort: String) -> SubmodelElement? {
        value?.first { $0.idShort == idShort }
    }
}

// MARK: - SubmodelElementList

/// An ordered list of submodel elements of the same type.
public struct SubmodelElementList: Codable, Sendable, Hashable {
    public let modelType: String
    public let idShort: String
    public let semanticId: Reference?
    public let supplementalSemanticIds: [Reference]?
    public let qualifiers: [Qualifier]?
    public let category: String?
    public let description: [LangString]?
    public let displayName: [LangString]?
    public let orderRelevant: Bool?
    public let semanticIdListElement: Reference?
    public let typeValueListElement: AasSubmodelElements
    public let valueTypeListElement: DataTypeDefXsd?
    public let value: [SubmodelElement]?

    public init(
        idShort: String,
        typeValueListElement: AasSubmodelElements,
        value: [SubmodelElement]? = nil,
        orderRelevant: Bool? = true,
        valueTypeListElement: DataTypeDefXsd? = nil,
        semanticId: Reference? = nil,
        semanticIdListElement: Reference? = nil,
        supplementalSemanticIds: [Reference]? = nil,
        qualifiers: [Qualifier]? = nil,
        category: String? = nil,
        description: [LangString]? = nil,
        displayName: [LangString]? = nil
    ) {
        self.modelType = "SubmodelElementList"
        self.idShort = idShort
        self.typeValueListElement = typeValueListElement
        self.value = value
        self.orderRelevant = orderRelevant
        self.valueTypeListElement = valueTypeListElement
        self.semanticId = semanticId
        self.semanticIdListElement = semanticIdListElement
        self.supplementalSemanticIds = supplementalSemanticIds
        self.qualifiers = qualifiers
        self.category = category
        self.description = description
        self.displayName = displayName
    }
}

// MARK: - File

/// A file element with content type and path/URL.
public struct AASFile: Codable, Sendable, Hashable {
    public let modelType: String
    public let idShort: String
    public let semanticId: Reference?
    public let supplementalSemanticIds: [Reference]?
    public let qualifiers: [Qualifier]?
    public let category: String?
    public let description: [LangString]?
    public let displayName: [LangString]?
    public let contentType: String
    public let value: String?

    public init(
        idShort: String,
        contentType: String,
        value: String? = nil,
        semanticId: Reference? = nil,
        supplementalSemanticIds: [Reference]? = nil,
        qualifiers: [Qualifier]? = nil,
        category: String? = nil,
        description: [LangString]? = nil,
        displayName: [LangString]? = nil
    ) {
        self.modelType = "File"
        self.idShort = idShort
        self.contentType = contentType
        self.value = value
        self.semanticId = semanticId
        self.supplementalSemanticIds = supplementalSemanticIds
        self.qualifiers = qualifiers
        self.category = category
        self.description = description
        self.displayName = displayName
    }
}

// MARK: - Blob

/// A binary large object element.
public struct Blob: Codable, Sendable, Hashable {
    public let modelType: String
    public let idShort: String
    public let semanticId: Reference?
    public let supplementalSemanticIds: [Reference]?
    public let qualifiers: [Qualifier]?
    public let category: String?
    public let description: [LangString]?
    public let displayName: [LangString]?
    public let contentType: String
    public let value: String? // Base64-encoded

    public init(
        idShort: String,
        contentType: String,
        value: String? = nil,
        semanticId: Reference? = nil,
        supplementalSemanticIds: [Reference]? = nil,
        qualifiers: [Qualifier]? = nil,
        category: String? = nil,
        description: [LangString]? = nil,
        displayName: [LangString]? = nil
    ) {
        self.modelType = "Blob"
        self.idShort = idShort
        self.contentType = contentType
        self.value = value
        self.semanticId = semanticId
        self.supplementalSemanticIds = supplementalSemanticIds
        self.qualifiers = qualifiers
        self.category = category
        self.description = description
        self.displayName = displayName
    }

    /// Decode the Base64-encoded value to Data.
    public var decodedValue: Data? {
        guard let value = value else { return nil }
        return Data(base64Encoded: value)
    }
}

// MARK: - ReferenceElement

/// An element that references another element.
public struct ReferenceElement: Codable, Sendable, Hashable {
    public let modelType: String
    public let idShort: String
    public let semanticId: Reference?
    public let supplementalSemanticIds: [Reference]?
    public let qualifiers: [Qualifier]?
    public let category: String?
    public let description: [LangString]?
    public let displayName: [LangString]?
    public let value: Reference?

    public init(
        idShort: String,
        value: Reference? = nil,
        semanticId: Reference? = nil,
        supplementalSemanticIds: [Reference]? = nil,
        qualifiers: [Qualifier]? = nil,
        category: String? = nil,
        description: [LangString]? = nil,
        displayName: [LangString]? = nil
    ) {
        self.modelType = "ReferenceElement"
        self.idShort = idShort
        self.value = value
        self.semanticId = semanticId
        self.supplementalSemanticIds = supplementalSemanticIds
        self.qualifiers = qualifiers
        self.category = category
        self.description = description
        self.displayName = displayName
    }
}

// MARK: - Range

/// A range element with min and max values.
public struct RangeElement: Codable, Sendable, Hashable {
    public let modelType: String
    public let idShort: String
    public let semanticId: Reference?
    public let supplementalSemanticIds: [Reference]?
    public let qualifiers: [Qualifier]?
    public let category: String?
    public let description: [LangString]?
    public let displayName: [LangString]?
    public let valueType: DataTypeDefXsd
    public let min: String?
    public let max: String?

    public init(
        idShort: String,
        valueType: DataTypeDefXsd,
        min: String? = nil,
        max: String? = nil,
        semanticId: Reference? = nil,
        supplementalSemanticIds: [Reference]? = nil,
        qualifiers: [Qualifier]? = nil,
        category: String? = nil,
        description: [LangString]? = nil,
        displayName: [LangString]? = nil
    ) {
        self.modelType = "Range"
        self.idShort = idShort
        self.valueType = valueType
        self.min = min
        self.max = max
        self.semanticId = semanticId
        self.supplementalSemanticIds = supplementalSemanticIds
        self.qualifiers = qualifiers
        self.category = category
        self.description = description
        self.displayName = displayName
    }
}

// MARK: - Entity

/// An entity element representing a co-managed or self-managed entity.
public struct Entity: Codable, Sendable, Hashable {
    public let modelType: String
    public let idShort: String
    public let semanticId: Reference?
    public let supplementalSemanticIds: [Reference]?
    public let qualifiers: [Qualifier]?
    public let category: String?
    public let description: [LangString]?
    public let displayName: [LangString]?
    public let entityType: EntityType
    public let globalAssetId: String?
    public let specificAssetIds: [SpecificAssetId]?
    public let statements: [SubmodelElement]?

    public init(
        idShort: String,
        entityType: EntityType,
        globalAssetId: String? = nil,
        specificAssetIds: [SpecificAssetId]? = nil,
        statements: [SubmodelElement]? = nil,
        semanticId: Reference? = nil,
        supplementalSemanticIds: [Reference]? = nil,
        qualifiers: [Qualifier]? = nil,
        category: String? = nil,
        description: [LangString]? = nil,
        displayName: [LangString]? = nil
    ) {
        self.modelType = "Entity"
        self.idShort = idShort
        self.entityType = entityType
        self.globalAssetId = globalAssetId
        self.specificAssetIds = specificAssetIds
        self.statements = statements
        self.semanticId = semanticId
        self.supplementalSemanticIds = supplementalSemanticIds
        self.qualifiers = qualifiers
        self.category = category
        self.description = description
        self.displayName = displayName
    }
}

/// Entity type enumeration.
public enum EntityType: String, Codable, Sendable {
    case coManagedEntity = "CoManagedEntity"
    case selfManagedEntity = "SelfManagedEntity"
}

// MARK: - RelationshipElement

/// A relationship between two referable elements.
public struct RelationshipElement: Codable, Sendable, Hashable {
    public let modelType: String
    public let idShort: String
    public let semanticId: Reference?
    public let supplementalSemanticIds: [Reference]?
    public let qualifiers: [Qualifier]?
    public let category: String?
    public let description: [LangString]?
    public let displayName: [LangString]?
    public let first: Reference
    public let second: Reference

    public init(
        idShort: String,
        first: Reference,
        second: Reference,
        semanticId: Reference? = nil,
        supplementalSemanticIds: [Reference]? = nil,
        qualifiers: [Qualifier]? = nil,
        category: String? = nil,
        description: [LangString]? = nil,
        displayName: [LangString]? = nil
    ) {
        self.modelType = "RelationshipElement"
        self.idShort = idShort
        self.first = first
        self.second = second
        self.semanticId = semanticId
        self.supplementalSemanticIds = supplementalSemanticIds
        self.qualifiers = qualifiers
        self.category = category
        self.description = description
        self.displayName = displayName
    }
}

// MARK: - AnnotatedRelationshipElement

/// A relationship with additional annotations.
public struct AnnotatedRelationshipElement: Codable, Sendable, Hashable {
    public let modelType: String
    public let idShort: String
    public let semanticId: Reference?
    public let supplementalSemanticIds: [Reference]?
    public let qualifiers: [Qualifier]?
    public let category: String?
    public let description: [LangString]?
    public let displayName: [LangString]?
    public let first: Reference
    public let second: Reference
    public let annotations: [SubmodelElement]?

    public init(
        idShort: String,
        first: Reference,
        second: Reference,
        annotations: [SubmodelElement]? = nil,
        semanticId: Reference? = nil,
        supplementalSemanticIds: [Reference]? = nil,
        qualifiers: [Qualifier]? = nil,
        category: String? = nil,
        description: [LangString]? = nil,
        displayName: [LangString]? = nil
    ) {
        self.modelType = "AnnotatedRelationshipElement"
        self.idShort = idShort
        self.first = first
        self.second = second
        self.annotations = annotations
        self.semanticId = semanticId
        self.supplementalSemanticIds = supplementalSemanticIds
        self.qualifiers = qualifiers
        self.category = category
        self.description = description
        self.displayName = displayName
    }
}

// MARK: - Operation

/// An operation element representing an executable function.
public struct Operation: Codable, Sendable, Hashable {
    public let modelType: String
    public let idShort: String
    public let semanticId: Reference?
    public let supplementalSemanticIds: [Reference]?
    public let qualifiers: [Qualifier]?
    public let category: String?
    public let description: [LangString]?
    public let displayName: [LangString]?
    public let inputVariables: [OperationVariable]?
    public let outputVariables: [OperationVariable]?
    public let inoutputVariables: [OperationVariable]?

    public init(
        idShort: String,
        inputVariables: [OperationVariable]? = nil,
        outputVariables: [OperationVariable]? = nil,
        inoutputVariables: [OperationVariable]? = nil,
        semanticId: Reference? = nil,
        supplementalSemanticIds: [Reference]? = nil,
        qualifiers: [Qualifier]? = nil,
        category: String? = nil,
        description: [LangString]? = nil,
        displayName: [LangString]? = nil
    ) {
        self.modelType = "Operation"
        self.idShort = idShort
        self.inputVariables = inputVariables
        self.outputVariables = outputVariables
        self.inoutputVariables = inoutputVariables
        self.semanticId = semanticId
        self.supplementalSemanticIds = supplementalSemanticIds
        self.qualifiers = qualifiers
        self.category = category
        self.description = description
        self.displayName = displayName
    }
}

/// Variable definition for operations.
public struct OperationVariable: Codable, Sendable, Hashable {
    public let value: SubmodelElement

    public init(value: SubmodelElement) {
        self.value = value
    }
}

// MARK: - Capability

/// A capability element.
public struct Capability: Codable, Sendable, Hashable {
    public let modelType: String
    public let idShort: String
    public let semanticId: Reference?
    public let supplementalSemanticIds: [Reference]?
    public let qualifiers: [Qualifier]?
    public let category: String?
    public let description: [LangString]?
    public let displayName: [LangString]?

    public init(
        idShort: String,
        semanticId: Reference? = nil,
        supplementalSemanticIds: [Reference]? = nil,
        qualifiers: [Qualifier]? = nil,
        category: String? = nil,
        description: [LangString]? = nil,
        displayName: [LangString]? = nil
    ) {
        self.modelType = "Capability"
        self.idShort = idShort
        self.semanticId = semanticId
        self.supplementalSemanticIds = supplementalSemanticIds
        self.qualifiers = qualifiers
        self.category = category
        self.description = description
        self.displayName = displayName
    }
}

// MARK: - BasicEventElement

/// A basic event element.
public struct BasicEventElement: Codable, Sendable, Hashable {
    public let modelType: String
    public let idShort: String
    public let semanticId: Reference?
    public let supplementalSemanticIds: [Reference]?
    public let qualifiers: [Qualifier]?
    public let category: String?
    public let description: [LangString]?
    public let displayName: [LangString]?
    public let observed: Reference
    public let direction: EventDirection
    public let state: EventState
    public let messageTopic: String?
    public let messageBroker: Reference?
    public let lastUpdate: String?
    public let minInterval: String?
    public let maxInterval: String?

    public init(
        idShort: String,
        observed: Reference,
        direction: EventDirection,
        state: EventState,
        messageTopic: String? = nil,
        messageBroker: Reference? = nil,
        lastUpdate: String? = nil,
        minInterval: String? = nil,
        maxInterval: String? = nil,
        semanticId: Reference? = nil,
        supplementalSemanticIds: [Reference]? = nil,
        qualifiers: [Qualifier]? = nil,
        category: String? = nil,
        description: [LangString]? = nil,
        displayName: [LangString]? = nil
    ) {
        self.modelType = "BasicEventElement"
        self.idShort = idShort
        self.observed = observed
        self.direction = direction
        self.state = state
        self.messageTopic = messageTopic
        self.messageBroker = messageBroker
        self.lastUpdate = lastUpdate
        self.minInterval = minInterval
        self.maxInterval = maxInterval
        self.semanticId = semanticId
        self.supplementalSemanticIds = supplementalSemanticIds
        self.qualifiers = qualifiers
        self.category = category
        self.description = description
        self.displayName = displayName
    }
}

/// Event direction enumeration.
public enum EventDirection: String, Codable, Sendable {
    case input
    case output
}

/// Event state enumeration.
public enum EventState: String, Codable, Sendable {
    case on
    case off
}

// MARK: - Qualifier

/// Qualifier for submodel elements.
public struct Qualifier: Codable, Sendable, Hashable {
    public let type: String
    public let valueType: DataTypeDefXsd
    public let value: String?
    public let valueId: Reference?
    public let kind: QualifierKind?
    public let semanticId: Reference?

    public init(
        type: String,
        valueType: DataTypeDefXsd,
        value: String? = nil,
        valueId: Reference? = nil,
        kind: QualifierKind? = nil,
        semanticId: Reference? = nil
    ) {
        self.type = type
        self.valueType = valueType
        self.value = value
        self.valueId = valueId
        self.kind = kind
        self.semanticId = semanticId
    }
}

/// Qualifier kind enumeration.
public enum QualifierKind: String, Codable, Sendable {
    case valueQualifier = "ValueQualifier"
    case conceptQualifier = "ConceptQualifier"
    case templateQualifier = "TemplateQualifier"
}

// MARK: - AAS Submodel Elements Enum

/// Enumeration of all submodel element types (for SubmodelElementList).
public enum AasSubmodelElements: String, Codable, Sendable {
    case annotatedRelationshipElement = "AnnotatedRelationshipElement"
    case basicEventElement = "BasicEventElement"
    case blob = "Blob"
    case capability = "Capability"
    case dataElement = "DataElement"
    case entity = "Entity"
    case eventElement = "EventElement"
    case file = "File"
    case multiLanguageProperty = "MultiLanguageProperty"
    case operation = "Operation"
    case property = "Property"
    case range = "Range"
    case referenceElement = "ReferenceElement"
    case relationshipElement = "RelationshipElement"
    case submodelElement = "SubmodelElement"
    case submodelElementCollection = "SubmodelElementCollection"
    case submodelElementList = "SubmodelElementList"
}

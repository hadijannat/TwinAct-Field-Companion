//
//  Submodel.swift
//  TwinAct Field Companion
//
//  Complete Submodel model for AAS API v3.
//

import Foundation

// MARK: - Submodel

/// Complete submodel with all elements populated.
public struct Submodel: Codable, Sendable, Identifiable, Hashable {
    /// Unique identifier (IRI/URN) for the submodel
    public let id: String

    /// Short, human-readable name
    public let idShort: String?

    /// Semantic reference linking to IDTA template or standard
    public let semanticId: Reference?

    /// Supplemental semantic IDs
    public let supplementalSemanticId: [Reference]?

    /// Multi-language descriptions
    public let description: [LangString]?

    /// Multi-language display names
    public let displayName: [LangString]?

    /// Administrative information
    public let administration: AdministrativeInformation?

    /// Kind of model (Instance or Template)
    public let kind: ModelKind?

    /// Qualifiers
    public let qualifiers: [Qualifier]?

    /// Submodel elements (the actual data)
    public let submodelElements: [SubmodelElement]?

    public init(
        id: String,
        idShort: String? = nil,
        semanticId: Reference? = nil,
        supplementalSemanticId: [Reference]? = nil,
        description: [LangString]? = nil,
        displayName: [LangString]? = nil,
        administration: AdministrativeInformation? = nil,
        kind: ModelKind? = nil,
        qualifiers: [Qualifier]? = nil,
        submodelElements: [SubmodelElement]? = nil
    ) {
        self.id = id
        self.idShort = idShort
        self.semanticId = semanticId
        self.supplementalSemanticId = supplementalSemanticId
        self.description = description
        self.displayName = displayName
        self.administration = administration
        self.kind = kind
        self.qualifiers = qualifiers
        self.submodelElements = submodelElements
    }

    /// Find an element by idShort path (e.g., "ManufacturerName" or "ContactInformation/Phone").
    public func element(at path: String) -> SubmodelElement? {
        let pathComponents = path.split(separator: "/").map(String.init)
        return findElement(in: submodelElements, path: pathComponents)
    }

    private func findElement(in elements: [SubmodelElement]?, path: [String]) -> SubmodelElement? {
        guard !path.isEmpty, let elements = elements else { return nil }

        let currentIdShort = path[0]
        let remainingPath = Array(path.dropFirst())

        guard let element = elements.first(where: { $0.idShort == currentIdShort }) else {
            return nil
        }

        if remainingPath.isEmpty {
            return element
        }

        // Recurse into collections/lists
        switch element {
        case .submodelElementCollection(let collection):
            return findElement(in: collection.value, path: remainingPath)
        case .submodelElementList(let list):
            return findElement(in: list.value, path: remainingPath)
        case .entity(let entity):
            return findElement(in: entity.statements, path: remainingPath)
        default:
            return nil
        }
    }

    /// Get all elements as a flat list with their paths.
    public func flattenedElements() -> [(path: String, element: SubmodelElement)] {
        var result: [(String, SubmodelElement)] = []
        flattenElements(submodelElements, prefix: "", into: &result)
        return result
    }

    private func flattenElements(_ elements: [SubmodelElement]?, prefix: String, into result: inout [(String, SubmodelElement)]) {
        guard let elements = elements else { return }

        for element in elements {
            let currentPath = prefix.isEmpty ? element.idShort : "\(prefix)/\(element.idShort)"
            result.append((currentPath, element))

            // Recurse into nested elements
            switch element {
            case .submodelElementCollection(let collection):
                flattenElements(collection.value, prefix: currentPath, into: &result)
            case .submodelElementList(let list):
                flattenElements(list.value, prefix: currentPath, into: &result)
            case .entity(let entity):
                flattenElements(entity.statements, prefix: currentPath, into: &result)
            default:
                break
            }
        }
    }
}

// MARK: - Model Kind

/// Kind of model (Template vs Instance).
public enum ModelKind: String, Codable, Sendable {
    case template = "Template"
    case instance = "Instance"
}

// MARK: - Asset Administration Shell

/// Complete Asset Administration Shell model.
public struct AssetAdministrationShell: Codable, Sendable, Identifiable, Hashable {
    /// Unique identifier (IRI/URN)
    public let id: String

    /// Short, human-readable name
    public let idShort: String?

    /// Multi-language descriptions
    public let description: [LangString]?

    /// Multi-language display names
    public let displayName: [LangString]?

    /// Administrative information
    public let administration: AdministrativeInformation?

    /// Asset information
    public let assetInformation: AssetInformation

    /// References to submodels
    public let submodels: [Reference]?

    /// Derived from reference
    public let derivedFrom: Reference?

    public init(
        id: String,
        idShort: String? = nil,
        description: [LangString]? = nil,
        displayName: [LangString]? = nil,
        administration: AdministrativeInformation? = nil,
        assetInformation: AssetInformation,
        submodels: [Reference]? = nil,
        derivedFrom: Reference? = nil
    ) {
        self.id = id
        self.idShort = idShort
        self.description = description
        self.displayName = displayName
        self.administration = administration
        self.assetInformation = assetInformation
        self.submodels = submodels
        self.derivedFrom = derivedFrom
    }
}

// MARK: - Asset Information

/// Information about the asset represented by an AAS.
public struct AssetInformation: Codable, Sendable, Hashable {
    /// Kind of asset
    public let assetKind: AssetKind

    /// Global asset identifier
    public let globalAssetId: String?

    /// Specific asset identifiers
    public let specificAssetIds: [SpecificAssetId]?

    /// Asset type
    public let assetType: String?

    /// Default thumbnail
    public let defaultThumbnail: Resource?

    public init(
        assetKind: AssetKind,
        globalAssetId: String? = nil,
        specificAssetIds: [SpecificAssetId]? = nil,
        assetType: String? = nil,
        defaultThumbnail: Resource? = nil
    ) {
        self.assetKind = assetKind
        self.globalAssetId = globalAssetId
        self.specificAssetIds = specificAssetIds
        self.assetType = assetType
        self.defaultThumbnail = defaultThumbnail
    }
}

// MARK: - Resource

/// Resource reference (e.g., for thumbnails).
public struct Resource: Codable, Sendable, Hashable {
    /// Path or URL to the resource
    public let path: String

    /// Content type (MIME type)
    public let contentType: String?

    public init(path: String, contentType: String? = nil) {
        self.path = path
        self.contentType = contentType
    }
}

// MARK: - Concept Description

/// Concept description for semantic definitions.
public struct ConceptDescription: Codable, Sendable, Identifiable, Hashable {
    /// Unique identifier
    public let id: String

    /// Short, human-readable name
    public let idShort: String?

    /// Multi-language descriptions
    public let description: [LangString]?

    /// Multi-language display names
    public let displayName: [LangString]?

    /// Administrative information
    public let administration: AdministrativeInformation?

    /// Is case of references
    public let isCaseOf: [Reference]?

    /// Embedded data specification
    public let embeddedDataSpecifications: [EmbeddedDataSpecification]?

    public init(
        id: String,
        idShort: String? = nil,
        description: [LangString]? = nil,
        displayName: [LangString]? = nil,
        administration: AdministrativeInformation? = nil,
        isCaseOf: [Reference]? = nil,
        embeddedDataSpecifications: [EmbeddedDataSpecification]? = nil
    ) {
        self.id = id
        self.idShort = idShort
        self.description = description
        self.displayName = displayName
        self.administration = administration
        self.isCaseOf = isCaseOf
        self.embeddedDataSpecifications = embeddedDataSpecifications
    }
}

// MARK: - Embedded Data Specification

/// Embedded data specification for concept descriptions.
public struct EmbeddedDataSpecification: Codable, Sendable, Hashable {
    /// Reference to the data specification template
    public let dataSpecification: Reference

    /// Content of the data specification
    public let dataSpecificationContent: DataSpecificationContent

    public init(dataSpecification: Reference, dataSpecificationContent: DataSpecificationContent) {
        self.dataSpecification = dataSpecification
        self.dataSpecificationContent = dataSpecificationContent
    }
}

/// Data specification content (simplified - IEC 61360 content).
public struct DataSpecificationContent: Codable, Sendable, Hashable {
    public let modelType: String?
    public let preferredName: [LangString]?
    public let shortName: [LangString]?
    public let unit: String?
    public let unitId: Reference?
    public let sourceOfDefinition: String?
    public let symbol: String?
    public let dataType: String?
    public let definition: [LangString]?
    public let valueFormat: String?
    public let valueList: ValueList?
    public let value: String?
    public let levelType: LevelType?

    public init(
        modelType: String? = nil,
        preferredName: [LangString]? = nil,
        shortName: [LangString]? = nil,
        unit: String? = nil,
        unitId: Reference? = nil,
        sourceOfDefinition: String? = nil,
        symbol: String? = nil,
        dataType: String? = nil,
        definition: [LangString]? = nil,
        valueFormat: String? = nil,
        valueList: ValueList? = nil,
        value: String? = nil,
        levelType: LevelType? = nil
    ) {
        self.modelType = modelType
        self.preferredName = preferredName
        self.shortName = shortName
        self.unit = unit
        self.unitId = unitId
        self.sourceOfDefinition = sourceOfDefinition
        self.symbol = symbol
        self.dataType = dataType
        self.definition = definition
        self.valueFormat = valueFormat
        self.valueList = valueList
        self.value = value
        self.levelType = levelType
    }
}

/// Value list for data specifications.
public struct ValueList: Codable, Sendable, Hashable {
    public let valueReferencePairs: [ValueReferencePair]?

    public init(valueReferencePairs: [ValueReferencePair]? = nil) {
        self.valueReferencePairs = valueReferencePairs
    }
}

/// Value reference pair.
public struct ValueReferencePair: Codable, Sendable, Hashable {
    public let value: String
    public let valueId: Reference?

    public init(value: String, valueId: Reference? = nil) {
        self.value = value
        self.valueId = valueId
    }
}

/// Level type for data specifications.
public struct LevelType: Codable, Sendable, Hashable {
    public let min: Bool?
    public let nom: Bool?
    public let typ: Bool?
    public let max: Bool?

    public init(min: Bool? = nil, nom: Bool? = nil, typ: Bool? = nil, max: Bool? = nil) {
        self.min = min
        self.nom = nom
        self.typ = typ
        self.max = max
    }
}

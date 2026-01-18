//
//  SubmodelDescriptor.swift
//  TwinAct Field Companion
//
//  Submodel descriptor and reference models for AAS API v3.
//

import Foundation

// MARK: - Submodel Descriptor

/// Submodel descriptor from registry.
/// Contains metadata about a submodel and its access endpoints.
public struct SubmodelDescriptor: Codable, Sendable, Identifiable, Hashable {
    /// Unique identifier (IRI/URN) for the submodel
    public let id: String

    /// Short, human-readable name for the submodel
    public let idShort: String?

    /// Semantic reference linking to IDTA template or standard
    public let semanticId: Reference?

    /// Supplemental semantic IDs
    public let supplementalSemanticId: [Reference]?

    /// Multi-language descriptions
    public let description: [LangString]?

    /// Multi-language display names
    public let displayName: [LangString]?

    /// Endpoints where this submodel can be accessed
    public let endpoints: [Endpoint]?

    /// Administrative information
    public let administration: AdministrativeInformation?

    public init(
        id: String,
        idShort: String? = nil,
        semanticId: Reference? = nil,
        supplementalSemanticId: [Reference]? = nil,
        description: [LangString]? = nil,
        displayName: [LangString]? = nil,
        endpoints: [Endpoint]? = nil,
        administration: AdministrativeInformation? = nil
    ) {
        self.id = id
        self.idShort = idShort
        self.semanticId = semanticId
        self.supplementalSemanticId = supplementalSemanticId
        self.description = description
        self.displayName = displayName
        self.endpoints = endpoints
        self.administration = administration
    }
}

// MARK: - Reference

/// Reference to semantic definitions or other AAS elements.
public struct Reference: Codable, Sendable, Hashable {
    /// Type of reference
    public let type: ReferenceType

    /// Keys forming the reference path
    public let keys: [Key]

    /// Referred semantic ID (optional)
    public let referredSemanticId: Reference?

    public init(type: ReferenceType, keys: [Key], referredSemanticId: Reference? = nil) {
        self.type = type
        self.keys = keys
        self.referredSemanticId = referredSemanticId
    }

    /// Convenience initializer for a single global reference.
    public static func globalReference(_ value: String) -> Reference {
        Reference(
            type: .externalReference,
            keys: [Key(type: .globalReference, value: value)]
        )
    }

    /// Convenience initializer for a model reference.
    public static func modelReference(type: KeyType, value: String) -> Reference {
        Reference(
            type: .modelReference,
            keys: [Key(type: type, value: value)]
        )
    }
}

// MARK: - Reference Type

/// Types of references in AAS.
public enum ReferenceType: String, Codable, Sendable {
    /// Reference to external resources (IRIs, URNs)
    case externalReference = "ExternalReference"

    /// Reference to elements within the AAS model
    case modelReference = "ModelReference"
}

// MARK: - Key

/// Key element in a reference path.
public struct Key: Codable, Sendable, Hashable {
    /// Type of the key
    public let type: KeyType

    /// The actual value (IRI, URN, idShort path, etc.)
    public let value: String

    public init(type: KeyType, value: String) {
        self.type = type
        self.value = value
    }
}

// MARK: - Key Type

/// Types of keys used in references.
public enum KeyType: String, Codable, Sendable {
    // Identifiables
    case assetAdministrationShell = "AssetAdministrationShell"
    case conceptDescription = "ConceptDescription"
    case submodel = "Submodel"

    // Referables (submodel elements)
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

    // Global/Fragment references
    case globalReference = "GlobalReference"
    case fragmentReference = "FragmentReference"
}

// MARK: - Submodel Reference

/// A simplified reference specifically to a submodel.
public struct SubmodelReference: Codable, Sendable, Hashable {
    /// The full reference
    public let reference: Reference

    /// The submodel ID (convenience accessor)
    public var submodelId: String? {
        reference.keys.first(where: { $0.type == .submodel })?.value
    }

    public init(reference: Reference) {
        self.reference = reference
    }

    public init(submodelId: String) {
        self.reference = Reference(
            type: .modelReference,
            keys: [Key(type: .submodel, value: submodelId)]
        )
    }
}

// MARK: - Common Semantic IDs

/// Common IDTA submodel semantic IDs.
public enum IDTASemanticId {
    /// Digital Nameplate
    public static let digitalNameplate = "https://admin-shell.io/zvei/nameplate/2/0/Nameplate"

    /// Technical Data
    public static let technicalData = "https://admin-shell.io/ZVEI/TechnicalData/Submodel/1/2"

    /// Documentation
    public static let documentation = "https://admin-shell.io/ZVEI/HandoverDocumentation/1/2/Submodel"

    /// Contact Information
    public static let contactInformation = "https://admin-shell.io/zvei/nameplate/1/0/ContactInformation"

    /// Carbon Footprint (PCF)
    public static let carbonFootprint = "https://admin-shell.io/idta/CarbonFootprint/ProductCarbonFootprint/0/9"

    /// Hierarchical Structures
    public static let hierarchicalStructures = "https://admin-shell.io/idta/HierarchicalStructures/1/0/Submodel"

    /// Time Series Data
    public static let timeSeries = "https://admin-shell.io/idta/TimeSeries/1/0/Submodel"

    /// Asset Interfaces Description
    public static let assetInterfacesDescription = "https://admin-shell.io/idta/AssetInterfacesDescription/1/0/Submodel"

    /// Capability Description
    public static let capabilityDescription = "https://admin-shell.io/idta/CapabilityDescription/1/0/Submodel"
}

//
//  AASDescriptor.swift
//  TwinAct Field Companion
//
//  Asset Administration Shell descriptor models for AAS API v3.
//  These models represent AAS descriptors returned from the registry.
//

import Foundation

// MARK: - AAS Descriptor

/// Asset Administration Shell descriptor from registry.
/// Contains metadata about an AAS and its access endpoints.
public struct AASDescriptor: Codable, Sendable, Identifiable, Hashable {
    /// Unique identifier (IRI/URN) for the AAS
    public let id: String

    /// Short, human-readable name for the AAS
    public let idShort: String?

    /// Kind of asset (Type, Instance, or NotApplicable)
    public let assetKind: AssetKind?

    /// Global reference to the asset this AAS represents
    public let globalAssetId: String?

    /// Additional asset identifiers (e.g., serial number, part number)
    public let specificAssetIds: [SpecificAssetId]?

    /// Multi-language descriptions
    public let description: [LangString]?

    /// Multi-language display names
    public let displayName: [LangString]?

    /// Endpoints where this AAS can be accessed
    public let endpoints: [Endpoint]?

    /// Administrative information
    public let administration: AdministrativeInformation?

    /// References to submodel descriptors
    public let submodelDescriptors: [SubmodelDescriptor]?

    public init(
        id: String,
        idShort: String? = nil,
        assetKind: AssetKind? = nil,
        globalAssetId: String? = nil,
        specificAssetIds: [SpecificAssetId]? = nil,
        description: [LangString]? = nil,
        displayName: [LangString]? = nil,
        endpoints: [Endpoint]? = nil,
        administration: AdministrativeInformation? = nil,
        submodelDescriptors: [SubmodelDescriptor]? = nil
    ) {
        self.id = id
        self.idShort = idShort
        self.assetKind = assetKind
        self.globalAssetId = globalAssetId
        self.specificAssetIds = specificAssetIds
        self.description = description
        self.displayName = displayName
        self.endpoints = endpoints
        self.administration = administration
        self.submodelDescriptors = submodelDescriptors
    }
}

// MARK: - Asset Kind

/// Defines the kind of asset represented by an AAS.
public enum AssetKind: String, Codable, Sendable, CaseIterable {
    /// A type/template asset (not a specific instance)
    case type = "Type"

    /// A specific instance of an asset
    case instance = "Instance"

    /// Asset kind is not applicable
    case notApplicable = "NotApplicable"
}

// MARK: - Specific Asset ID

/// Additional asset identifier with optional access control.
public struct SpecificAssetId: Codable, Sendable, Hashable {
    /// Name/key of the identifier (e.g., "serialNumber", "partNumber")
    public let name: String

    /// Value of the identifier
    public let value: String

    /// External subject that can access this identifier
    public let externalSubjectId: Reference?

    /// Semantic ID for the identifier type
    public let semanticId: Reference?

    public init(
        name: String,
        value: String,
        externalSubjectId: Reference? = nil,
        semanticId: Reference? = nil
    ) {
        self.name = name
        self.value = value
        self.externalSubjectId = externalSubjectId
        self.semanticId = semanticId
    }
}

// MARK: - Language String

/// Multi-language string with language tag.
public struct LangString: Codable, Sendable, Hashable {
    /// Language code (e.g., "en", "de", "fr")
    public let language: String

    /// Text content in the specified language
    public let text: String

    public init(language: String, text: String) {
        self.language = language
        self.text = text
    }
}

// MARK: - Endpoint

/// Access endpoint for an AAS or submodel.
public struct Endpoint: Codable, Sendable, Hashable {
    /// Protocol information (e.g., HTTP, MQTT)
    public let `interface`: String

    /// Protocol-specific endpoint information
    public let protocolInformation: ProtocolInformation

    public init(interface: String, protocolInformation: ProtocolInformation) {
        self.interface = interface
        self.protocolInformation = protocolInformation
    }

    private enum CodingKeys: String, CodingKey {
        case `interface`
        case protocolInformation
    }
}

// MARK: - Protocol Information

/// Protocol-specific endpoint details.
public struct ProtocolInformation: Codable, Sendable, Hashable {
    /// Base URL/address for the endpoint
    public let href: String

    /// Endpoint protocol (e.g., "HTTP", "HTTPS", "MQTT")
    public let endpointProtocol: String?

    /// Protocol version
    public let endpointProtocolVersion: [String]?

    /// Subprotocol (e.g., "OPC UA", "AAS")
    public let subprotocol: String?

    /// Subprotocol body
    public let subprotocolBody: String?

    /// Subprotocol body encoding
    public let subprotocolBodyEncoding: String?

    /// Security attributes
    public let securityAttributes: [SecurityAttribute]?

    public init(
        href: String,
        endpointProtocol: String? = nil,
        endpointProtocolVersion: [String]? = nil,
        subprotocol: String? = nil,
        subprotocolBody: String? = nil,
        subprotocolBodyEncoding: String? = nil,
        securityAttributes: [SecurityAttribute]? = nil
    ) {
        self.href = href
        self.endpointProtocol = endpointProtocol
        self.endpointProtocolVersion = endpointProtocolVersion
        self.subprotocol = subprotocol
        self.subprotocolBody = subprotocolBody
        self.subprotocolBodyEncoding = subprotocolBodyEncoding
        self.securityAttributes = securityAttributes
    }
}

// MARK: - Security Attribute

/// Security attribute for endpoint access.
public struct SecurityAttribute: Codable, Sendable, Hashable {
    /// Type of security (e.g., "NONE", "RFC_TLSA", "W3C_DID")
    public let type: SecurityAttributeType

    /// Security key
    public let key: String

    /// Security value
    public let value: String

    public init(type: SecurityAttributeType, key: String, value: String) {
        self.type = type
        self.key = key
        self.value = value
    }
}

/// Security attribute types per AAS specification.
public enum SecurityAttributeType: String, Codable, Sendable {
    case none = "NONE"
    case rfcTlsa = "RFC_TLSA"
    case w3cDid = "W3C_DID"
}

// MARK: - Administrative Information

/// Administrative metadata for AAS elements.
public struct AdministrativeInformation: Codable, Sendable, Hashable {
    /// Version of the element
    public let version: String?

    /// Revision of the element
    public let revision: String?

    /// Creator of the element
    public let creator: Reference?

    /// Template ID this element is based on
    public let templateId: String?

    public init(
        version: String? = nil,
        revision: String? = nil,
        creator: Reference? = nil,
        templateId: String? = nil
    ) {
        self.version = version
        self.revision = revision
        self.creator = creator
        self.templateId = templateId
    }
}

// MARK: - LangString Helpers

extension Array where Element == LangString {
    /// Get text for a specific language, or first available if not found.
    public func text(for language: String) -> String? {
        // Try exact match first
        if let match = first(where: { $0.language.lowercased() == language.lowercased() }) {
            return match.text
        }
        // Try prefix match (e.g., "en" matches "en-US")
        if let match = first(where: { $0.language.lowercased().hasPrefix(language.lowercased()) }) {
            return match.text
        }
        // Return first available
        return first?.text
    }

    /// Get English text, falling back to first available.
    public var englishText: String? {
        text(for: "en")
    }
}

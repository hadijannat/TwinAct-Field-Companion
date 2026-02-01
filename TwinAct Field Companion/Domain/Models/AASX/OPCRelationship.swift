//
//  OPCRelationship.swift
//  TwinAct Field Companion
//
//  OPC (Open Packaging Conventions) relationship parsing per ISO/IEC 29500-2.
//

import Foundation
import XMLCoder

// MARK: - OPC Relationships

/// Root element for OPC .rels files.
public struct OPCRelationships: Codable {
    public let relationships: [OPCRelationship]

    enum CodingKeys: String, CodingKey {
        case relationships = "Relationship"
    }

    public init(relationships: [OPCRelationship] = []) {
        self.relationships = relationships
    }
}

// MARK: - OPC Relationship

/// Single relationship entry in OPC package.
public struct OPCRelationship: Codable, Identifiable {
    /// Unique relationship ID
    public let id: String

    /// Relationship type URI
    public let type: String

    /// Target path within package
    public let target: String

    /// Target mode (Internal/External)
    public let targetMode: String?

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case type = "Type"
        case target = "Target"
        case targetMode = "TargetMode"
    }

    public init(id: String, type: String, target: String, targetMode: String? = nil) {
        self.id = id
        self.type = type
        self.target = target
        self.targetMode = targetMode
    }

    /// Whether this is an internal relationship
    public var isInternal: Bool {
        targetMode?.lowercased() != "external"
    }

    /// Normalized target path (removes leading /)
    public var normalizedTarget: String {
        if target.hasPrefix("/") {
            return String(target.dropFirst())
        }
        return target
    }
}

// MARK: - OPC Relationship Types

/// Known OPC relationship type URIs.
public enum OPCRelationshipType {
    /// Core properties relationship
    public static let coreProperties = "http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties"

    /// Thumbnail relationship
    public static let thumbnail = "http://schemas.openxmlformats.org/package/2006/relationships/metadata/thumbnail"

    /// AASX origin relationship
    public static let aasxOrigin = "http://www.admin-shell.io/aasx/relationships/aas-spec"

    /// AAS supplementary file
    public static let aasSupplementary = "http://www.admin-shell.io/aasx/relationships/aas-suppl"

    /// AASX spec relationship (alternative)
    public static let aasSpec = "http://admin-shell.io/aasx/relationships/aas-spec"
}

// MARK: - OPC Content Types

/// Content types XML root element.
public struct OPCContentTypes: Codable {
    public let defaults: [OPCDefault]?
    public let overrides: [OPCOverride]?

    enum CodingKeys: String, CodingKey {
        case defaults = "Default"
        case overrides = "Override"
    }

    public init(defaults: [OPCDefault]? = nil, overrides: [OPCOverride]? = nil) {
        self.defaults = defaults
        self.overrides = overrides
    }

    /// Get content type for a path
    public func contentType(for path: String) -> String? {
        // Check overrides first
        if let override = overrides?.first(where: { $0.partName == path || $0.partName == "/\(path)" }) {
            return override.contentType
        }

        // Fall back to extension default
        let ext = (path as NSString).pathExtension.lowercased()
        return defaults?.first(where: { $0.extension.lowercased() == ext })?.contentType
    }
}

/// Default content type by extension.
public struct OPCDefault: Codable {
    public let `extension`: String
    public let contentType: String

    enum CodingKeys: String, CodingKey {
        case `extension` = "Extension"
        case contentType = "ContentType"
    }
}

/// Override content type for specific path.
public struct OPCOverride: Codable {
    public let partName: String
    public let contentType: String

    enum CodingKeys: String, CodingKey {
        case partName = "PartName"
        case contentType = "ContentType"
    }
}

// MARK: - Relationship Parser

/// Parser for OPC relationship files.
public struct OPCRelationshipParser {

    /// Parse relationships from XML data
    public static func parse(data: Data) throws -> OPCRelationships {
        let decoder = XMLDecoder()
        decoder.shouldProcessNamespaces = true
        return try decoder.decode(OPCRelationships.self, from: data)
    }

    /// Parse content types from XML data
    public static func parseContentTypes(data: Data) throws -> OPCContentTypes {
        let decoder = XMLDecoder()
        decoder.shouldProcessNamespaces = true
        return try decoder.decode(OPCContentTypes.self, from: data)
    }

    /// Build relationship path for a given source path
    /// e.g., "aasx/aas.json" -> "aasx/_rels/aas.json.rels"
    public static func relsPath(for sourcePath: String) -> String {
        let directory = (sourcePath as NSString).deletingLastPathComponent
        let filename = (sourcePath as NSString).lastPathComponent

        if directory.isEmpty {
            return "_rels/\(filename).rels"
        } else {
            return "\(directory)/_rels/\(filename).rels"
        }
    }

    /// Root relationships path
    public static let rootRelsPath = "_rels/.rels"
}

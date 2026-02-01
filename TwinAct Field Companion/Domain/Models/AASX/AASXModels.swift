//
//  AASXModels.swift
//  TwinAct Field Companion
//
//  Data structures for AASX package parsing results.
//

import Foundation

// MARK: - AASX Parse Result

/// Result of parsing an AASX package.
public struct AASXParseResult: Sendable {
    /// Asset identifier extracted from the package
    public let assetId: String

    /// Metadata from the AAS manifest
    public let metadata: AASXMetadata

    /// Extracted content files with local URLs
    public let extractedContent: ExtractedContent

    /// Non-fatal warnings encountered during parsing
    public let warnings: [AASXWarning]

    public init(
        assetId: String,
        metadata: AASXMetadata,
        extractedContent: ExtractedContent,
        warnings: [AASXWarning] = []
    ) {
        self.assetId = assetId
        self.metadata = metadata
        self.extractedContent = extractedContent
        self.warnings = warnings
    }
}

// MARK: - AASX Metadata

/// Metadata extracted from AASX manifest.
public struct AASXMetadata: Sendable, Codable {
    /// Asset name/designation
    public let assetName: String?

    /// Manufacturer name
    public let manufacturerName: String?

    /// Serial number
    public let serialNumber: String?

    /// Model/product designation
    public let productDesignation: String?

    /// Source AASX filename
    public let sourceFilename: String?

    /// Parse timestamp
    public let parsedAt: Date

    public init(
        assetName: String? = nil,
        manufacturerName: String? = nil,
        serialNumber: String? = nil,
        productDesignation: String? = nil,
        sourceFilename: String? = nil,
        parsedAt: Date = Date()
    ) {
        self.assetName = assetName
        self.manufacturerName = manufacturerName
        self.serialNumber = serialNumber
        self.productDesignation = productDesignation
        self.sourceFilename = sourceFilename
        self.parsedAt = parsedAt
    }
}

// MARK: - Extracted Content

/// Extracted content with local file URLs.
public struct ExtractedContent: Sendable {
    /// Primary thumbnail image
    public let thumbnail: URL?

    /// Product images/renderings
    public let productImages: [URL]

    /// Manufacturer logo
    public let manufacturerLogo: URL?

    /// Certification/compliance markings
    public let certificationMarkings: [URL]

    /// Extracted documents
    public let documents: [ExtractedDocument]

    public init(
        thumbnail: URL? = nil,
        productImages: [URL] = [],
        manufacturerLogo: URL? = nil,
        certificationMarkings: [URL] = [],
        documents: [ExtractedDocument] = []
    ) {
        self.thumbnail = thumbnail
        self.productImages = productImages
        self.manufacturerLogo = manufacturerLogo
        self.certificationMarkings = certificationMarkings
        self.documents = documents
    }

    /// Whether any content was extracted
    public var isEmpty: Bool {
        thumbnail == nil &&
        productImages.isEmpty &&
        manufacturerLogo == nil &&
        certificationMarkings.isEmpty &&
        documents.isEmpty
    }
}

// MARK: - Extracted Document

/// A document extracted from AASX package.
public struct ExtractedDocument: Sendable, Identifiable, Codable {
    public let id: String

    /// Document title/name
    public let title: String

    /// Local file URL
    public let localURL: URL

    /// MIME type
    public let mimeType: String

    /// Document category
    public let category: DocumentCategory

    /// Original filename in AASX
    public let originalFilename: String?

    /// File size in bytes
    public let fileSize: Int64?

    public init(
        id: String = UUID().uuidString,
        title: String,
        localURL: URL,
        mimeType: String,
        category: DocumentCategory,
        originalFilename: String? = nil,
        fileSize: Int64? = nil
    ) {
        self.id = id
        self.title = title
        self.localURL = localURL
        self.mimeType = mimeType
        self.category = category
        self.originalFilename = originalFilename
        self.fileSize = fileSize
    }
}

// MARK: - Document Category

/// Category of extracted document.
public enum DocumentCategory: String, Sendable, Codable, CaseIterable {
    case manual
    case certificate
    case datasheet
    case drawing
    case other

    public var displayName: String {
        switch self {
        case .manual: return "Manual"
        case .certificate: return "Certificate"
        case .datasheet: return "Datasheet"
        case .drawing: return "Drawing"
        case .other: return "Other"
        }
    }

    public var icon: String {
        switch self {
        case .manual: return "book.fill"
        case .certificate: return "checkmark.seal.fill"
        case .datasheet: return "doc.text.fill"
        case .drawing: return "pencil.and.ruler.fill"
        case .other: return "doc.fill"
        }
    }

    /// Infer category from filename
    public static func from(filename: String) -> DocumentCategory {
        let lowercased = filename.lowercased()

        if lowercased.contains("manual") || lowercased.contains("instruction") {
            return .manual
        }
        if lowercased.contains("certificate") || lowercased.contains("cert") {
            return .certificate
        }
        if lowercased.contains("datasheet") || lowercased.contains("spec") {
            return .datasheet
        }
        if lowercased.contains("drawing") || lowercased.contains("cad") {
            return .drawing
        }
        return .other
    }
}

// MARK: - AASX Warning

/// Non-fatal warning during AASX parsing.
public struct AASXWarning: Sendable, Identifiable {
    public let id: String
    public let type: WarningType
    public let message: String
    public let path: String?

    public enum WarningType: String, Sendable {
        case missingContent
        case corruptedFile
        case unsupportedFormat
        case partialMetadata
        case relationshipNotFound
    }

    public init(
        id: String = UUID().uuidString,
        type: WarningType,
        message: String,
        path: String? = nil
    ) {
        self.id = id
        self.type = type
        self.message = message
        self.path = path
    }

    public var description: String {
        if let path = path {
            return "\(message) (\(path))"
        }
        return message
    }
}

// MARK: - AASX Error

/// Errors that can occur during AASX parsing.
public enum AASXError: LocalizedError, Sendable {
    case fileNotFound(URL)
    case invalidPackage(String)
    case extractionFailed(String)
    case missingManifest
    case parsingFailed(String)
    case storageError(String)
    case downloadFailed(String)
    case userAborted

    public var errorDescription: String? {
        switch self {
        case .fileNotFound(let url):
            return "AASX file not found: \(url.lastPathComponent)"
        case .invalidPackage(let reason):
            return "Invalid AASX package: \(reason)"
        case .extractionFailed(let reason):
            return "Failed to extract AASX: \(reason)"
        case .missingManifest:
            return "AASX package is missing required manifest"
        case .parsingFailed(let reason):
            return "Failed to parse AASX content: \(reason)"
        case .storageError(let reason):
            return "Failed to store extracted content: \(reason)"
        case .downloadFailed(let reason):
            return "Failed to download AASX: \(reason)"
        case .userAborted:
            return "Import was cancelled"
        }
    }
}

// MARK: - AASX Import Issue

/// Issue found during import that requires user decision.
public enum AASXImportIssue: Sendable, Identifiable {
    case missingContent(paths: [String])
    case corruptedFile(path: String, error: String)
    case unsupportedFormat(path: String, format: String)
    case partialMetadata(missing: [String])

    public var id: String {
        switch self {
        case .missingContent(let paths):
            return "missing_\(paths.joined(separator: "_"))"
        case .corruptedFile(let path, _):
            return "corrupted_\(path)"
        case .unsupportedFormat(let path, _):
            return "unsupported_\(path)"
        case .partialMetadata(let missing):
            return "partial_\(missing.joined(separator: "_"))"
        }
    }

    public var title: String {
        switch self {
        case .missingContent:
            return "Missing Content"
        case .corruptedFile:
            return "Corrupted File"
        case .unsupportedFormat:
            return "Unsupported Format"
        case .partialMetadata:
            return "Incomplete Metadata"
        }
    }

    public var description: String {
        switch self {
        case .missingContent(let paths):
            return "Could not find: \(paths.joined(separator: ", "))"
        case .corruptedFile(let path, let error):
            return "\(path): \(error)"
        case .unsupportedFormat(let path, let format):
            return "\(path) has unsupported format: \(format)"
        case .partialMetadata(let missing):
            return "Missing fields: \(missing.joined(separator: ", "))"
        }
    }

    public var icon: String {
        switch self {
        case .missingContent:
            return "questionmark.folder"
        case .corruptedFile:
            return "exclamationmark.triangle"
        case .unsupportedFormat:
            return "doc.badge.ellipsis"
        case .partialMetadata:
            return "info.circle"
        }
    }
}

// MARK: - Image Item

/// An image extracted from AASX package with category information.
public struct AASXImageItem: Sendable, Identifiable, Equatable {
    public let id: String
    public let url: URL
    public let category: AASXImageCategory

    public init(url: URL, category: AASXImageCategory) {
        self.id = url.absoluteString
        self.url = url
        self.category = category
    }

    /// Filename without path
    public var filename: String {
        url.lastPathComponent
    }
}

/// Category of image in AASX package.
public enum AASXImageCategory: String, Sendable, CaseIterable {
    case product
    case certification
    case logo
    case thumbnail
    case other

    public var displayName: String {
        switch self {
        case .product: return "Product"
        case .certification: return "Certifications"
        case .logo: return "Logos"
        case .thumbnail: return "Thumbnails"
        case .other: return "Other"
        }
    }

    public var icon: String {
        switch self {
        case .product: return "photo.fill"
        case .certification: return "checkmark.seal.fill"
        case .logo: return "building.2.fill"
        case .thumbnail: return "photo.on.rectangle"
        case .other: return "photo"
        }
    }
}

// MARK: - CAD File

/// A CAD file extracted from AASX package.
public struct AASXCADFile: Sendable, Identifiable {
    public let id: String
    public let url: URL
    public let format: AASXCADFormat
    public let filename: String
    public let fileSize: Int64?

    public init(url: URL, format: AASXCADFormat, filename: String, fileSize: Int64? = nil) {
        self.id = url.absoluteString
        self.url = url
        self.format = format
        self.filename = filename
        self.fileSize = fileSize
    }

    /// Formatted file size
    public var formattedFileSize: String? {
        guard let size = fileSize else { return nil }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}

/// CAD file format with support level.
public enum AASXCADFormat: String, Sendable, CaseIterable {
    case usdz
    case obj
    case stl
    case gltf
    case glb
    case fbx
    case step
    case iges
    case unknown

    /// Display name for the format
    public var displayName: String {
        switch self {
        case .usdz: return "USDZ"
        case .obj: return "OBJ"
        case .stl: return "STL"
        case .gltf: return "glTF"
        case .glb: return "GLB"
        case .fbx: return "FBX"
        case .step: return "STEP"
        case .iges: return "IGES"
        case .unknown: return "Unknown"
        }
    }

    /// Whether this format is natively supported for viewing
    public var isNativelySupported: Bool {
        switch self {
        case .usdz, .obj, .stl, .gltf, .glb:
            return true
        case .fbx, .step, .iges, .unknown:
            return false
        }
    }

    /// SF Symbol icon for the format
    public var icon: String {
        switch self {
        case .usdz, .gltf, .glb:
            return "arkit"
        case .obj, .stl, .fbx:
            return "cube.fill"
        case .step, .iges:
            return "cube.transparent"
        case .unknown:
            return "doc.questionmark"
        }
    }

    /// Create from file extension
    public static func from(extension ext: String) -> AASXCADFormat {
        switch ext.lowercased() {
        case "usdz": return .usdz
        case "obj": return .obj
        case "stl": return .stl
        case "gltf": return .gltf
        case "glb": return .glb
        case "fbx": return .fbx
        case "step", "stp": return .step
        case "iges", "igs": return .iges
        default: return .unknown
        }
    }
}

// MARK: - Package Structure

/// A node in the AASX package structure tree.
public struct AASXPackageNode: Sendable, Identifiable {
    public let id: String
    public let name: String
    public let path: String
    public let isDirectory: Bool
    public let fileSize: Int64?
    public let children: [AASXPackageNode]?
    public let fileType: AASXFileType

    public init(
        name: String,
        path: String,
        isDirectory: Bool,
        fileSize: Int64? = nil,
        children: [AASXPackageNode]? = nil,
        fileType: AASXFileType = .other
    ) {
        self.id = path
        self.name = name
        self.path = path
        self.isDirectory = isDirectory
        self.fileSize = fileSize
        self.children = children
        self.fileType = fileType
    }

    /// Formatted file size
    public var formattedFileSize: String? {
        guard let size = fileSize else { return nil }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }

    /// Number of children (for directories)
    public var childCount: Int {
        children?.count ?? 0
    }
}

/// File type classification for package contents.
public enum AASXFileType: String, Sendable {
    case directory
    case json
    case xml
    case pdf
    case image
    case cad
    case archive
    case text
    case other

    public var icon: String {
        switch self {
        case .directory: return "folder.fill"
        case .json: return "curlybraces"
        case .xml: return "chevron.left.forwardslash.chevron.right"
        case .pdf: return "doc.fill"
        case .image: return "photo.fill"
        case .cad: return "cube.fill"
        case .archive: return "doc.zipper"
        case .text: return "doc.text.fill"
        case .other: return "doc"
        }
    }

    public var color: String {
        switch self {
        case .directory: return "blue"
        case .json: return "orange"
        case .xml: return "purple"
        case .pdf: return "red"
        case .image: return "green"
        case .cad: return "teal"
        case .archive: return "brown"
        case .text: return "gray"
        case .other: return "secondary"
        }
    }

    public static func from(extension ext: String) -> AASXFileType {
        switch ext.lowercased() {
        case "json": return .json
        case "xml", "aml": return .xml
        case "pdf": return .pdf
        case "jpg", "jpeg", "png", "gif", "webp", "svg", "bmp", "tiff": return .image
        case "usdz", "obj", "stl", "step", "stp", "iges", "igs", "gltf", "glb", "fbx": return .cad
        case "zip", "aasx", "tar", "gz": return .archive
        case "txt", "md", "csv", "log": return .text
        default: return .other
        }
    }
}

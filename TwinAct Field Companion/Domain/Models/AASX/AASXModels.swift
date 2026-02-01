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

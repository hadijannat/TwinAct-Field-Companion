# AASX Parser Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Extract embedded content (images, PDFs, documents) from AASX packages and display them in Asset Passport views.

**Architecture:** AASXImportManager coordinates file picker/URL import → AASXParser extracts using ZIPFoundation/XMLCoder → AASXContentStore persists to Documents → Models use resolved URLs with local fallback.

**Tech Stack:** ZIPFoundation (ZIP), XMLCoder (XML parsing), SwiftUI (UI), FileManager (storage)

---

## Task 1: Add SPM Dependencies

**Files:**
- Modify: `TwinAct Field Companion.xcodeproj` (via Xcode)

**Step 1: Add ZIPFoundation package**

In Xcode:
1. File → Add Package Dependencies
2. Enter URL: `https://github.com/weichsel/ZIPFoundation.git`
3. Set version rule: Up to Next Major (0.9.0)
4. Add to target: TwinAct Field Companion

**Step 2: Add XMLCoder package**

In Xcode:
1. File → Add Package Dependencies
2. Enter URL: `https://github.com/CoreOffice/XMLCoder.git`
3. Set version rule: Up to Next Major (0.17.0)
4. Add to target: TwinAct Field Companion

**Step 3: Verify dependencies resolve**

Run: Build project (Cmd+B)
Expected: BUILD SUCCEEDED with new packages visible in Package Dependencies

**Step 4: Commit**

```bash
git add -A
git commit -m "chore: Add ZIPFoundation and XMLCoder dependencies for AASX parsing"
```

---

## Task 2: Create AASX Data Models

**Files:**
- Create: `TwinAct Field Companion/Domain/Models/AASX/AASXModels.swift`
- Test: Compile check

**Step 1: Create the AASX directory**

```bash
mkdir -p "TwinAct Field Companion/Domain/Models/AASX"
```

**Step 2: Write AASXModels.swift**

```swift
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
```

**Step 3: Verify compilation**

Run: Build project (Cmd+B)
Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add "TwinAct Field Companion/Domain/Models/AASX/AASXModels.swift"
git commit -m "feat(aasx): Add data models for AASX parsing"
```

---

## Task 3: Create OPC Relationship Parser

**Files:**
- Create: `TwinAct Field Companion/Domain/Models/AASX/OPCRelationship.swift`

**Step 1: Write OPCRelationship.swift**

```swift
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
```

**Step 2: Verify compilation**

Run: Build project (Cmd+B)
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add "TwinAct Field Companion/Domain/Models/AASX/OPCRelationship.swift"
git commit -m "feat(aasx): Add OPC relationship parser for .rels files"
```

---

## Task 4: Create AASX Content Store

**Files:**
- Create: `TwinAct Field Companion/Domain/Services/AASX/AASXContentStore.swift`

**Step 1: Create the AASX services directory**

```bash
mkdir -p "TwinAct Field Companion/Domain/Services/AASX"
```

**Step 2: Write AASXContentStore.swift**

```swift
//
//  AASXContentStore.swift
//  TwinAct Field Companion
//
//  Local storage management for extracted AASX content.
//

import Foundation
import os.log

// MARK: - AASX Content Store

/// Manages local storage of extracted AASX content.
public final class AASXContentStore: @unchecked Sendable {

    // MARK: - Singleton

    public static let shared = AASXContentStore()

    // MARK: - Properties

    private let fileManager = FileManager.default
    private let logger = Logger(
        subsystem: AppConfiguration.AppInfo.bundleIdentifier,
        category: "AASXContentStore"
    )

    /// Base directory for all AASX content
    private var baseDirectory: URL {
        let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documents.appendingPathComponent("AASXContent", isDirectory: true)
    }

    // MARK: - Initialization

    private init() {
        createBaseDirectoryIfNeeded()
    }

    // MARK: - Public Methods

    /// Store parsed AASX content
    /// - Parameter result: Parse result to store
    /// - Returns: URL to the asset's content directory
    public func store(_ result: AASXParseResult) throws -> URL {
        let assetDir = assetDirectory(for: result.assetId)

        // Create directory structure
        try createDirectoryStructure(for: assetDir)

        // Store manifest
        try storeManifest(result.metadata, in: assetDir)

        logger.info("Stored AASX content for asset: \(result.assetId)")
        return assetDir
    }

    /// Copy extracted file to content store
    /// - Parameters:
    ///   - sourceURL: Source file URL (in temp directory)
    ///   - assetId: Asset identifier
    ///   - subdirectory: Subdirectory within asset folder (images, markings, documents)
    ///   - filename: Target filename
    /// - Returns: Local file URL in content store
    public func copyFile(
        from sourceURL: URL,
        forAsset assetId: String,
        subdirectory: String,
        filename: String
    ) throws -> URL {
        let assetDir = assetDirectory(for: assetId)
        let targetDir = assetDir.appendingPathComponent(subdirectory, isDirectory: true)

        // Ensure directory exists
        try fileManager.createDirectory(at: targetDir, withIntermediateDirectories: true)

        let targetURL = targetDir.appendingPathComponent(filename)

        // Remove existing file if present
        if fileManager.fileExists(atPath: targetURL.path) {
            try fileManager.removeItem(at: targetURL)
        }

        // Copy file
        try fileManager.copyItem(at: sourceURL, to: targetURL)

        logger.debug("Copied file to: \(targetURL.path)")
        return targetURL
    }

    /// Get thumbnail URL for asset
    public func thumbnailURL(for assetId: String) -> URL? {
        let candidates = [
            "thumbnail.jpg",
            "thumbnail.png",
            "thumbnail.jpeg"
        ]

        let assetDir = assetDirectory(for: assetId)

        for candidate in candidates {
            let url = assetDir.appendingPathComponent(candidate)
            if fileManager.fileExists(atPath: url.path) {
                return url
            }
        }

        // Check images directory for first product image
        return productImages(for: assetId).first
    }

    /// Get product images for asset
    public func productImages(for assetId: String) -> [URL] {
        let imagesDir = assetDirectory(for: assetId).appendingPathComponent("images")
        return filesInDirectory(imagesDir, extensions: ["jpg", "jpeg", "png", "gif", "webp"])
    }

    /// Get manufacturer logo URL for asset
    public func logoURL(for assetId: String) -> URL? {
        let imagesDir = assetDirectory(for: assetId).appendingPathComponent("images")
        let candidates = [
            "logo.png",
            "logo.jpg",
            "manufacturer_logo.png",
            "manufacturer_logo.jpg"
        ]

        for candidate in candidates {
            let url = imagesDir.appendingPathComponent(candidate)
            if fileManager.fileExists(atPath: url.path) {
                return url
            }
        }
        return nil
    }

    /// Get certification marking URLs for asset
    public func markingURLs(for assetId: String) -> [URL] {
        let markingsDir = assetDirectory(for: assetId).appendingPathComponent("markings")
        return filesInDirectory(markingsDir, extensions: ["jpg", "jpeg", "png", "gif", "svg"])
    }

    /// Get documents for asset
    public func documents(for assetId: String) -> [ExtractedDocument] {
        let docsDir = assetDirectory(for: assetId).appendingPathComponent("documents")
        let files = filesInDirectory(docsDir, extensions: ["pdf", "doc", "docx", "xls", "xlsx", "txt"])

        return files.map { url in
            let filename = url.lastPathComponent
            let mimeType = mimeType(for: url)
            let category = DocumentCategory.from(filename: filename)
            let fileSize = try? fileManager.attributesOfItem(atPath: url.path)[.size] as? Int64

            return ExtractedDocument(
                title: (filename as NSString).deletingPathExtension,
                localURL: url,
                mimeType: mimeType,
                category: category,
                originalFilename: filename,
                fileSize: fileSize
            )
        }
    }

    /// Check if content exists for asset
    public func hasContent(for assetId: String) -> Bool {
        let assetDir = assetDirectory(for: assetId)
        return fileManager.fileExists(atPath: assetDir.path)
    }

    /// Delete content for asset
    public func deleteContent(for assetId: String) throws {
        let assetDir = assetDirectory(for: assetId)
        if fileManager.fileExists(atPath: assetDir.path) {
            try fileManager.removeItem(at: assetDir)
            logger.info("Deleted content for asset: \(assetId)")
        }
    }

    /// Get total storage used by all AASX content
    public func totalStorageUsed() -> Int64 {
        guard let enumerator = fileManager.enumerator(
            at: baseDirectory,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }

        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                total += Int64(size)
            }
        }
        return total
    }

    /// List all stored asset IDs
    public func storedAssetIds() -> [String] {
        guard let contents = try? fileManager.contentsOfDirectory(
            at: baseDirectory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return contents.compactMap { url in
            let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            return isDirectory ? url.lastPathComponent : nil
        }
    }

    // MARK: - Private Methods

    private func assetDirectory(for assetId: String) -> URL {
        // Sanitize asset ID for filesystem
        let sanitized = assetId
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
            .replacingOccurrences(of: "?", with: "_")
            .replacingOccurrences(of: "&", with: "_")

        return baseDirectory.appendingPathComponent(sanitized, isDirectory: true)
    }

    private func createBaseDirectoryIfNeeded() {
        if !fileManager.fileExists(atPath: baseDirectory.path) {
            do {
                try fileManager.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
                logger.info("Created AASX content directory: \(self.baseDirectory.path)")
            } catch {
                logger.error("Failed to create base directory: \(error.localizedDescription)")
            }
        }
    }

    private func createDirectoryStructure(for assetDir: URL) throws {
        let subdirectories = ["images", "markings", "documents"]

        for subdir in subdirectories {
            let path = assetDir.appendingPathComponent(subdir, isDirectory: true)
            try fileManager.createDirectory(at: path, withIntermediateDirectories: true)
        }
    }

    private func storeManifest(_ metadata: AASXMetadata, in directory: URL) throws {
        let manifestURL = directory.appendingPathComponent("manifest.json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(metadata)
        try data.write(to: manifestURL)
    }

    private func filesInDirectory(_ directory: URL, extensions: [String]) -> [URL] {
        guard let contents = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return contents.filter { url in
            extensions.contains(url.pathExtension.lowercased())
        }.sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    private func mimeType(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "pdf": return "application/pdf"
        case "doc": return "application/msword"
        case "docx": return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        case "xls": return "application/vnd.ms-excel"
        case "xlsx": return "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        case "txt": return "text/plain"
        case "jpg", "jpeg": return "image/jpeg"
        case "png": return "image/png"
        case "gif": return "image/gif"
        default: return "application/octet-stream"
        }
    }
}
```

**Step 3: Verify compilation**

Run: Build project (Cmd+B)
Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add "TwinAct Field Companion/Domain/Services/AASX/AASXContentStore.swift"
git commit -m "feat(aasx): Add content store for local AASX storage"
```

---

## Task 5: Create AASX Parser

**Files:**
- Create: `TwinAct Field Companion/Domain/Services/AASX/AASXParser.swift`

**Step 1: Write AASXParser.swift**

```swift
//
//  AASXParser.swift
//  TwinAct Field Companion
//
//  Core AASX package parser using ZIPFoundation and XMLCoder.
//

import Foundation
import ZIPFoundation
import XMLCoder
import os.log

// MARK: - AASX Parser

/// Parser for AASX (Asset Administration Shell Exchange) packages.
public final class AASXParser: @unchecked Sendable {

    // MARK: - Properties

    private let fileManager = FileManager.default
    private let contentStore: AASXContentStore
    private let logger = Logger(
        subsystem: AppConfiguration.AppInfo.bundleIdentifier,
        category: "AASXParser"
    )

    // MARK: - Initialization

    public init(contentStore: AASXContentStore = .shared) {
        self.contentStore = contentStore
    }

    // MARK: - Public Methods

    /// Parse an AASX file
    /// - Parameters:
    ///   - url: URL to the AASX file
    ///   - assetId: Optional asset ID override (extracted from package if nil)
    /// - Returns: Parse result with extracted content
    public func parse(url: URL, assetId: String? = nil) async throws -> AASXParseResult {
        logger.info("Parsing AASX: \(url.lastPathComponent)")

        // Verify file exists
        guard fileManager.fileExists(atPath: url.path) else {
            throw AASXError.fileNotFound(url)
        }

        // Create temp directory for extraction
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)

        defer {
            // Cleanup temp directory
            try? fileManager.removeItem(at: tempDir)
        }

        // Extract ZIP contents
        try await extractPackage(from: url, to: tempDir)

        // Parse content types
        let contentTypes = try parseContentTypes(in: tempDir)

        // Parse root relationships
        let rootRels = try parseRelationships(at: OPCRelationshipParser.rootRelsPath, in: tempDir)

        // Extract asset ID and metadata
        let extractedAssetId = assetId ?? extractAssetId(from: rootRels, in: tempDir)
        let metadata = try extractMetadata(from: tempDir, filename: url.lastPathComponent)

        // Collect warnings
        var warnings: [AASXWarning] = []

        // Extract and store content
        let content = try await extractContent(
            from: tempDir,
            assetId: extractedAssetId,
            relationships: rootRels,
            contentTypes: contentTypes,
            warnings: &warnings
        )

        logger.info("AASX parsed successfully. Asset: \(extractedAssetId), Warnings: \(warnings.count)")

        return AASXParseResult(
            assetId: extractedAssetId,
            metadata: metadata,
            extractedContent: content,
            warnings: warnings
        )
    }

    /// Get issues found during preliminary scan
    public func scanForIssues(url: URL) async throws -> [AASXImportIssue] {
        var issues: [AASXImportIssue] = []

        // Verify file exists
        guard fileManager.fileExists(atPath: url.path) else {
            throw AASXError.fileNotFound(url)
        }

        // Try to open as ZIP
        guard let archive = Archive(url: url, accessMode: .read) else {
            throw AASXError.invalidPackage("Not a valid ZIP archive")
        }

        // Check for required files
        var hasContentTypes = false
        var hasRootRels = false

        for entry in archive {
            if entry.path == "[Content_Types].xml" {
                hasContentTypes = true
            }
            if entry.path == "_rels/.rels" {
                hasRootRels = true
            }
        }

        if !hasContentTypes {
            issues.append(.missingContent(paths: ["[Content_Types].xml"]))
        }

        if !hasRootRels {
            issues.append(.missingContent(paths: ["_rels/.rels"]))
        }

        return issues
    }

    // MARK: - Private Methods

    private func extractPackage(from url: URL, to destination: URL) async throws {
        guard let archive = Archive(url: url, accessMode: .read) else {
            throw AASXError.invalidPackage("Failed to open AASX as ZIP archive")
        }

        for entry in archive {
            let entryPath = destination.appendingPathComponent(entry.path)

            // Create parent directories
            let parentDir = entryPath.deletingLastPathComponent()
            if !fileManager.fileExists(atPath: parentDir.path) {
                try fileManager.createDirectory(at: parentDir, withIntermediateDirectories: true)
            }

            // Extract entry
            if entry.type == .directory {
                try fileManager.createDirectory(at: entryPath, withIntermediateDirectories: true)
            } else {
                _ = try archive.extract(entry, to: entryPath)
            }
        }

        logger.debug("Extracted AASX to: \(destination.path)")
    }

    private func parseContentTypes(in directory: URL) throws -> OPCContentTypes {
        let contentTypesURL = directory.appendingPathComponent("[Content_Types].xml")

        guard fileManager.fileExists(atPath: contentTypesURL.path) else {
            throw AASXError.missingManifest
        }

        let data = try Data(contentsOf: contentTypesURL)
        return try OPCRelationshipParser.parseContentTypes(data: data)
    }

    private func parseRelationships(at path: String, in directory: URL) throws -> OPCRelationships {
        let relsURL = directory.appendingPathComponent(path)

        guard fileManager.fileExists(atPath: relsURL.path) else {
            logger.warning("Relationships file not found: \(path)")
            return OPCRelationships()
        }

        let data = try Data(contentsOf: relsURL)
        return try OPCRelationshipParser.parse(data: data)
    }

    private func extractAssetId(from relationships: OPCRelationships, in directory: URL) -> String {
        // Try to find AAS spec relationship
        if let aasRel = relationships.relationships.first(where: {
            $0.type == OPCRelationshipType.aasxOrigin ||
            $0.type == OPCRelationshipType.aasSpec
        }) {
            // Parse AAS JSON/XML to get asset ID
            let aasPath = directory.appendingPathComponent(aasRel.normalizedTarget)
            if let assetId = extractAssetIdFromAAS(at: aasPath) {
                return assetId
            }
        }

        // Fallback: generate from directory name
        return UUID().uuidString
    }

    private func extractAssetIdFromAAS(at url: URL) -> String? {
        guard let data = try? Data(contentsOf: url) else { return nil }

        // Try JSON first
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            // Look for assetInformation.globalAssetId
            if let assetInfo = json["assetInformation"] as? [String: Any],
               let globalAssetId = assetInfo["globalAssetId"] as? String {
                return globalAssetId
            }
            // Or id at root
            if let id = json["id"] as? String {
                return id
            }
        }

        return nil
    }

    private func extractMetadata(from directory: URL, filename: String) throws -> AASXMetadata {
        // Try to find and parse AAS metadata
        var metadata = AASXMetadata(sourceFilename: filename)

        // Look for common AAS file locations
        let aasLocations = [
            "aasx/aas.json",
            "aas.json",
            "aasx/aas.xml"
        ]

        for location in aasLocations {
            let aasURL = directory.appendingPathComponent(location)
            if let data = try? Data(contentsOf: aasURL),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {

                metadata = AASXMetadata(
                    assetName: json["idShort"] as? String,
                    manufacturerName: extractManufacturer(from: json),
                    serialNumber: extractSerialNumber(from: json),
                    productDesignation: json["description"] as? String,
                    sourceFilename: filename
                )
                break
            }
        }

        return metadata
    }

    private func extractManufacturer(from json: [String: Any]) -> String? {
        // Try various paths where manufacturer might be
        if let submodels = json["submodels"] as? [[String: Any]] {
            for submodel in submodels {
                if let elements = submodel["submodelElements"] as? [[String: Any]] {
                    for element in elements {
                        if let idShort = element["idShort"] as? String,
                           idShort.lowercased().contains("manufacturer"),
                           let value = element["value"] as? String {
                            return value
                        }
                    }
                }
            }
        }
        return nil
    }

    private func extractSerialNumber(from json: [String: Any]) -> String? {
        if let submodels = json["submodels"] as? [[String: Any]] {
            for submodel in submodels {
                if let elements = submodel["submodelElements"] as? [[String: Any]] {
                    for element in elements {
                        if let idShort = element["idShort"] as? String,
                           idShort.lowercased().contains("serial"),
                           let value = element["value"] as? String {
                            return value
                        }
                    }
                }
            }
        }
        return nil
    }

    private func extractContent(
        from directory: URL,
        assetId: String,
        relationships: OPCRelationships,
        contentTypes: OPCContentTypes,
        warnings: inout [AASXWarning]
    ) async throws -> ExtractedContent {
        var thumbnail: URL?
        var productImages: [URL] = []
        var manufacturerLogo: URL?
        var certificationMarkings: [URL] = []
        var documents: [ExtractedDocument] = []

        // Process thumbnail relationship
        if let thumbRel = relationships.relationships.first(where: { $0.type == OPCRelationshipType.thumbnail }) {
            let sourcePath = directory.appendingPathComponent(thumbRel.normalizedTarget)
            if fileManager.fileExists(atPath: sourcePath.path) {
                let filename = "thumbnail.\(sourcePath.pathExtension)"
                thumbnail = try contentStore.copyFile(
                    from: sourcePath,
                    forAsset: assetId,
                    subdirectory: "",
                    filename: filename
                )
            }
        }

        // Scan for images and documents
        let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )

        while let fileURL = enumerator?.nextObject() as? URL {
            let ext = fileURL.pathExtension.lowercased()
            let filename = fileURL.lastPathComponent.lowercased()
            let relativePath = fileURL.path.replacingOccurrences(of: directory.path + "/", with: "")

            // Skip metadata files
            if filename.hasSuffix(".rels") || filename == "[content_types].xml" {
                continue
            }

            // Images
            if ["jpg", "jpeg", "png", "gif", "webp"].contains(ext) {
                do {
                    if filename.contains("logo") {
                        manufacturerLogo = try contentStore.copyFile(
                            from: fileURL,
                            forAsset: assetId,
                            subdirectory: "images",
                            filename: fileURL.lastPathComponent
                        )
                    } else if filename.contains("marking") || filename.contains("ce_") || filename.contains("ul_") {
                        let url = try contentStore.copyFile(
                            from: fileURL,
                            forAsset: assetId,
                            subdirectory: "markings",
                            filename: fileURL.lastPathComponent
                        )
                        certificationMarkings.append(url)
                    } else if filename != "thumbnail.jpg" && filename != "thumbnail.png" {
                        let url = try contentStore.copyFile(
                            from: fileURL,
                            forAsset: assetId,
                            subdirectory: "images",
                            filename: fileURL.lastPathComponent
                        )
                        productImages.append(url)
                    }
                } catch {
                    warnings.append(AASXWarning(
                        type: .corruptedFile,
                        message: "Failed to copy image",
                        path: relativePath
                    ))
                }
            }

            // Documents
            if ["pdf", "doc", "docx", "xls", "xlsx", "txt"].contains(ext) {
                do {
                    let url = try contentStore.copyFile(
                        from: fileURL,
                        forAsset: assetId,
                        subdirectory: "documents",
                        filename: fileURL.lastPathComponent
                    )

                    let category = DocumentCategory.from(filename: filename)
                    let fileSize = try? fileManager.attributesOfItem(atPath: fileURL.path)[.size] as? Int64

                    documents.append(ExtractedDocument(
                        title: (filename as NSString).deletingPathExtension,
                        localURL: url,
                        mimeType: contentStore.mimeType(for: url),
                        category: category,
                        originalFilename: fileURL.lastPathComponent,
                        fileSize: fileSize
                    ))
                } catch {
                    warnings.append(AASXWarning(
                        type: .corruptedFile,
                        message: "Failed to copy document",
                        path: relativePath
                    ))
                }
            }
        }

        return ExtractedContent(
            thumbnail: thumbnail,
            productImages: productImages,
            manufacturerLogo: manufacturerLogo,
            certificationMarkings: certificationMarkings,
            documents: documents
        )
    }
}

// MARK: - Content Store Extension

extension AASXContentStore {
    func mimeType(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "pdf": return "application/pdf"
        case "doc": return "application/msword"
        case "docx": return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        case "xls": return "application/vnd.ms-excel"
        case "xlsx": return "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        case "txt": return "text/plain"
        default: return "application/octet-stream"
        }
    }
}
```

**Step 2: Verify compilation**

Run: Build project (Cmd+B)
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add "TwinAct Field Companion/Domain/Services/AASX/AASXParser.swift"
git commit -m "feat(aasx): Add AASX parser with ZIPFoundation extraction"
```

---

## Task 6: Create AASX Import Manager

**Files:**
- Create: `TwinAct Field Companion/Domain/Services/AASX/AASXImportManager.swift`

**Step 1: Write AASXImportManager.swift**

```swift
//
//  AASXImportManager.swift
//  TwinAct Field Companion
//
//  Coordinates AASX import from file picker or URL download.
//

import Foundation
import Combine
import os.log

// MARK: - Import State

/// State of an AASX import operation.
public enum AASXImportState: Equatable {
    case idle
    case downloading(progress: Double)
    case extracting
    case parsing
    case storingContent
    case awaitingUserDecision(issues: [AASXImportIssue])
    case completed(AASXParseResult)
    case failed(String)

    public static func == (lhs: AASXImportState, rhs: AASXImportState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.extracting, .extracting), (.parsing, .parsing), (.storingContent, .storingContent):
            return true
        case (.downloading(let a), .downloading(let b)):
            return a == b
        case (.failed(let a), .failed(let b)):
            return a == b
        case (.completed(let a), .completed(let b)):
            return a.assetId == b.assetId
        case (.awaitingUserDecision(let a), .awaitingUserDecision(let b)):
            return a.map(\.id) == b.map(\.id)
        default:
            return false
        }
    }
}

// MARK: - Import Manager

/// Manages AASX file imports from file picker or URL download.
@MainActor
public final class AASXImportManager: ObservableObject {

    // MARK: - Published Properties

    @Published public private(set) var state: AASXImportState = .idle
    @Published public private(set) var currentResult: AASXParseResult?

    // MARK: - Properties

    private let parser: AASXParser
    private let contentStore: AASXContentStore
    private let logger = Logger(
        subsystem: AppConfiguration.AppInfo.bundleIdentifier,
        category: "AASXImportManager"
    )

    private var downloadTask: URLSessionDownloadTask?
    private var pendingIssues: [AASXImportIssue] = []
    private var pendingURL: URL?

    // MARK: - Initialization

    public init(
        parser: AASXParser = AASXParser(),
        contentStore: AASXContentStore = .shared
    ) {
        self.parser = parser
        self.contentStore = contentStore
    }

    // MARK: - Public Methods

    /// Import AASX from local file URL
    public func importFromFile(_ url: URL) async {
        logger.info("Importing AASX from file: \(url.lastPathComponent)")

        // Start accessing security-scoped resource
        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        // Scan for issues first
        state = .extracting

        do {
            let issues = try await parser.scanForIssues(url: url)

            if !issues.isEmpty {
                pendingURL = url
                pendingIssues = issues
                state = .awaitingUserDecision(issues: issues)
                return
            }

            // No issues, proceed with parsing
            await parseAndStore(url: url)

        } catch {
            logger.error("Import failed: \(error.localizedDescription)")
            state = .failed(error.localizedDescription)
        }
    }

    /// Import AASX from remote URL
    public func importFromURL(_ urlString: String) async {
        guard let url = URL(string: urlString) else {
            state = .failed("Invalid URL")
            return
        }

        logger.info("Downloading AASX from: \(urlString)")
        state = .downloading(progress: 0)

        do {
            let localURL = try await downloadFile(from: url)

            // Scan for issues
            let issues = try await parser.scanForIssues(url: localURL)

            if !issues.isEmpty {
                pendingURL = localURL
                pendingIssues = issues
                state = .awaitingUserDecision(issues: issues)
                return
            }

            await parseAndStore(url: localURL)

            // Cleanup downloaded file
            try? FileManager.default.removeItem(at: localURL)

        } catch {
            logger.error("Download failed: \(error.localizedDescription)")
            state = .failed(error.localizedDescription)
        }
    }

    /// User chose to continue despite issues
    public func continueWithIssues() async {
        guard let url = pendingURL else {
            state = .failed("No pending import")
            return
        }

        pendingIssues = []
        await parseAndStore(url: url)
    }

    /// User chose to abort due to issues
    public func abortImport() {
        pendingURL = nil
        pendingIssues = []
        state = .idle
        logger.info("Import aborted by user")
    }

    /// Cancel ongoing download
    public func cancelDownload() {
        downloadTask?.cancel()
        downloadTask = nil
        state = .idle
    }

    /// Reset to idle state
    public func reset() {
        state = .idle
        currentResult = nil
        pendingURL = nil
        pendingIssues = []
    }

    // MARK: - Private Methods

    private func downloadFile(from url: URL) async throws -> URL {
        let (tempURL, response) = try await URLSession.shared.download(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw AASXError.downloadFailed("Server returned error")
        }

        // Move to permanent temp location with .aasx extension
        let destinationURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("aasx")

        try FileManager.default.moveItem(at: tempURL, to: destinationURL)

        return destinationURL
    }

    private func parseAndStore(url: URL) async {
        state = .parsing

        do {
            let result = try await parser.parse(url: url)

            state = .storingContent
            _ = try contentStore.store(result)

            currentResult = result
            state = .completed(result)

            logger.info("Import completed: \(result.assetId)")

        } catch {
            logger.error("Parse failed: \(error.localizedDescription)")
            state = .failed(error.localizedDescription)
        }
    }
}
```

**Step 2: Verify compilation**

Run: Build project (Cmd+B)
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add "TwinAct Field Companion/Domain/Services/AASX/AASXImportManager.swift"
git commit -m "feat(aasx): Add import manager for file picker and URL download"
```

---

## Task 7: Add Model Extensions for Resolved URLs

**Files:**
- Modify: `TwinAct Field Companion/Domain/Models/AssetModel.swift`
- Modify: `TwinAct Field Companion/Domain/Models/DigitalNameplate.swift`

**Step 1: Add extension to AssetModel.swift**

Add at end of file before closing:

```swift
// MARK: - AASX Content Integration

extension Asset {
    /// Returns local AASX content URL if available, otherwise remote URL
    public var resolvedThumbnailURL: URL? {
        if let localURL = AASXContentStore.shared.thumbnailURL(for: id) {
            return localURL
        }
        return thumbnailURL
    }

    /// Whether this asset has locally stored AASX content
    public var hasLocalContent: Bool {
        AASXContentStore.shared.hasContent(for: id)
    }

    /// Get all product images (local + remote)
    public var resolvedProductImages: [URL] {
        let local = AASXContentStore.shared.productImages(for: id)
        if !local.isEmpty {
            return local
        }
        if let thumbnail = thumbnailURL {
            return [thumbnail]
        }
        return []
    }
}
```

**Step 2: Add extension to DigitalNameplate.swift**

Add at end of file:

```swift
// MARK: - AASX Content Integration

extension DigitalNameplate {
    /// Resolved product image URL (local AASX content preferred)
    public func resolvedProductImage(for assetId: String) -> URL? {
        if let localURL = AASXContentStore.shared.thumbnailURL(for: assetId) {
            return localURL
        }
        if let localImages = AASXContentStore.shared.productImages(for: assetId).first {
            return localImages
        }
        return productImage
    }

    /// Resolved manufacturer logo URL (local AASX content preferred)
    public func resolvedManufacturerLogo(for assetId: String) -> URL? {
        if let localURL = AASXContentStore.shared.logoURL(for: assetId) {
            return localURL
        }
        return manufacturerLogo
    }

    /// Resolved certification markings (local AASX content preferred)
    public func resolvedMarkings(for assetId: String) -> [Marking] {
        let localMarkingURLs = AASXContentStore.shared.markingURLs(for: assetId)

        if !localMarkingURLs.isEmpty {
            return localMarkingURLs.map { url in
                Marking(
                    name: (url.lastPathComponent as NSString).deletingPathExtension.uppercased(),
                    file: url
                )
            }
        }

        return markings ?? []
    }
}
```

**Step 3: Verify compilation**

Run: Build project (Cmd+B)
Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add "TwinAct Field Companion/Domain/Models/AssetModel.swift"
git add "TwinAct Field Companion/Domain/Models/DigitalNameplate.swift"
git commit -m "feat(aasx): Add resolved URL extensions for local content fallback"
```

---

## Task 8: Create Import UI Components

**Files:**
- Create: `TwinAct Field Companion/Core/UI/Components/AASXImportView.swift`

**Step 1: Write AASXImportView.swift**

```swift
//
//  AASXImportView.swift
//  TwinAct Field Companion
//
//  UI components for AASX file import.
//

import SwiftUI
import UniformTypeIdentifiers

// MARK: - AASX UTType

extension UTType {
    /// AASX file type
    static let aasx = UTType(filenameExtension: "aasx") ?? .data
}

// MARK: - AASX Import Sheet

/// Sheet for importing AASX files via URL.
public struct AASXURLImportSheet: View {
    @ObservedObject var importManager: AASXImportManager
    @Environment(\.dismiss) private var dismiss

    @State private var urlString = ""
    @FocusState private var isURLFieldFocused: Bool

    public init(importManager: AASXImportManager) {
        self.importManager = importManager
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "link.badge.plus")
                        .font(.system(size: 48))
                        .foregroundColor(.accentColor)

                    Text("Import from URL")
                        .font(.title2.bold())

                    Text("Enter the URL of an AASX file to import")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top)

                // URL input
                VStack(alignment: .leading, spacing: 8) {
                    Text("AASX URL")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    TextField("https://example.com/asset.aasx", text: $urlString)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                        .focused($isURLFieldFocused)
                }
                .padding(.horizontal)

                // State indicator
                stateView

                Spacer()

                // Actions
                actionButtons
            }
            .navigationTitle("Import AASX")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        importManager.cancelDownload()
                        dismiss()
                    }
                }
            }
            .onAppear {
                isURLFieldFocused = true
            }
        }
        .presentationDetents([.medium])
    }

    @ViewBuilder
    private var stateView: some View {
        switch importManager.state {
        case .idle:
            EmptyView()

        case .downloading(let progress):
            VStack(spacing: 8) {
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                Text("Downloading... \(Int(progress * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)

        case .extracting, .parsing, .storingContent:
            VStack(spacing: 8) {
                ProgressView()
                Text(stateMessage)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

        case .awaitingUserDecision(let issues):
            AASXIssuesAlert(
                issues: issues,
                onContinue: {
                    Task { await importManager.continueWithIssues() }
                },
                onAbort: {
                    importManager.abortImport()
                }
            )

        case .completed:
            VStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.green)
                Text("Import successful!")
                    .font(.headline)
            }

        case .failed(let error):
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.orange)
                Text(error)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal)
        }
    }

    private var stateMessage: String {
        switch importManager.state {
        case .extracting: return "Extracting package..."
        case .parsing: return "Parsing content..."
        case .storingContent: return "Storing files..."
        default: return ""
        }
    }

    @ViewBuilder
    private var actionButtons: some View {
        switch importManager.state {
        case .idle, .failed:
            Button {
                Task {
                    await importManager.importFromURL(urlString)
                }
            } label: {
                Label("Download & Import", systemImage: "arrow.down.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(urlString.isEmpty || !isValidURL)
            .padding(.horizontal)
            .padding(.bottom)

        case .completed:
            Button {
                dismiss()
            } label: {
                Text("Done")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal)
            .padding(.bottom)

        default:
            EmptyView()
        }
    }

    private var isValidURL: Bool {
        guard let url = URL(string: urlString) else { return false }
        return url.scheme == "http" || url.scheme == "https"
    }
}

// MARK: - Issues Alert

/// Alert view showing import issues.
struct AASXIssuesAlert: View {
    let issues: [AASXImportIssue]
    let onContinue: () -> Void
    let onAbort: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundColor(.orange)

            Text("Issues Found")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(issues) { issue in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: issue.icon)
                            .foregroundColor(.orange)
                            .frame(width: 20)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(issue.title)
                                .font(.subheadline.bold())
                            Text(issue.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(8)

            HStack(spacing: 16) {
                Button("Abort") {
                    onAbort()
                }
                .buttonStyle(.bordered)

                Button("Continue Anyway") {
                    onContinue()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }
}

// MARK: - File Importer Modifier

/// View modifier for AASX file import.
public struct AASXFileImporterModifier: ViewModifier {
    @Binding var isPresented: Bool
    let importManager: AASXImportManager

    public func body(content: Content) -> some View {
        content
            .fileImporter(
                isPresented: $isPresented,
                allowedContentTypes: [.aasx, .zip],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        Task {
                            await importManager.importFromFile(url)
                        }
                    }
                case .failure(let error):
                    print("File selection failed: \(error)")
                }
            }
    }
}

extension View {
    /// Add AASX file importer capability
    public func aasxFileImporter(
        isPresented: Binding<Bool>,
        importManager: AASXImportManager
    ) -> some View {
        modifier(AASXFileImporterModifier(isPresented: isPresented, importManager: importManager))
    }
}

// MARK: - Import Progress View

/// Compact progress indicator for import state.
public struct AASXImportProgressView: View {
    @ObservedObject var importManager: AASXImportManager

    public init(importManager: AASXImportManager) {
        self.importManager = importManager
    }

    public var body: some View {
        switch importManager.state {
        case .idle:
            EmptyView()

        case .downloading(let progress):
            HStack(spacing: 8) {
                ProgressView()
                    .scaleEffect(0.8)
                Text("Downloading \(Int(progress * 100))%")
                    .font(.caption)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(16)

        case .extracting, .parsing, .storingContent:
            HStack(spacing: 8) {
                ProgressView()
                    .scaleEffect(0.8)
                Text("Importing...")
                    .font(.caption)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(16)

        default:
            EmptyView()
        }
    }
}

// MARK: - Preview

#if DEBUG
struct AASXImportView_Previews: PreviewProvider {
    static var previews: some View {
        AASXURLImportSheet(importManager: AASXImportManager())
            .previewDisplayName("URL Import")
    }
}
#endif
```

**Step 2: Verify compilation**

Run: Build project (Cmd+B)
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add "TwinAct Field Companion/Core/UI/Components/AASXImportView.swift"
git commit -m "feat(aasx): Add import UI components with file picker and URL support"
```

---

## Task 9: Update AssetHeaderView to Use Resolved URLs

**Files:**
- Modify: `TwinAct Field Companion/Features/Passport/AssetHeaderView.swift`

**Step 1: Update productImage computed property**

Replace line 58's `asset?.thumbnailURL` with `asset?.resolvedThumbnailURL`:

```swift
private var productImage: some View {
    Group {
        if let imageURL = asset?.resolvedThumbnailURL {  // Changed from thumbnailURL
            AsyncImage(url: imageURL) { phase in
                // ... rest unchanged
            }
        } else {
            placeholderImage
        }
    }
}
```

**Step 2: Update LargeAssetHeaderView**

In `LargeAssetHeaderView`, update line 222 to use resolved URLs:

```swift
public var body: some View {
    VStack(spacing: 20) {
        // Large product image
        if let asset = asset,
           let imageURL = nameplate?.resolvedProductImage(for: asset.id) ?? asset.resolvedThumbnailURL {
            AsyncImage(url: imageURL) { phase in
                // ... rest unchanged
            }
        } else {
            largePlaceholder
        }

        // ... rest of view unchanged
```

And update manufacturer logo around line 250:

```swift
// Manufacturer logo
if let asset = asset,
   let logoURL = nameplate?.resolvedManufacturerLogo(for: asset.id) {
    AsyncImage(url: logoURL) { image in
        // ... rest unchanged
    }
}
```

**Step 3: Verify compilation**

Run: Build project (Cmd+B)
Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add "TwinAct Field Companion/Features/Passport/AssetHeaderView.swift"
git commit -m "feat(aasx): Update AssetHeaderView to use resolved local URLs"
```

---

## Task 10: Add Import Menu to PassportView

**Files:**
- Modify: `TwinAct Field Companion/Features/Passport/PassportView.swift`

**Step 1: Add import manager and state properties**

Add after line 31 (after `let glossaryService: GlossaryService?`):

```swift
// AASX Import
@StateObject private var aasxImportManager = AASXImportManager()
@State private var showFileImporter = false
@State private var showURLImporter = false
```

**Step 2: Add import menu to toolbar**

In the `.toolbar` section around line 133, add before the existing ToolbarItem:

```swift
// AASX Import menu
ToolbarItem(placement: .topBarTrailing) {
    Menu {
        Button {
            showFileImporter = true
        } label: {
            Label("Import from Files", systemImage: "folder")
        }

        Button {
            showURLImporter = true
        } label: {
            Label("Import from URL", systemImage: "link")
        }
    } label: {
        Image(systemName: "square.and.arrow.down")
    }
    .accessibilityLabel("Import AASX")
}
```

**Step 3: Add file importer and sheet modifiers**

After the existing `.sheet` modifiers around line 177, add:

```swift
// AASX file importer
.aasxFileImporter(isPresented: $showFileImporter, importManager: aasxImportManager)
// AASX URL import sheet
.sheet(isPresented: $showURLImporter) {
    AASXURLImportSheet(importManager: aasxImportManager)
}
// Import completion handler
.onChange(of: aasxImportManager.state) { _, newState in
    if case .completed = newState {
        // Refresh the view to show new content
        Task {
            await viewModel.refresh()
        }
    }
}
```

**Step 4: Verify compilation**

Run: Build project (Cmd+B)
Expected: BUILD SUCCEEDED

**Step 5: Commit**

```bash
git add "TwinAct Field Companion/Features/Passport/PassportView.swift"
git commit -m "feat(aasx): Add AASX import menu to PassportView toolbar"
```

---

## Task 11: Register AASX UTType in Info.plist

**Files:**
- Modify: `Info.plist`

**Step 1: Add document types and imported UTIs**

Add the following to Info.plist (before the closing `</dict></plist>`):

```xml
<key>CFBundleDocumentTypes</key>
<array>
    <dict>
        <key>CFBundleTypeName</key>
        <string>AASX Package</string>
        <key>CFBundleTypeRole</key>
        <string>Viewer</string>
        <key>LSHandlerRank</key>
        <string>Default</string>
        <key>LSItemContentTypes</key>
        <array>
            <string>com.twinact.aasx</string>
        </array>
    </dict>
</array>
<key>UTImportedTypeDeclarations</key>
<array>
    <dict>
        <key>UTTypeConformsTo</key>
        <array>
            <string>public.data</string>
            <string>public.archive</string>
        </array>
        <key>UTTypeDescription</key>
        <string>Asset Administration Shell Exchange Package</string>
        <key>UTTypeIconFiles</key>
        <array/>
        <key>UTTypeIdentifier</key>
        <string>com.twinact.aasx</string>
        <key>UTTypeTagSpecification</key>
        <dict>
            <key>public.filename-extension</key>
            <array>
                <string>aasx</string>
            </array>
            <key>public.mime-type</key>
            <string>application/asset-administration-shell-package</string>
        </dict>
    </dict>
</array>
```

**Step 2: Verify compilation**

Run: Build project (Cmd+B)
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add Info.plist
git commit -m "feat(aasx): Register AASX UTType for file picker support"
```

---

## Task 12: Add Files to Xcode Project

**Files:**
- Modify: Xcode project (via Xcode UI)

**Step 1: Add new files to project**

In Xcode:
1. Right-click on `Domain/Models` → Add Files to "TwinAct Field Companion"
2. Select `Domain/Models/AASX/` folder
3. Ensure "Create groups" is selected
4. Add to target: TwinAct Field Companion

Repeat for:
- `Domain/Services/AASX/` folder
- `Core/UI/Components/AASXImportView.swift`

**Step 2: Verify build**

Run: Build project (Cmd+B)
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add -A
git commit -m "chore: Add AASX files to Xcode project"
```

---

## Task 13: Test with Sample AASX File

**Step 1: Build and run app**

Run: Build and run on simulator (Cmd+R)

**Step 2: Test file import**

1. Open PassportView for any asset
2. Tap import button (↓ icon) in toolbar
3. Select "Import from Files"
4. Navigate to sample AASX file in Downloads
5. Select and import

**Step 3: Verify content displays**

Expected:
- Asset thumbnail updates to show extracted image
- No errors in console
- Import completes successfully

**Step 4: Commit test confirmation**

```bash
git commit --allow-empty -m "test: Verified AASX import with sample file"
```

---

## Summary

| Task | Description | Files |
|------|-------------|-------|
| 1 | Add SPM dependencies | Project file |
| 2 | Create AASX data models | AASXModels.swift |
| 3 | Create OPC relationship parser | OPCRelationship.swift |
| 4 | Create content store | AASXContentStore.swift |
| 5 | Create AASX parser | AASXParser.swift |
| 6 | Create import manager | AASXImportManager.swift |
| 7 | Add model extensions | AssetModel.swift, DigitalNameplate.swift |
| 8 | Create import UI | AASXImportView.swift |
| 9 | Update AssetHeaderView | AssetHeaderView.swift |
| 10 | Add import menu | PassportView.swift |
| 11 | Register UTType | Info.plist |
| 12 | Add to Xcode project | Project file |
| 13 | Test with sample file | Manual test |

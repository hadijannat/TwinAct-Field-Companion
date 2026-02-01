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

    // MARK: - Errors

    public enum AASXContentStoreError: Error {
        case baseDirectoryUnavailable
        case createDirectoryFailed(underlying: Error)
    }

    // MARK: - Singleton

    public static let shared = AASXContentStore()

    // MARK: - Properties

    private let fileManager = FileManager.default
    private let logger = Logger(
        subsystem: AppConfiguration.AppInfo.bundleIdentifier,
        category: "AASXContentStore"
    )

    /// Base directory for all AASX content
    private let baseDirectory: URL
    private let usesTemporaryDirectory: Bool
    private var isAvailable: Bool = true

    // MARK: - Initialization

    private init() {
        if let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            baseDirectory = documents.appendingPathComponent("AASXContent", isDirectory: true)
            usesTemporaryDirectory = false
        } else {
            baseDirectory = fileManager.temporaryDirectory.appendingPathComponent("AASXContent", isDirectory: true)
            usesTemporaryDirectory = true
            logger.error("Documents directory unavailable; falling back to temporary directory for AASX content.")
        }
        createBaseDirectoryIfNeeded()
        if usesTemporaryDirectory {
            logger.warning("AASX content is stored in a temporary directory and may be purged by the system.")
        }
    }

    // MARK: - Public Methods

    /// Store parsed AASX content
    /// - Parameter result: Parse result to store
    /// - Returns: URL to the asset's content directory
    public func store(_ result: AASXParseResult) throws -> URL {
        try ensureBaseDirectoryAvailable()
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
        try ensureBaseDirectoryAvailable()
        let assetDir = assetDirectory(for: assetId)
        let targetDir: URL

        if subdirectory.isEmpty {
            targetDir = assetDir
        } else {
            targetDir = assetDir.appendingPathComponent(subdirectory, isDirectory: true)
        }

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
            let mimeType = Self.mimeType(for: url)
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
        guard isAvailable else { return false }
        let assetDir = assetDirectory(for: assetId)
        return fileManager.fileExists(atPath: assetDir.path)
    }

    /// Delete content for asset
    public func deleteContent(for assetId: String) throws {
        try ensureBaseDirectoryAvailable()
        let assetDir = assetDirectory(for: assetId)
        if fileManager.fileExists(atPath: assetDir.path) {
            try fileManager.removeItem(at: assetDir)
            logger.info("Deleted content for asset: \(assetId)")
        }
    }

    /// Get total storage used by all AASX content
    public func totalStorageUsed() -> Int64 {
        guard isAvailable else { return 0 }
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
        guard isAvailable else { return [] }
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

    // MARK: - Enhanced Content Access

    /// Get all images for asset, categorized by type.
    /// - Parameter assetId: Asset identifier
    /// - Returns: Array of categorized image items
    public func images(for assetId: String) -> [AASXImageItem] {
        var items: [AASXImageItem] = []

        // Product images
        let productImgs = productImages(for: assetId)
        items += productImgs.map { AASXImageItem(url: $0, category: .product) }

        // Certification markings
        let markings = markingURLs(for: assetId)
        items += markings.map { AASXImageItem(url: $0, category: .certification) }

        // Logos
        if let logo = logoURL(for: assetId) {
            items.append(AASXImageItem(url: logo, category: .logo))
        }

        // Thumbnail (if not already included)
        if let thumb = thumbnailURL(for: assetId), !items.contains(where: { $0.url == thumb }) {
            items.insert(AASXImageItem(url: thumb, category: .thumbnail), at: 0)
        }

        return items
    }

    /// Get CAD files for asset.
    /// - Parameter assetId: Asset identifier
    /// - Returns: Array of CAD file items
    public func cadFiles(for assetId: String) -> [AASXCADFile] {
        let assetDir = assetDirectory(for: assetId)

        // Check multiple locations for CAD files
        let directories = [
            assetDir,
            assetDir.appendingPathComponent("models"),
            assetDir.appendingPathComponent("cad"),
            assetDir.appendingPathComponent("3d")
        ]

        let cadExtensions = ["usdz", "obj", "stl", "step", "stp", "iges", "igs", "gltf", "glb", "fbx"]
        var files: [AASXCADFile] = []

        for dir in directories {
            let found = filesInDirectory(dir, extensions: cadExtensions)
            files += found.map { url in
                let ext = url.pathExtension.lowercased()
                let format = AASXCADFormat.from(extension: ext)
                let fileSize = try? fileManager.attributesOfItem(atPath: url.path)[.size] as? Int64
                return AASXCADFile(
                    url: url,
                    format: format,
                    filename: url.lastPathComponent,
                    fileSize: fileSize
                )
            }
        }

        return files
    }

    /// Get the package structure for an asset.
    /// - Parameter assetId: Asset identifier
    /// - Returns: Root node of the package structure tree
    public func packageStructure(for assetId: String) -> AASXPackageNode? {
        let assetDir = assetDirectory(for: assetId)
        guard fileManager.fileExists(atPath: assetDir.path) else { return nil }

        return buildPackageNode(at: assetDir, name: assetId, isRoot: true)
    }

    /// Get the AAS JSON content for an asset.
    /// - Parameter assetId: Asset identifier
    /// - Returns: Parsed JSON dictionary, or nil if not found
    public func aasJSON(for assetId: String) -> [String: Any]? {
        let assetDir = assetDirectory(for: assetId)

        // Common locations for AAS JSON
        let candidates = [
            assetDir.appendingPathComponent("aas.json"),
            assetDir.appendingPathComponent("aasx/aas.json"),
            assetDir.appendingPathComponent("aas-spec/aas.json"),
            assetDir.appendingPathComponent("shell.json")
        ]

        for candidate in candidates {
            if let data = try? Data(contentsOf: candidate),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                return json
            }
        }

        // Try to find any JSON file that looks like AAS content
        let jsonFiles = filesInDirectory(assetDir, extensions: ["json"])
        for jsonFile in jsonFiles {
            if let data = try? Data(contentsOf: jsonFile),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                // Check if it looks like AAS content
                if json["assetAdministrationShells"] != nil ||
                   json["submodels"] != nil ||
                   json["idShort"] != nil {
                    return json
                }
            }
        }

        return nil
    }

    /// Get the asset directory URL (for direct access when needed).
    /// - Parameter assetId: Asset identifier
    /// - Returns: URL to the asset's content directory
    public func contentDirectory(for assetId: String) -> URL {
        return assetDirectory(for: assetId)
    }

    // MARK: - Private Helper Methods

    /// Recursively build package node tree.
    private func buildPackageNode(at url: URL, name: String, isRoot: Bool) -> AASXPackageNode {
        var isDirectory: ObjCBool = false
        fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory)

        if isDirectory.boolValue {
            let children: [AASXPackageNode]
            if let contents = try? fileManager.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey],
                options: [.skipsHiddenFiles]
            ) {
                children = contents
                    .sorted { $0.lastPathComponent < $1.lastPathComponent }
                    .map { buildPackageNode(at: $0, name: $0.lastPathComponent, isRoot: false) }
            } else {
                children = []
            }

            return AASXPackageNode(
                name: name,
                path: url.path,
                isDirectory: true,
                fileSize: nil,
                children: children,
                fileType: .directory
            )
        } else {
            let fileSize = try? fileManager.attributesOfItem(atPath: url.path)[.size] as? Int64
            let fileType = AASXFileType.from(extension: url.pathExtension.lowercased())

            return AASXPackageNode(
                name: name,
                path: url.path,
                isDirectory: false,
                fileSize: fileSize,
                children: nil,
                fileType: fileType
            )
        }
    }

    // MARK: - Internal Methods

    /// Get MIME type for a file URL
    static func mimeType(for url: URL) -> String {
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
                isAvailable = false
                logger.error("Failed to create base directory: \(error.localizedDescription)")
            }
        }
    }

    private func ensureBaseDirectoryAvailable() throws {
        guard isAvailable else {
            throw AASXContentStoreError.baseDirectoryUnavailable
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
}

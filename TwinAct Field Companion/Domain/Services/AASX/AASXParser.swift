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
        let archive: Archive
        do {
            archive = try Archive(url: url, accessMode: .read, pathEncoding: nil)
        } catch {
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
        let archive: Archive
        do {
            archive = try Archive(url: url, accessMode: .read, pathEncoding: nil)
        } catch {
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
                        mimeType: AASXContentStore.mimeType(for: url),
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

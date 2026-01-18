//
//  CachedDocument.swift
//  TwinAct Field Companion
//
//  SwiftData model for cached document files
//

import Foundation
import SwiftData

// MARK: - Cached Document Model

/// Cached document file for offline access
///
/// Stores metadata about documents that have been downloaded
/// for offline viewing. The actual file content is stored in
/// the app's document directory, referenced by localPath.
@Model
public final class CachedDocument {

    // MARK: - Properties

    /// Document ID from AAS (primary identifier)
    @Attribute(.unique)
    public var id: String

    /// Parent AAS ID
    public var aasId: String

    /// Parent submodel ID
    public var submodelId: String

    /// Document title/name
    public var title: String

    /// MIME type of the document
    public var fileType: String

    /// File size in bytes
    public var fileSize: Int

    /// Path to the file in app's document directory
    public var localPath: String

    /// Original remote URL
    public var remoteURL: String

    /// When the document was downloaded
    public var downloadedAt: Date

    /// When the document was last accessed
    public var lastAccessedAt: Date

    /// Number of times the document has been viewed
    public var viewCount: Int

    /// Whether the document is marked as favorite
    public var isFavorite: Bool

    /// Document description (if available)
    public var documentDescription: String?

    /// Document version (if available)
    public var version: String?

    /// Language of the document
    public var language: String?

    /// Hash of the file content for integrity verification
    public var contentHash: String?

    /// ETag from server for cache validation
    public var etag: String?

    // MARK: - Initialization

    public init(
        id: String,
        aasId: String,
        submodelId: String,
        title: String,
        fileType: String,
        fileSize: Int,
        localPath: String,
        remoteURL: String
    ) {
        self.id = id
        self.aasId = aasId
        self.submodelId = submodelId
        self.title = title
        self.fileType = fileType
        self.fileSize = fileSize
        self.localPath = localPath
        self.remoteURL = remoteURL
        self.downloadedAt = Date()
        self.lastAccessedAt = Date()
        self.viewCount = 0
        self.isFavorite = false
    }

    // MARK: - Computed Properties

    /// File extension derived from MIME type or title
    public var fileExtension: String {
        // Try to get from title first
        if let ext = title.split(separator: ".").last {
            return String(ext).lowercased()
        }
        // Fall back to MIME type mapping
        return Self.extensionForMIMEType(fileType)
    }

    /// Human-readable file size
    public var formattedFileSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(fileSize), countStyle: .file)
    }

    /// Full local file URL
    public var localURL: URL? {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        return documentsPath?.appendingPathComponent(localPath)
    }

    /// Whether the local file exists
    public var localFileExists: Bool {
        guard let url = localURL else { return false }
        return FileManager.default.fileExists(atPath: url.path)
    }

    /// Age of the cached document in days
    public var ageInDays: Int {
        let days = Calendar.current.dateComponents([.day], from: downloadedAt, to: Date()).day ?? 0
        return days
    }

    /// Whether this is a PDF document
    public var isPDF: Bool {
        fileType == "application/pdf" || fileExtension == "pdf"
    }

    /// Whether this is an image
    public var isImage: Bool {
        fileType.hasPrefix("image/")
    }

    /// Whether this is a video
    public var isVideo: Bool {
        fileType.hasPrefix("video/")
    }

    // MARK: - Methods

    /// Record a view of this document
    public func recordView() {
        viewCount += 1
        lastAccessedAt = Date()
    }

    /// Toggle favorite status
    public func toggleFavorite() {
        isFavorite.toggle()
    }

    /// Delete the local file
    public func deleteLocalFile() throws {
        guard let url = localURL else { return }
        try FileManager.default.removeItem(at: url)
    }

    // MARK: - Static Helpers

    /// Get file extension for a MIME type
    public static func extensionForMIMEType(_ mimeType: String) -> String {
        let mapping: [String: String] = [
            "application/pdf": "pdf",
            "image/jpeg": "jpg",
            "image/png": "png",
            "image/gif": "gif",
            "image/svg+xml": "svg",
            "video/mp4": "mp4",
            "video/quicktime": "mov",
            "text/plain": "txt",
            "text/html": "html",
            "application/json": "json",
            "application/xml": "xml",
            "application/zip": "zip",
            "application/msword": "doc",
            "application/vnd.openxmlformats-officedocument.wordprocessingml.document": "docx",
            "application/vnd.ms-excel": "xls",
            "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet": "xlsx",
            "application/vnd.ms-powerpoint": "ppt",
            "application/vnd.openxmlformats-officedocument.presentationml.presentation": "pptx"
        ]
        return mapping[mimeType] ?? "dat"
    }

    /// Generate a unique local filename for a document
    public static func generateLocalFilename(documentId: String, extension ext: String) -> String {
        let sanitizedId = documentId.replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
        return "doc_\(sanitizedId).\(ext)"
    }
}

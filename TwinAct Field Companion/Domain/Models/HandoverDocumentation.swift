//
//  HandoverDocumentation.swift
//  TwinAct Field Companion
//
//  Handover Documentation domain model per IDTA 02004-1-2.
//  Product documentation and manuals.
//  READ ONLY - This submodel cannot be modified by the app.
//

import Foundation

// MARK: - Handover Documentation

/// Handover Documentation per IDTA 02004-1-2
/// Contains product documentation and manuals.
/// This is a read-only submodel.
public struct HandoverDocumentation: Codable, Sendable, Hashable {
    /// Collection of documents
    public let documents: [Document]

    public init(documents: [Document] = []) {
        self.documents = documents
    }
}

// MARK: - Document

/// A single document in the handover documentation.
public struct Document: Codable, Sendable, Hashable, Identifiable {
    /// Unique document identifier
    public let id: String

    /// Document title in multiple languages
    public let title: [LangString]

    /// Brief summary of document contents
    public let summary: [LangString]?

    /// Classification per VDI 2770 / ECLASS
    public let documentClass: DocumentClass

    /// Version of the document
    public let documentVersion: String?

    /// Languages available in the document (ISO 639-1 codes)
    public let language: [String]?

    /// Associated digital files
    public let digitalFile: [DigitalFile]?

    /// Document keywords for search
    public let keywords: [LangString]?

    /// Date when document was created or last modified
    public let documentDate: Date?

    /// Organization that created the document
    public let organization: String?

    public init(
        id: String,
        title: [LangString],
        summary: [LangString]? = nil,
        documentClass: DocumentClass,
        documentVersion: String? = nil,
        language: [String]? = nil,
        digitalFile: [DigitalFile]? = nil,
        keywords: [LangString]? = nil,
        documentDate: Date? = nil,
        organization: String? = nil
    ) {
        self.id = id
        self.title = title
        self.summary = summary
        self.documentClass = documentClass
        self.documentVersion = documentVersion
        self.language = language
        self.digitalFile = digitalFile
        self.keywords = keywords
        self.documentDate = documentDate
        self.organization = organization
    }

    /// Get title for a specific language
    public func title(for languageCode: String) -> String? {
        title.text(for: languageCode)
    }

    /// Get summary for a specific language
    public func summary(for languageCode: String) -> String? {
        summary?.text(for: languageCode)
    }
}

// MARK: - Document Class

/// Document classification per VDI 2770 / ECLASS standards.
public enum DocumentClass: String, Codable, Sendable, CaseIterable {
    // Primary documentation types
    case operatingManual = "02-01"
    case assemblyInstructions = "02-02"
    case safetyInstructions = "02-03"
    case maintenanceInstructions = "02-04"
    case technicalDrawing = "03-01"
    case certificate = "03-02"
    case declaration = "03-03"
    case testReport = "03-04"

    // Additional common types
    case datasheet = "01-01"
    case brochure = "01-02"
    case spareParts = "02-05"
    case troubleshooting = "02-06"
    case circuitDiagram = "03-05"
    case installationPlan = "03-06"
    case contractDocumentation = "04-01"
    case other = "99-99"

    /// Human-readable display name
    public var displayName: String {
        switch self {
        case .operatingManual: return "Operating Manual"
        case .assemblyInstructions: return "Assembly Instructions"
        case .safetyInstructions: return "Safety Instructions"
        case .maintenanceInstructions: return "Maintenance Instructions"
        case .technicalDrawing: return "Technical Drawing"
        case .certificate: return "Certificate"
        case .declaration: return "Declaration"
        case .testReport: return "Test Report"
        case .datasheet: return "Datasheet"
        case .brochure: return "Brochure"
        case .spareParts: return "Spare Parts List"
        case .troubleshooting: return "Troubleshooting Guide"
        case .circuitDiagram: return "Circuit Diagram"
        case .installationPlan: return "Installation Plan"
        case .contractDocumentation: return "Contract Documentation"
        case .other: return "Other"
        }
    }

    /// SF Symbol icon name for the document class
    public var iconName: String {
        switch self {
        case .operatingManual: return "book.fill"
        case .assemblyInstructions: return "wrench.and.screwdriver.fill"
        case .safetyInstructions: return "exclamationmark.shield.fill"
        case .maintenanceInstructions: return "gearshape.fill"
        case .technicalDrawing: return "ruler.fill"
        case .certificate: return "checkmark.seal.fill"
        case .declaration: return "doc.text.fill"
        case .testReport: return "chart.bar.doc.horizontal.fill"
        case .datasheet: return "doc.richtext.fill"
        case .brochure: return "magazine.fill"
        case .spareParts: return "list.bullet.rectangle.fill"
        case .troubleshooting: return "questionmark.circle.fill"
        case .circuitDiagram: return "bolt.circle.fill"
        case .installationPlan: return "map.fill"
        case .contractDocumentation: return "signature"
        case .other: return "doc.fill"
        }
    }
}

// MARK: - Digital File

/// A digital file associated with a document.
public struct DigitalFile: Codable, Sendable, Hashable {
    /// Preview/thumbnail file URL
    public let previewFile: URL?

    /// MIME type of the file (e.g., "application/pdf")
    public let fileFormat: String

    /// Actual file URL
    public let file: URL

    /// File size in bytes (if available)
    public let fileSize: Int64?

    /// File name for display
    public let fileName: String?

    public init(
        previewFile: URL? = nil,
        fileFormat: String,
        file: URL,
        fileSize: Int64? = nil,
        fileName: String? = nil
    ) {
        self.previewFile = previewFile
        self.fileFormat = fileFormat
        self.file = file
        self.fileSize = fileSize
        self.fileName = fileName
    }

    /// Whether this file is a PDF
    public var isPDF: Bool {
        fileFormat.lowercased().contains("pdf")
    }

    /// Whether this file is an image
    public var isImage: Bool {
        fileFormat.lowercased().hasPrefix("image/")
    }

    /// Formatted file size string (e.g., "2.5 MB")
    public var formattedFileSize: String? {
        guard let size = fileSize else { return nil }

        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}

// MARK: - IDTA Semantic IDs

extension HandoverDocumentation {
    /// IDTA semantic ID for Handover Documentation submodel
    public static let semanticId = "https://admin-shell.io/ZVEI/HandoverDocumentation/1/2/Submodel"

    /// Alternative semantic ID (version 1.1)
    public static let semanticIdV11 = "https://admin-shell.io/ZVEI/HandoverDocumentation/1/1/Submodel"
}

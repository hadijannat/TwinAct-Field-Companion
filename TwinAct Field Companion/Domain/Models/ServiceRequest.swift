//
//  ServiceRequest.swift
//  TwinAct Field Companion
//
//  Service Request domain model per IDTA 02010.
//  READ + WRITE - This is the ONLY submodel the app can write to.
//

import Foundation

// MARK: - Service Request

/// Service Request per IDTA 02010
/// This is the ONLY submodel the app can write to.
public struct ServiceRequest: Codable, Sendable, Hashable, Identifiable {
    /// Unique request identifier (generated)
    public let id: String

    /// Current status of the request
    public var status: ServiceRequestStatus

    /// Priority level
    public var priority: ServiceRequestPriority

    /// Category of service request
    public var category: ServiceRequestCategory

    /// Brief title/subject
    public var title: String

    /// Detailed description of the issue/request
    public var description: String

    /// Date and time when request was created
    public var requestDate: Date

    /// Name of the person making the request
    public var requesterName: String?

    /// Email of the requester
    public var requesterEmail: String?

    /// Phone number of the requester
    public var requesterPhone: String?

    /// URLs to attached files/images
    public var attachments: [URL]?

    /// Service notes and updates
    public var notes: [ServiceNote]?

    /// Asset identifier this request is for
    public var assetId: String?

    /// Location/site information
    public var location: String?

    /// Scheduled service date (if applicable)
    public var scheduledDate: Date?

    /// Date when request was completed
    public var completedDate: Date?

    /// Assigned technician/team
    public var assignedTo: String?

    // MARK: - Initialization

    /// Create a new service request
    public init(
        title: String,
        description: String,
        category: ServiceRequestCategory,
        priority: ServiceRequestPriority = .normal,
        assetId: String? = nil,
        location: String? = nil
    ) {
        self.id = UUID().uuidString
        self.status = .new
        self.priority = priority
        self.category = category
        self.title = title
        self.description = description
        self.requestDate = Date()
        self.assetId = assetId
        self.location = location
        self.requesterName = nil
        self.requesterEmail = nil
        self.requesterPhone = nil
        self.attachments = nil
        self.notes = nil
        self.scheduledDate = nil
        self.completedDate = nil
        self.assignedTo = nil
    }

    /// Full initializer for deserialization
    public init(
        id: String,
        status: ServiceRequestStatus,
        priority: ServiceRequestPriority,
        category: ServiceRequestCategory,
        title: String,
        description: String,
        requestDate: Date,
        requesterName: String? = nil,
        requesterEmail: String? = nil,
        requesterPhone: String? = nil,
        attachments: [URL]? = nil,
        notes: [ServiceNote]? = nil,
        assetId: String? = nil,
        location: String? = nil,
        scheduledDate: Date? = nil,
        completedDate: Date? = nil,
        assignedTo: String? = nil
    ) {
        self.id = id
        self.status = status
        self.priority = priority
        self.category = category
        self.title = title
        self.description = description
        self.requestDate = requestDate
        self.requesterName = requesterName
        self.requesterEmail = requesterEmail
        self.requesterPhone = requesterPhone
        self.attachments = attachments
        self.notes = notes
        self.assetId = assetId
        self.location = location
        self.scheduledDate = scheduledDate
        self.completedDate = completedDate
        self.assignedTo = assignedTo
    }

    // MARK: - Methods

    /// Add a note to the service request
    public mutating func addNote(author: String, text: String) {
        let note = ServiceNote(timestamp: Date(), author: author, text: text)
        if notes == nil {
            notes = []
        }
        notes?.append(note)
    }

    /// Add an attachment URL
    public mutating func addAttachment(_ url: URL) {
        if attachments == nil {
            attachments = []
        }
        attachments?.append(url)
    }

    /// Update the status
    public mutating func updateStatus(_ newStatus: ServiceRequestStatus) {
        status = newStatus
        if newStatus == .resolved || newStatus == .closed {
            completedDate = Date()
        }
    }

    /// Whether the request is still open
    public var isOpen: Bool {
        status == .new || status == .inProgress || status == .onHold
    }

    /// Whether the request is urgent
    public var isUrgent: Bool {
        priority == .urgent || priority == .high
    }

    /// Time since request was created
    public var age: TimeInterval {
        Date().timeIntervalSince(requestDate)
    }

    /// Formatted age string (e.g., "2 days ago")
    public var formattedAge: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: requestDate, relativeTo: Date())
    }
}

// MARK: - Service Request Status

/// Status of a service request.
public enum ServiceRequestStatus: String, Codable, Sendable, CaseIterable {
    /// Newly created, not yet reviewed
    case new = "New"

    /// Being actively worked on
    case inProgress = "InProgress"

    /// Temporarily paused
    case onHold = "OnHold"

    /// Issue resolved
    case resolved = "Resolved"

    /// Fully closed
    case closed = "Closed"

    /// Human-readable display name
    public var displayName: String {
        switch self {
        case .new: return "New"
        case .inProgress: return "In Progress"
        case .onHold: return "On Hold"
        case .resolved: return "Resolved"
        case .closed: return "Closed"
        }
    }

    /// SF Symbol icon name
    public var iconName: String {
        switch self {
        case .new: return "circle"
        case .inProgress: return "clock.fill"
        case .onHold: return "pause.circle.fill"
        case .resolved: return "checkmark.circle.fill"
        case .closed: return "xmark.circle.fill"
        }
    }

    /// Color name for status display
    public var colorName: String {
        switch self {
        case .new: return "blue"
        case .inProgress: return "orange"
        case .onHold: return "yellow"
        case .resolved: return "green"
        case .closed: return "gray"
        }
    }
}

// MARK: - Service Request Priority

/// Priority level of a service request.
public enum ServiceRequestPriority: String, Codable, Sendable, CaseIterable {
    case low = "Low"
    case normal = "Normal"
    case high = "High"
    case urgent = "Urgent"

    /// Human-readable display name
    public var displayName: String {
        rawValue
    }

    /// SF Symbol icon name
    public var iconName: String {
        switch self {
        case .low: return "arrow.down.circle"
        case .normal: return "minus.circle"
        case .high: return "arrow.up.circle"
        case .urgent: return "exclamationmark.triangle.fill"
        }
    }

    /// Numeric value for sorting (higher = more urgent)
    public var sortOrder: Int {
        switch self {
        case .low: return 0
        case .normal: return 1
        case .high: return 2
        case .urgent: return 3
        }
    }
}

// MARK: - Service Request Category

/// Category of service request.
public enum ServiceRequestCategory: String, Codable, Sendable, CaseIterable {
    case maintenance = "Maintenance"
    case repair = "Repair"
    case inspection = "Inspection"
    case calibration = "Calibration"
    case replacement = "Replacement"
    case installation = "Installation"
    case consultation = "Consultation"
    case training = "Training"
    case other = "Other"

    /// Human-readable display name
    public var displayName: String {
        rawValue
    }

    /// SF Symbol icon name
    public var iconName: String {
        switch self {
        case .maintenance: return "wrench.and.screwdriver.fill"
        case .repair: return "hammer.fill"
        case .inspection: return "magnifyingglass"
        case .calibration: return "ruler.fill"
        case .replacement: return "arrow.triangle.2.circlepath"
        case .installation: return "square.and.arrow.down.fill"
        case .consultation: return "bubble.left.and.bubble.right.fill"
        case .training: return "book.fill"
        case .other: return "ellipsis.circle.fill"
        }
    }
}

// MARK: - Service Note

/// A note or update on a service request.
public struct ServiceNote: Codable, Sendable, Hashable {
    /// When the note was created
    public let timestamp: Date

    /// Who created the note
    public let author: String

    /// Note content
    public let text: String

    /// Whether this note is internal only
    public let isInternal: Bool

    public init(
        timestamp: Date,
        author: String,
        text: String,
        isInternal: Bool = false
    ) {
        self.timestamp = timestamp
        self.author = author
        self.text = text
        self.isInternal = isInternal
    }

    /// Formatted timestamp string
    public var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
}

// MARK: - IDTA Semantic IDs

extension ServiceRequest {
    /// IDTA semantic ID for Service Request submodel
    public static let semanticId = "https://admin-shell.io/idta/ServiceRequest/1/0/Submodel"
}

// MARK: - Service Request Builder

/// Builder pattern for creating service requests with fluent API.
public struct ServiceRequestBuilder {
    private var request: ServiceRequest

    public init(title: String, description: String, category: ServiceRequestCategory) {
        self.request = ServiceRequest(
            title: title,
            description: description,
            category: category
        )
    }

    public func priority(_ priority: ServiceRequestPriority) -> ServiceRequestBuilder {
        var builder = self
        builder.request.priority = priority
        return builder
    }

    public func requester(name: String?, email: String?, phone: String?) -> ServiceRequestBuilder {
        var builder = self
        builder.request.requesterName = name
        builder.request.requesterEmail = email
        builder.request.requesterPhone = phone
        return builder
    }

    public func asset(_ assetId: String) -> ServiceRequestBuilder {
        var builder = self
        builder.request.assetId = assetId
        return builder
    }

    public func location(_ location: String) -> ServiceRequestBuilder {
        var builder = self
        builder.request.location = location
        return builder
    }

    public func build() -> ServiceRequest {
        request
    }
}

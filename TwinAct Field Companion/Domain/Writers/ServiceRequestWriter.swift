//
//  ServiceRequestWriter.swift
//  TwinAct Field Companion
//
//  Converts ServiceRequest domain model to AAS SubmodelElement structure for API writes.
//  ServiceRequest is the ONLY submodel the app can write to.
//

import Foundation

// MARK: - Writer Errors

/// Errors that can occur during service request writing.
public enum ServiceRequestWriterError: Error, LocalizedError {
    case serializationFailed(String)
    case invalidData(String)
    case encodingFailed(Error)

    public var errorDescription: String? {
        switch self {
        case .serializationFailed(let reason):
            return "Serialization failed: \(reason)"
        case .invalidData(let reason):
            return "Invalid data: \(reason)"
        case .encodingFailed(let error):
            return "Encoding failed: \(error.localizedDescription)"
        }
    }
}

// MARK: - Service Request Writer

/// Converts ServiceRequest domain model to AAS SubmodelElement structure.
public struct ServiceRequestWriter {

    // MARK: - To SubmodelElement

    /// Convert a ServiceRequest to a SubmodelElementCollection for creating via API.
    public static func toSubmodelElement(_ request: ServiceRequest) -> SubmodelElement {
        var elements: [SubmodelElement] = []

        // Request ID
        elements.append(.property(Property(
            idShort: "RequestId",
            valueType: .string,
            value: request.id,
            semanticId: Reference.globalReference("https://admin-shell.io/idta/ServiceRequest/RequestId/1/0")
        )))

        // Status
        elements.append(.property(Property(
            idShort: "Status",
            valueType: .string,
            value: request.status.rawValue,
            semanticId: Reference.globalReference("https://admin-shell.io/idta/ServiceRequest/Status/1/0")
        )))

        // Priority
        elements.append(.property(Property(
            idShort: "Priority",
            valueType: .string,
            value: request.priority.rawValue,
            semanticId: Reference.globalReference("https://admin-shell.io/idta/ServiceRequest/Priority/1/0")
        )))

        // Category
        elements.append(.property(Property(
            idShort: "Category",
            valueType: .string,
            value: request.category.rawValue,
            semanticId: Reference.globalReference("https://admin-shell.io/idta/ServiceRequest/Category/1/0")
        )))

        // Title
        elements.append(.property(Property(
            idShort: "Title",
            valueType: .string,
            value: request.title,
            semanticId: Reference.globalReference("https://admin-shell.io/idta/ServiceRequest/Title/1/0")
        )))

        // Description
        elements.append(.property(Property(
            idShort: "Description",
            valueType: .string,
            value: request.description,
            semanticId: Reference.globalReference("https://admin-shell.io/idta/ServiceRequest/Description/1/0")
        )))

        // Request Date
        let dateFormatter = ISO8601DateFormatter()
        elements.append(.property(Property(
            idShort: "RequestDate",
            valueType: .dateTime,
            value: dateFormatter.string(from: request.requestDate),
            semanticId: Reference.globalReference("https://admin-shell.io/idta/ServiceRequest/RequestDate/1/0")
        )))

        // Optional Requester Information
        if let requesterName = request.requesterName {
            elements.append(.property(Property(
                idShort: "RequesterName",
                valueType: .string,
                value: requesterName
            )))
        }

        if let requesterEmail = request.requesterEmail {
            elements.append(.property(Property(
                idShort: "RequesterEmail",
                valueType: .string,
                value: requesterEmail
            )))
        }

        if let requesterPhone = request.requesterPhone {
            elements.append(.property(Property(
                idShort: "RequesterPhone",
                valueType: .string,
                value: requesterPhone
            )))
        }

        // Optional Asset ID
        if let assetId = request.assetId {
            elements.append(.property(Property(
                idShort: "AssetId",
                valueType: .string,
                value: assetId
            )))
        }

        // Optional Location
        if let location = request.location {
            elements.append(.property(Property(
                idShort: "Location",
                valueType: .string,
                value: location
            )))
        }

        // Optional Scheduled Date
        if let scheduledDate = request.scheduledDate {
            elements.append(.property(Property(
                idShort: "ScheduledDate",
                valueType: .dateTime,
                value: dateFormatter.string(from: scheduledDate)
            )))
        }

        // Optional Completed Date
        if let completedDate = request.completedDate {
            elements.append(.property(Property(
                idShort: "CompletedDate",
                valueType: .dateTime,
                value: dateFormatter.string(from: completedDate)
            )))
        }

        // Optional Assigned To
        if let assignedTo = request.assignedTo {
            elements.append(.property(Property(
                idShort: "AssignedTo",
                valueType: .string,
                value: assignedTo
            )))
        }

        // Attachments (as SubmodelElementList of Files)
        if let attachments = request.attachments, !attachments.isEmpty {
            var fileElements: [SubmodelElement] = []
            for (index, url) in attachments.enumerated() {
                fileElements.append(.file(AASFile(
                    idShort: "Attachment\(index + 1)",
                    contentType: mimeType(for: url),
                    value: url.absoluteString
                )))
            }
            elements.append(.submodelElementList(SubmodelElementList(
                idShort: "Attachments",
                typeValueListElement: .file,
                value: fileElements
            )))
        }

        // Notes (as SubmodelElementList of Collections)
        if let notes = request.notes, !notes.isEmpty {
            var noteElements: [SubmodelElement] = []
            for (index, note) in notes.enumerated() {
                noteElements.append(noteToSubmodelElement(note, index: index))
            }
            elements.append(.submodelElementList(SubmodelElementList(
                idShort: "Notes",
                typeValueListElement: .submodelElementCollection,
                value: noteElements
            )))
        }

        return .submodelElementCollection(SubmodelElementCollection(
            idShort: "ServiceRequest_\(request.id)",
            value: elements,
            semanticId: Reference.globalReference(ServiceRequest.semanticId)
        ))
    }

    private static func noteToSubmodelElement(_ note: ServiceNote, index: Int) -> SubmodelElement {
        let dateFormatter = ISO8601DateFormatter()

        return .submodelElementCollection(SubmodelElementCollection(
            idShort: "Note\(index + 1)",
            value: [
                .property(Property(
                    idShort: "Timestamp",
                    valueType: .dateTime,
                    value: dateFormatter.string(from: note.timestamp)
                )),
                .property(Property(
                    idShort: "Author",
                    valueType: .string,
                    value: note.author
                )),
                .property(Property(
                    idShort: "Text",
                    valueType: .string,
                    value: note.text
                )),
                .property(Property(
                    idShort: "IsInternal",
                    valueType: .boolean,
                    value: note.isInternal ? "true" : "false"
                ))
            ]
        ))
    }

    // MARK: - To API Body

    /// Convert a ServiceRequest to JSON body for API POST/PUT.
    public static func toAPIBody(_ request: ServiceRequest) throws -> Data {
        let submodelElement = toSubmodelElement(request)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        do {
            return try encoder.encode(submodelElement)
        } catch {
            throw ServiceRequestWriterError.encodingFailed(error)
        }
    }

    /// Convert a ServiceRequest to a dictionary for API requests.
    public static func toDictionary(_ request: ServiceRequest) -> [String: Any] {
        var dict: [String: Any] = [
            "RequestId": request.id,
            "Status": request.status.rawValue,
            "Priority": request.priority.rawValue,
            "Category": request.category.rawValue,
            "Title": request.title,
            "Description": request.description,
            "RequestDate": ISO8601DateFormatter().string(from: request.requestDate)
        ]

        if let requesterName = request.requesterName {
            dict["RequesterName"] = requesterName
        }
        if let requesterEmail = request.requesterEmail {
            dict["RequesterEmail"] = requesterEmail
        }
        if let requesterPhone = request.requesterPhone {
            dict["RequesterPhone"] = requesterPhone
        }
        if let assetId = request.assetId {
            dict["AssetId"] = assetId
        }
        if let location = request.location {
            dict["Location"] = location
        }
        if let scheduledDate = request.scheduledDate {
            dict["ScheduledDate"] = ISO8601DateFormatter().string(from: scheduledDate)
        }
        if let completedDate = request.completedDate {
            dict["CompletedDate"] = ISO8601DateFormatter().string(from: completedDate)
        }
        if let assignedTo = request.assignedTo {
            dict["AssignedTo"] = assignedTo
        }
        if let attachments = request.attachments {
            dict["Attachments"] = attachments.map { $0.absoluteString }
        }
        if let notes = request.notes {
            dict["Notes"] = notes.map { note in
                [
                    "Timestamp": ISO8601DateFormatter().string(from: note.timestamp),
                    "Author": note.author,
                    "Text": note.text,
                    "IsInternal": note.isInternal
                ] as [String: Any]
            }
        }

        return dict
    }

    // MARK: - To Submodel

    /// Create a complete Submodel containing the ServiceRequest.
    public static func toSubmodel(_ request: ServiceRequest, submodelId: String? = nil) -> Submodel {
        let element = toSubmodelElement(request)

        // Extract the collection value
        var elements: [SubmodelElement] = []
        if case .submodelElementCollection(let collection) = element {
            elements = collection.value ?? []
        }

        return Submodel(
            id: submodelId ?? "urn:twinact:serviceRequest:\(request.id)",
            idShort: "ServiceRequest",
            semanticId: Reference.globalReference(ServiceRequest.semanticId),
            description: [LangString(language: "en", text: "Service Request: \(request.title)")],
            submodelElements: elements
        )
    }

    // MARK: - Property Updates

    /// Create a property value update for a specific field.
    public static func toPropertyUpdate(field: ServiceRequestField, value: String) -> PropertyValueUpdate {
        PropertyValueUpdate(value: value)
    }

    /// Create the idShort path for a specific field.
    public static func propertyPath(for field: ServiceRequestField) -> String {
        switch field {
        case .status: return "Status"
        case .priority: return "Priority"
        case .title: return "Title"
        case .description: return "Description"
        case .assignedTo: return "AssignedTo"
        case .scheduledDate: return "ScheduledDate"
        case .completedDate: return "CompletedDate"
        case .location: return "Location"
        }
    }

    // MARK: - Helpers

    /// Determine MIME type from URL.
    private static func mimeType(for url: URL) -> String {
        let pathExtension = url.pathExtension.lowercased()

        switch pathExtension {
        case "pdf": return "application/pdf"
        case "jpg", "jpeg": return "image/jpeg"
        case "png": return "image/png"
        case "gif": return "image/gif"
        case "doc": return "application/msword"
        case "docx": return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        case "xls": return "application/vnd.ms-excel"
        case "xlsx": return "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        case "txt": return "text/plain"
        case "json": return "application/json"
        case "xml": return "application/xml"
        case "mp4": return "video/mp4"
        case "mp3": return "audio/mpeg"
        default: return "application/octet-stream"
        }
    }
}

// MARK: - Service Request Field

/// Fields that can be updated in a ServiceRequest.
public enum ServiceRequestField: String, CaseIterable {
    case status
    case priority
    case title
    case description
    case assignedTo
    case scheduledDate
    case completedDate
    case location
}

// MARK: - Service Request Extensions

extension ServiceRequest {
    /// Convert this request to a SubmodelElement.
    public func toSubmodelElement() -> SubmodelElement {
        ServiceRequestWriter.toSubmodelElement(self)
    }

    /// Convert this request to JSON data for API.
    public func toAPIBody() throws -> Data {
        try ServiceRequestWriter.toAPIBody(self)
    }

    /// Convert this request to a dictionary.
    public func toDictionary() -> [String: Any] {
        ServiceRequestWriter.toDictionary(self)
    }

    /// Convert this request to a complete Submodel.
    public func toSubmodel(submodelId: String? = nil) -> Submodel {
        ServiceRequestWriter.toSubmodel(self, submodelId: submodelId)
    }
}

// MARK: - Batch Writer

/// Support for writing multiple service requests.
extension ServiceRequestWriter {

    /// Convert multiple ServiceRequests to a SubmodelElementList.
    public static func toSubmodelElementList(_ requests: [ServiceRequest]) -> SubmodelElement {
        let elements = requests.map { toSubmodelElement($0) }

        return .submodelElementList(SubmodelElementList(
            idShort: "ServiceRequests",
            typeValueListElement: .submodelElementCollection,
            value: elements,
            semanticId: Reference.globalReference(ServiceRequest.semanticId)
        ))
    }

    /// Convert multiple ServiceRequests to JSON array for batch API.
    public static func toAPIBodyArray(_ requests: [ServiceRequest]) throws -> Data {
        let elements = requests.map { toSubmodelElement($0) }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        do {
            return try encoder.encode(elements)
        } catch {
            throw ServiceRequestWriterError.encodingFailed(error)
        }
    }
}

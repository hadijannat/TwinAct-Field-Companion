//
//  APIModels.swift
//  TwinAct Field Companion
//
//  API request/response models for AAS API v3.
//

import Foundation

// MARK: - Paged Result

/// Generic paginated result for AAS API responses.
public struct PagedResult<T: Codable & Sendable>: Codable, Sendable {
    /// The actual result items
    public let result: [T]

    /// Paging metadata
    public let pagingMetadata: PagingMetadata?

    public init(result: [T], pagingMetadata: PagingMetadata? = nil) {
        self.result = result
        self.pagingMetadata = pagingMetadata
    }

    /// Whether there are more results available.
    public var hasMore: Bool {
        pagingMetadata?.cursor != nil
    }

    /// Cursor for the next page, if available.
    public var nextCursor: String? {
        pagingMetadata?.cursor
    }
}

// MARK: - Paging Metadata

/// Paging metadata for paginated results.
public struct PagingMetadata: Codable, Sendable {
    /// Cursor for fetching the next page
    public let cursor: String?

    public init(cursor: String? = nil) {
        self.cursor = cursor
    }
}

// MARK: - Search Request/Response

/// Request body for asset ID lookup in Discovery service.
public struct AssetIdLookupRequest: Codable, Sendable {
    /// Asset IDs to search for
    public let assetIds: [SpecificAssetId]

    public init(assetIds: [SpecificAssetId]) {
        self.assetIds = assetIds
    }
}

/// Response from asset ID lookup.
public struct AssetIdLookupResponse: Codable, Sendable {
    /// Matching AAS identifiers
    public let result: [String]

    /// Paging metadata
    public let pagingMetadata: PagingMetadata?

    public init(result: [String], pagingMetadata: PagingMetadata? = nil) {
        self.result = result
        self.pagingMetadata = pagingMetadata
    }
}

// MARK: - Search Queries

/// Search query for shells.
public struct ShellSearchQuery: Codable, Sendable {
    /// Filter by idShort (partial match)
    public let idShort: String?

    /// Filter by asset kind
    public let assetKind: AssetKind?

    /// Filter by global asset ID
    public let globalAssetId: String?

    /// Filter by specific asset IDs
    public let specificAssetIds: [SpecificAssetId]?

    /// Maximum results to return
    public let limit: Int?

    /// Cursor for pagination
    public let cursor: String?

    public init(
        idShort: String? = nil,
        assetKind: AssetKind? = nil,
        globalAssetId: String? = nil,
        specificAssetIds: [SpecificAssetId]? = nil,
        limit: Int? = nil,
        cursor: String? = nil
    ) {
        self.idShort = idShort
        self.assetKind = assetKind
        self.globalAssetId = globalAssetId
        self.specificAssetIds = specificAssetIds
        self.limit = limit
        self.cursor = cursor
    }

    /// Convert to URL query items.
    public func asQueryItems() -> [URLQueryItem] {
        var items: [URLQueryItem] = []

        if let idShort = idShort {
            items.append(URLQueryItem(name: "idShort", value: idShort))
        }
        if let assetKind = assetKind {
            items.append(URLQueryItem(name: "assetKind", value: assetKind.rawValue))
        }
        if let globalAssetId = globalAssetId {
            items.append(URLQueryItem(name: "globalAssetId", value: globalAssetId))
        }
        if let limit = limit {
            items.append(URLQueryItem(name: "limit", value: String(limit)))
        }
        if let cursor = cursor {
            items.append(URLQueryItem(name: "cursor", value: cursor))
        }

        return items
    }
}

// MARK: - Operation Invocation

/// Request for invoking an operation.
public struct OperationRequest: Codable, Sendable {
    /// Input arguments
    public let inputArguments: [OperationVariable]?

    /// In/out arguments
    public let inoutputArguments: [OperationVariable]?

    /// Client timeout in seconds
    public let clientTimeoutDuration: String?

    public init(
        inputArguments: [OperationVariable]? = nil,
        inoutputArguments: [OperationVariable]? = nil,
        clientTimeoutDuration: String? = nil
    ) {
        self.inputArguments = inputArguments
        self.inoutputArguments = inoutputArguments
        self.clientTimeoutDuration = clientTimeoutDuration
    }
}

/// Result of an operation invocation.
public struct OperationResult: Codable, Sendable {
    /// Output arguments
    public let outputArguments: [OperationVariable]?

    /// In/out arguments
    public let inoutputArguments: [OperationVariable]?

    /// Execution state
    public let executionState: ExecutionState?

    /// Whether execution was successful
    public let success: Bool?

    /// Error messages if any
    public let messages: [OperationMessage]?

    public init(
        outputArguments: [OperationVariable]? = nil,
        inoutputArguments: [OperationVariable]? = nil,
        executionState: ExecutionState? = nil,
        success: Bool? = nil,
        messages: [OperationMessage]? = nil
    ) {
        self.outputArguments = outputArguments
        self.inoutputArguments = inoutputArguments
        self.executionState = executionState
        self.success = success
        self.messages = messages
    }
}

/// Execution state for operation results.
public enum ExecutionState: String, Codable, Sendable {
    case initiated = "Initiated"
    case running = "Running"
    case completed = "Completed"
    case canceled = "Canceled"
    case failed = "Failed"
    case timeout = "Timeout"
}

/// Operation message (for errors/warnings).
public struct OperationMessage: Codable, Sendable {
    public let code: String?
    public let correlationId: String?
    public let messageType: MessageType?
    public let text: String?
    public let timestamp: String?

    public init(
        code: String? = nil,
        correlationId: String? = nil,
        messageType: MessageType? = nil,
        text: String? = nil,
        timestamp: String? = nil
    ) {
        self.code = code
        self.correlationId = correlationId
        self.messageType = messageType
        self.text = text
        self.timestamp = timestamp
    }
}

/// Message type for operation messages.
public enum MessageType: String, Codable, Sendable {
    case undefined = "Undefined"
    case info = "Info"
    case warning = "Warning"
    case error = "Error"
    case exception = "Exception"
}

// MARK: - Service Description

/// AAS server service description.
public struct ServiceDescription: Codable, Sendable {
    /// Supported profiles
    public let profiles: [ServiceProfile]?

    public init(profiles: [ServiceProfile]? = nil) {
        self.profiles = profiles
    }
}

/// Supported service profiles.
public enum ServiceProfile: String, Codable, Sendable {
    case aasRegistryFull = "https://admin-shell.io/aas/API/3/0/AasRegistry-ServiceSpecification/Profile/AssetAdministrationShellRegistryService"
    case aasRegistryRead = "https://admin-shell.io/aas/API/3/0/AasRegistry-ServiceSpecification/Profile/AssetAdministrationShellRegistryService/Read"
    case submodelRegistryFull = "https://admin-shell.io/aas/API/3/0/SubmodelRegistry-ServiceSpecification/Profile/SubmodelRegistryService"
    case submodelRegistryRead = "https://admin-shell.io/aas/API/3/0/SubmodelRegistry-ServiceSpecification/Profile/SubmodelRegistryService/Read"
    case discoveryFull = "https://admin-shell.io/aas/API/3/0/DiscoveryService-ServiceSpecification/Profile/DiscoveryService"
    case discoveryRead = "https://admin-shell.io/aas/API/3/0/DiscoveryService-ServiceSpecification/Profile/DiscoveryService/Read"
    case aasRepositoryFull = "https://admin-shell.io/aas/API/3/0/AasRepository-ServiceSpecification/Profile/AssetAdministrationShellRepositoryService"
    case aasRepositoryRead = "https://admin-shell.io/aas/API/3/0/AasRepository-ServiceSpecification/Profile/AssetAdministrationShellRepositoryService/Read"
    case submodelRepositoryFull = "https://admin-shell.io/aas/API/3/0/SubmodelRepository-ServiceSpecification/Profile/SubmodelRepositoryService"
    case submodelRepositoryRead = "https://admin-shell.io/aas/API/3/0/SubmodelRepository-ServiceSpecification/Profile/SubmodelRepositoryService/Read"
}

// MARK: - Value Only

/// Value-only representation of a property.
public struct PropertyValue: Codable, Sendable {
    public let idShort: String
    public let value: String?

    public init(idShort: String, value: String?) {
        self.idShort = idShort
        self.value = value
    }
}

/// Update request for a property value.
public struct PropertyValueUpdate: Codable, Sendable {
    public let value: String

    public init(value: String) {
        self.value = value
    }
}

// MARK: - Submodel Value

/// Value-only representation of an entire submodel.
public struct SubmodelValue: Codable, Sendable {
    /// Elements as dictionary with idShort keys
    public let values: [String: AnyCodable]

    public init(values: [String: AnyCodable]) {
        self.values = values
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.values = try container.decode([String: AnyCodable].self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(values)
    }
}

// MARK: - AnyCodable Helper

/// Type-erased Codable value for dynamic JSON handling.
public struct AnyCodable: Codable, Hashable {
    public let value: AnyHashable

    public init(_ value: Any) {
        if let hashable = value as? AnyHashable {
            self.value = hashable
        } else {
            self.value = String(describing: value)
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let string = try? container.decode(String.self) {
            self.value = string
        } else if let int = try? container.decode(Int.self) {
            self.value = int
        } else if let double = try? container.decode(Double.self) {
            self.value = double
        } else if let bool = try? container.decode(Bool.self) {
            self.value = bool
        } else if let array = try? container.decode([AnyCodable].self) {
            self.value = array as AnyHashable
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            self.value = dict as AnyHashable
        } else if container.decodeNil() {
            self.value = "null"
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode AnyCodable")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value.base {
        case let string as String:
            try container.encode(string)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let bool as Bool:
            try container.encode(bool)
        case let array as [AnyCodable]:
            try container.encode(array)
        case let dict as [String: AnyCodable]:
            try container.encode(dict)
        default:
            try container.encode(String(describing: value))
        }
    }

    /// Get the value as a specific type.
    public func typedValue<T>() -> T? {
        value.base as? T
    }
}

extension AnyCodable: @unchecked Sendable {}

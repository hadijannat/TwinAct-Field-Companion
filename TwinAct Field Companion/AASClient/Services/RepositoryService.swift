//
//  RepositoryService.swift
//  TwinAct Field Companion
//
//  AAS Repository Service - CRUD for shells and submodels.
//  Implements the AAS API v3 Repository interface.
//

import Foundation
import os.log

// MARK: - Repository Service Protocol

/// AAS Repository Service protocol for CRUD operations on shells and submodels.
public protocol RepositoryServiceProtocol: Sendable {

    // MARK: - Shell Operations

    /// Get all shells (paginated).
    /// - Parameter cursor: Optional cursor for pagination
    /// - Returns: Paginated result of shells
    func getAllShells(cursor: String?) async throws -> PagedResult<AssetAdministrationShell>

    /// Get complete AAS by ID.
    /// - Parameter aasId: The AAS identifier
    /// - Returns: The complete shell
    func getShell(aasId: String) async throws -> AssetAdministrationShell

    /// Create a new shell.
    /// - Parameter shell: The shell to create
    func createShell(_ shell: AssetAdministrationShell) async throws

    /// Update an existing shell.
    /// - Parameters:
    ///   - aasId: The AAS identifier
    ///   - shell: The updated shell
    func updateShell(aasId: String, shell: AssetAdministrationShell) async throws

    /// Delete a shell.
    /// - Parameter aasId: The AAS identifier
    func deleteShell(aasId: String) async throws

    // MARK: - Submodel Operations

    /// Get submodel by ID.
    /// - Parameter submodelId: The submodel identifier
    /// - Returns: The complete submodel
    func getSubmodel(submodelId: String) async throws -> Submodel

    /// Get submodel value-only representation.
    /// - Parameter submodelId: The submodel identifier
    /// - Returns: The submodel value
    func getSubmodelValue(submodelId: String) async throws -> SubmodelValue

    /// Create a new submodel.
    /// - Parameter submodel: The submodel to create
    func createSubmodel(_ submodel: Submodel) async throws

    /// Update an existing submodel.
    /// - Parameters:
    ///   - submodelId: The submodel identifier
    ///   - submodel: The updated submodel
    func updateSubmodel(submodelId: String, submodel: Submodel) async throws

    /// Delete a submodel.
    /// - Parameter submodelId: The submodel identifier
    func deleteSubmodel(submodelId: String) async throws

    // MARK: - Submodel Element Operations

    /// Get all submodel elements.
    /// - Parameter submodelId: The submodel identifier
    /// - Returns: Array of submodel elements
    func getAllSubmodelElements(submodelId: String) async throws -> [SubmodelElement]

    /// Get specific submodel element by path.
    /// - Parameters:
    ///   - submodelId: The submodel identifier
    ///   - idShortPath: The idShort path (e.g., "Collection/Property")
    /// - Returns: The submodel element
    func getSubmodelElement(submodelId: String, idShortPath: String) async throws -> SubmodelElement

    /// Get element value only.
    /// - Parameters:
    ///   - submodelId: The submodel identifier
    ///   - idShortPath: The idShort path
    /// - Returns: Raw value data
    func getSubmodelElementValue(submodelId: String, idShortPath: String) async throws -> Data

    /// Update submodel element value.
    /// - Parameters:
    ///   - submodelId: The submodel identifier
    ///   - idShortPath: The idShort path
    ///   - element: The updated element
    func updateSubmodelElement(submodelId: String, idShortPath: String, element: SubmodelElement) async throws

    /// Update element value only.
    /// - Parameters:
    ///   - submodelId: The submodel identifier
    ///   - idShortPath: The idShort path
    ///   - value: The new value
    func updateSubmodelElementValue(submodelId: String, idShortPath: String, value: String) async throws

    /// Create new submodel element.
    /// - Parameters:
    ///   - submodelId: The submodel identifier
    ///   - element: The element to create
    func createSubmodelElement(submodelId: String, element: SubmodelElement) async throws

    /// Delete a submodel element.
    /// - Parameters:
    ///   - submodelId: The submodel identifier
    ///   - idShortPath: The idShort path
    func deleteSubmodelElement(submodelId: String, idShortPath: String) async throws

    // MARK: - Operation Invocation

    /// Invoke an operation synchronously.
    /// - Parameters:
    ///   - submodelId: The submodel identifier
    ///   - idShortPath: The operation idShort path
    ///   - request: The operation request
    /// - Returns: The operation result
    func invokeOperation(submodelId: String, idShortPath: String, request: OperationRequest) async throws -> OperationResult

    /// Invoke an operation asynchronously.
    /// - Parameters:
    ///   - submodelId: The submodel identifier
    ///   - idShortPath: The operation idShort path
    ///   - request: The operation request
    /// - Returns: Handle ID for checking status
    func invokeOperationAsync(submodelId: String, idShortPath: String, request: OperationRequest) async throws -> String

    /// Get async operation result.
    /// - Parameters:
    ///   - submodelId: The submodel identifier
    ///   - idShortPath: The operation idShort path
    ///   - handleId: The operation handle ID
    /// - Returns: The operation result
    func getOperationResult(submodelId: String, idShortPath: String, handleId: String) async throws -> OperationResult

    // MARK: - File Operations

    /// Get file content from a File element.
    /// - Parameters:
    ///   - submodelId: The submodel identifier
    ///   - idShortPath: The file element idShort path
    /// - Returns: File data and content type
    func getFileContent(submodelId: String, idShortPath: String) async throws -> (data: Data, contentType: String)

    /// Upload file content to a File element.
    /// - Parameters:
    ///   - submodelId: The submodel identifier
    ///   - idShortPath: The file element idShort path
    ///   - data: The file data
    ///   - contentType: The MIME content type
    func uploadFileContent(submodelId: String, idShortPath: String, data: Data, contentType: String) async throws
}

// MARK: - Repository Service Implementation

/// Implementation of AAS Repository Service.
public final class RepositoryService: RepositoryServiceProtocol, @unchecked Sendable {

    // MARK: - Properties

    private let httpClient: HTTPClient
    private let logger: Logger

    // MARK: - Initialization

    /// Initialize with an HTTP client.
    /// - Parameter httpClient: Pre-configured HTTP client for repository service
    public init(httpClient: HTTPClient) {
        self.httpClient = httpClient
        self.logger = Logger(
            subsystem: AppConfiguration.AppInfo.bundleIdentifier,
            category: "RepositoryService"
        )
    }

    /// Initialize with default repository service configuration.
    /// - Parameter tokenProvider: Optional token provider for authentication
    public convenience init(tokenProvider: TokenProvider? = nil) {
        self.init(httpClient: HTTPClient.forRepository(tokenProvider: tokenProvider))
    }

    // MARK: - Shell Operations

    public func getAllShells(cursor: String? = nil) async throws -> PagedResult<AssetAdministrationShell> {
        logger.debug("Fetching all shells")

        var queryItems: [URLQueryItem] = []
        if let cursor = cursor {
            queryItems.append(URLQueryItem(name: "cursor", value: cursor))
        }

        let endpoint = Endpoint.get(
            "/shells",
            queryItems: queryItems.isEmpty ? nil : queryItems
        )

        do {
            let response: PagedResult<AssetAdministrationShell> = try await httpClient.request(endpoint)
            logger.debug("Fetched \(response.result.count) shells")
            return response
        } catch let error as HTTPError {
            throw AASError.from(error)
        }
    }

    public func getShell(aasId: String) async throws -> AssetAdministrationShell {
        logger.debug("Fetching shell: \(aasId)")

        let encodedId = aasB64Url(aasId)
        let endpoint = Endpoint.get("/shells/\(encodedId)")

        do {
            let shell: AssetAdministrationShell = try await httpClient.request(endpoint)
            logger.debug("Fetched shell: \(shell.idShort ?? "unknown")")
            return shell
        } catch let error as HTTPError {
            if case .notFound = error {
                throw AASError.shellNotFound(identifier: aasId)
            }
            throw AASError.from(error, context: aasId)
        }
    }

    public func createShell(_ shell: AssetAdministrationShell) async throws {
        logger.debug("Creating shell: \(shell.idShort ?? shell.id)")

        let endpoint = try Endpoint.post("/shells", body: shell)

        do {
            _ = try await httpClient.request(endpoint)
            logger.debug("Successfully created shell")
        } catch let error as HTTPError {
            if case .httpError(let statusCode, _) = error, statusCode == 409 {
                throw AASError.conflict(identifier: shell.id)
            }
            throw AASError.from(error, context: shell.id)
        }
    }

    public func updateShell(aasId: String, shell: AssetAdministrationShell) async throws {
        logger.debug("Updating shell: \(aasId)")

        let encodedId = aasB64Url(aasId)
        let endpoint = try Endpoint.put("/shells/\(encodedId)", body: shell)

        do {
            _ = try await httpClient.request(endpoint)
            logger.debug("Successfully updated shell")
        } catch let error as HTTPError {
            if case .notFound = error {
                throw AASError.shellNotFound(identifier: aasId)
            }
            throw AASError.from(error, context: aasId)
        }
    }

    public func deleteShell(aasId: String) async throws {
        logger.debug("Deleting shell: \(aasId)")

        let encodedId = aasB64Url(aasId)
        let endpoint = Endpoint.delete("/shells/\(encodedId)")

        do {
            _ = try await httpClient.request(endpoint)
            logger.debug("Successfully deleted shell")
        } catch let error as HTTPError {
            if case .notFound = error {
                throw AASError.shellNotFound(identifier: aasId)
            }
            throw AASError.from(error, context: aasId)
        }
    }

    // MARK: - Submodel Operations

    public func getSubmodel(submodelId: String) async throws -> Submodel {
        logger.debug("Fetching submodel: \(submodelId)")

        let encodedId = aasB64Url(submodelId)
        let endpoint = Endpoint.get("/submodels/\(encodedId)")

        do {
            let submodel: Submodel = try await httpClient.request(endpoint)
            logger.debug("Fetched submodel: \(submodel.idShort ?? "unknown")")
            return submodel
        } catch let error as HTTPError {
            if case .notFound = error {
                throw AASError.submodelNotFound(identifier: submodelId)
            }
            throw AASError.from(error, context: submodelId)
        }
    }

    public func getSubmodelValue(submodelId: String) async throws -> SubmodelValue {
        logger.debug("Fetching submodel value: \(submodelId)")

        let encodedId = aasB64Url(submodelId)
        let endpoint = Endpoint.get("/submodels/\(encodedId)/$value")

        do {
            let value: SubmodelValue = try await httpClient.request(endpoint)
            logger.debug("Fetched submodel value")
            return value
        } catch let error as HTTPError {
            if case .notFound = error {
                throw AASError.submodelNotFound(identifier: submodelId)
            }
            throw AASError.from(error, context: submodelId)
        }
    }

    public func createSubmodel(_ submodel: Submodel) async throws {
        logger.debug("Creating submodel: \(submodel.idShort ?? submodel.id)")

        let endpoint = try Endpoint.post("/submodels", body: submodel)

        do {
            _ = try await httpClient.request(endpoint)
            logger.debug("Successfully created submodel")
        } catch let error as HTTPError {
            if case .httpError(let statusCode, _) = error, statusCode == 409 {
                throw AASError.conflict(identifier: submodel.id)
            }
            throw AASError.from(error, context: submodel.id)
        }
    }

    public func updateSubmodel(submodelId: String, submodel: Submodel) async throws {
        logger.debug("Updating submodel: \(submodelId)")

        let encodedId = aasB64Url(submodelId)
        let endpoint = try Endpoint.put("/submodels/\(encodedId)", body: submodel)

        do {
            _ = try await httpClient.request(endpoint)
            logger.debug("Successfully updated submodel")
        } catch let error as HTTPError {
            if case .notFound = error {
                throw AASError.submodelNotFound(identifier: submodelId)
            }
            throw AASError.from(error, context: submodelId)
        }
    }

    public func deleteSubmodel(submodelId: String) async throws {
        logger.debug("Deleting submodel: \(submodelId)")

        let encodedId = aasB64Url(submodelId)
        let endpoint = Endpoint.delete("/submodels/\(encodedId)")

        do {
            _ = try await httpClient.request(endpoint)
            logger.debug("Successfully deleted submodel")
        } catch let error as HTTPError {
            if case .notFound = error {
                throw AASError.submodelNotFound(identifier: submodelId)
            }
            throw AASError.from(error, context: submodelId)
        }
    }

    // MARK: - Submodel Element Operations

    public func getAllSubmodelElements(submodelId: String) async throws -> [SubmodelElement] {
        logger.debug("Fetching all elements for submodel: \(submodelId)")

        let encodedId = aasB64Url(submodelId)
        let endpoint = Endpoint.get("/submodels/\(encodedId)/submodel-elements")

        do {
            let response: PagedResult<SubmodelElement> = try await httpClient.request(endpoint)
            logger.debug("Fetched \(response.result.count) elements")
            return response.result
        } catch let error as HTTPError {
            if case .notFound = error {
                throw AASError.submodelNotFound(identifier: submodelId)
            }
            throw AASError.from(error, context: submodelId)
        }
    }

    public func getSubmodelElement(submodelId: String, idShortPath: String) async throws -> SubmodelElement {
        logger.debug("Fetching element: \(idShortPath) from submodel: \(submodelId)")

        let encodedSubmodelId = aasB64Url(submodelId)
        // idShortPath uses URL path encoding (dots become %2E, etc.) but NOT base64
        let encodedPath = idShortPath.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? idShortPath

        let endpoint = Endpoint.get("/submodels/\(encodedSubmodelId)/submodel-elements/\(encodedPath)")

        do {
            let element: SubmodelElement = try await httpClient.request(endpoint)
            logger.debug("Fetched element: \(element.idShort)")
            return element
        } catch let error as HTTPError {
            if case .notFound = error {
                throw AASError.elementNotFound(path: idShortPath)
            }
            throw AASError.from(error, context: idShortPath)
        }
    }

    public func getSubmodelElementValue(submodelId: String, idShortPath: String) async throws -> Data {
        logger.debug("Fetching element value: \(idShortPath)")

        let encodedSubmodelId = aasB64Url(submodelId)
        let encodedPath = idShortPath.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? idShortPath

        let endpoint = Endpoint.get("/submodels/\(encodedSubmodelId)/submodel-elements/\(encodedPath)/$value")

        do {
            let data: Data = try await httpClient.request(endpoint)
            logger.debug("Fetched element value")
            return data
        } catch let error as HTTPError {
            if case .notFound = error {
                throw AASError.elementNotFound(path: idShortPath)
            }
            throw AASError.from(error, context: idShortPath)
        }
    }

    public func updateSubmodelElement(submodelId: String, idShortPath: String, element: SubmodelElement) async throws {
        logger.debug("Updating element: \(idShortPath)")

        let encodedSubmodelId = aasB64Url(submodelId)
        let encodedPath = idShortPath.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? idShortPath

        let endpoint = try Endpoint.put(
            "/submodels/\(encodedSubmodelId)/submodel-elements/\(encodedPath)",
            body: element
        )

        do {
            _ = try await httpClient.request(endpoint)
            logger.debug("Successfully updated element")
        } catch let error as HTTPError {
            if case .notFound = error {
                throw AASError.elementNotFound(path: idShortPath)
            }
            throw AASError.from(error, context: idShortPath)
        }
    }

    public func updateSubmodelElementValue(submodelId: String, idShortPath: String, value: String) async throws {
        logger.debug("Updating element value: \(idShortPath)")

        let encodedSubmodelId = aasB64Url(submodelId)
        let encodedPath = idShortPath.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? idShortPath

        let valueUpdate = PropertyValueUpdate(value: value)
        let endpoint = try Endpoint.patch(
            "/submodels/\(encodedSubmodelId)/submodel-elements/\(encodedPath)/$value",
            body: valueUpdate
        )

        do {
            _ = try await httpClient.request(endpoint)
            logger.debug("Successfully updated element value")
        } catch let error as HTTPError {
            if case .notFound = error {
                throw AASError.elementNotFound(path: idShortPath)
            }
            throw AASError.from(error, context: idShortPath)
        }
    }

    public func createSubmodelElement(submodelId: String, element: SubmodelElement) async throws {
        logger.debug("Creating element: \(element.idShort) in submodel: \(submodelId)")

        let encodedSubmodelId = aasB64Url(submodelId)
        let endpoint = try Endpoint.post(
            "/submodels/\(encodedSubmodelId)/submodel-elements",
            body: element
        )

        do {
            _ = try await httpClient.request(endpoint)
            logger.debug("Successfully created element")
        } catch let error as HTTPError {
            if case .notFound = error {
                throw AASError.submodelNotFound(identifier: submodelId)
            }
            if case .httpError(let statusCode, _) = error, statusCode == 409 {
                throw AASError.conflict(identifier: element.idShort)
            }
            throw AASError.from(error, context: element.idShort)
        }
    }

    public func deleteSubmodelElement(submodelId: String, idShortPath: String) async throws {
        logger.debug("Deleting element: \(idShortPath)")

        let encodedSubmodelId = aasB64Url(submodelId)
        let encodedPath = idShortPath.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? idShortPath

        let endpoint = Endpoint.delete("/submodels/\(encodedSubmodelId)/submodel-elements/\(encodedPath)")

        do {
            _ = try await httpClient.request(endpoint)
            logger.debug("Successfully deleted element")
        } catch let error as HTTPError {
            if case .notFound = error {
                throw AASError.elementNotFound(path: idShortPath)
            }
            throw AASError.from(error, context: idShortPath)
        }
    }

    // MARK: - Operation Invocation

    public func invokeOperation(submodelId: String, idShortPath: String, request: OperationRequest) async throws -> OperationResult {
        logger.debug("Invoking operation: \(idShortPath)")

        let encodedSubmodelId = aasB64Url(submodelId)
        let encodedPath = idShortPath.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? idShortPath

        let endpoint = try Endpoint.post(
            "/submodels/\(encodedSubmodelId)/submodel-elements/\(encodedPath)/invoke",
            body: request
        )

        do {
            let result: OperationResult = try await httpClient.request(endpoint)
            logger.debug("Operation completed with state: \(result.executionState?.rawValue ?? "unknown")")
            return result
        } catch let error as HTTPError {
            if case .notFound = error {
                throw AASError.elementNotFound(path: idShortPath)
            }
            throw AASError.from(error, context: idShortPath)
        }
    }

    public func invokeOperationAsync(submodelId: String, idShortPath: String, request: OperationRequest) async throws -> String {
        logger.debug("Invoking operation async: \(idShortPath)")

        let encodedSubmodelId = aasB64Url(submodelId)
        let encodedPath = idShortPath.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? idShortPath

        let endpoint = try Endpoint.post(
            "/submodels/\(encodedSubmodelId)/submodel-elements/\(encodedPath)/invoke-async",
            body: request
        )

        do {
            // Response contains the handle ID for tracking
            struct AsyncInvokeResponse: Codable {
                let handleId: String
            }
            let response: AsyncInvokeResponse = try await httpClient.request(endpoint)
            logger.debug("Operation started with handle: \(response.handleId)")
            return response.handleId
        } catch let error as HTTPError {
            if case .notFound = error {
                throw AASError.elementNotFound(path: idShortPath)
            }
            throw AASError.from(error, context: idShortPath)
        }
    }

    public func getOperationResult(submodelId: String, idShortPath: String, handleId: String) async throws -> OperationResult {
        logger.debug("Getting operation result: \(handleId)")

        let encodedSubmodelId = aasB64Url(submodelId)
        let encodedPath = idShortPath.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? idShortPath

        let endpoint = Endpoint.get(
            "/submodels/\(encodedSubmodelId)/submodel-elements/\(encodedPath)/operation-results/\(handleId)"
        )

        do {
            let result: OperationResult = try await httpClient.request(endpoint)
            logger.debug("Operation state: \(result.executionState?.rawValue ?? "unknown")")
            return result
        } catch let error as HTTPError {
            throw AASError.from(error, context: handleId)
        }
    }

    // MARK: - File Operations

    public func getFileContent(submodelId: String, idShortPath: String) async throws -> (data: Data, contentType: String) {
        logger.debug("Getting file content: \(idShortPath)")

        let encodedSubmodelId = aasB64Url(submodelId)
        let encodedPath = idShortPath.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? idShortPath

        let endpoint = Endpoint.get(
            "/submodels/\(encodedSubmodelId)/submodel-elements/\(encodedPath)/attachment"
        )

        do {
            let data: Data = try await httpClient.request(endpoint)
            // Default to octet-stream if content type not provided
            return (data, "application/octet-stream")
        } catch let error as HTTPError {
            if case .notFound = error {
                throw AASError.elementNotFound(path: idShortPath)
            }
            throw AASError.from(error, context: idShortPath)
        }
    }

    public func uploadFileContent(submodelId: String, idShortPath: String, data: Data, contentType: String) async throws {
        logger.debug("Uploading file content: \(idShortPath)")

        let encodedSubmodelId = aasB64Url(submodelId)
        let encodedPath = idShortPath.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? idShortPath

        let endpoint = Endpoint(
            path: "/submodels/\(encodedSubmodelId)/submodel-elements/\(encodedPath)/attachment",
            method: .put,
            headers: ["Content-Type": contentType],
            body: data
        )

        do {
            _ = try await httpClient.request(endpoint)
            logger.debug("Successfully uploaded file")
        } catch let error as HTTPError {
            if case .notFound = error {
                throw AASError.elementNotFound(path: idShortPath)
            }
            throw AASError.from(error, context: idShortPath)
        }
    }
}

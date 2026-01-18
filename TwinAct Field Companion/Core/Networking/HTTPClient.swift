//
//  HTTPClient.swift
//  TwinAct Field Companion
//
//  Robust HTTP client for AAS API communication with async/await, retry logic, and auth headers.
//

import Foundation
import os.log

// MARK: - HTTP Method

/// HTTP methods supported by the client
public enum HTTPMethod: String, Sendable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}

// MARK: - Endpoint

/// Endpoint configuration for HTTP requests
public struct Endpoint: Sendable {
    public let path: String
    public let method: HTTPMethod
    public let headers: [String: String]?
    public let queryItems: [URLQueryItem]?
    public let body: Data?
    public let timeout: TimeInterval?

    public init(
        path: String,
        method: HTTPMethod = .get,
        headers: [String: String]? = nil,
        queryItems: [URLQueryItem]? = nil,
        body: Data? = nil,
        timeout: TimeInterval? = nil
    ) {
        self.path = path
        self.method = method
        self.headers = headers
        self.queryItems = queryItems
        self.body = body
        self.timeout = timeout
    }
}

// MARK: - HTTP Errors

/// Errors that can occur during HTTP operations
public enum HTTPError: Error, LocalizedError, Sendable {
    case invalidURL
    case networkError(underlying: Error)
    case httpError(statusCode: Int, data: Data?)
    case decodingError(underlying: Error)
    case timeout
    case unauthorized      // 401
    case forbidden         // 403
    case notFound          // 404
    case tooManyRequests   // 429
    case serverError(statusCode: Int)  // 5xx
    case cancelled

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .networkError(let underlying):
            return "Network error: \(underlying.localizedDescription)"
        case .httpError(let statusCode, _):
            return "HTTP error with status code \(statusCode)"
        case .decodingError(let underlying):
            return "Failed to decode response: \(underlying.localizedDescription)"
        case .timeout:
            return "Request timed out"
        case .unauthorized:
            return "Unauthorized (401) - Authentication required"
        case .forbidden:
            return "Forbidden (403) - Access denied"
        case .notFound:
            return "Not found (404) - Resource does not exist"
        case .tooManyRequests:
            return "Too many requests (429) - Rate limited"
        case .serverError(let statusCode):
            return "Server error (\(statusCode))"
        case .cancelled:
            return "Request was cancelled"
        }
    }

    /// Whether this error is transient and should be retried
    public var isRetryable: Bool {
        switch self {
        case .networkError, .timeout, .tooManyRequests, .serverError:
            return true
        case .invalidURL, .httpError, .decodingError, .unauthorized, .forbidden, .notFound, .cancelled:
            return false
        }
    }
}

// MARK: - HTTP Client Protocol

/// Protocol for HTTP client (for testability)
public protocol HTTPClientProtocol: Sendable {
    /// Perform a request and decode the response to the specified type
    func request<T: Decodable>(_ endpoint: Endpoint) async throws -> T

    /// Perform a request and return raw data
    func request(_ endpoint: Endpoint) async throws -> Data

    /// Upload data to an endpoint
    func upload(_ endpoint: Endpoint, data: Data) async throws -> Data
}

// MARK: - HTTP Client Configuration

/// Configuration for the HTTP client
public struct HTTPClientConfiguration: Sendable {
    /// Base URL for all requests
    public let baseURL: URL

    /// Default request timeout
    public let defaultTimeout: TimeInterval

    /// Maximum number of retry attempts for transient errors
    public let maxRetryAttempts: Int

    /// Base delay for exponential backoff (in seconds)
    public let retryDelayBase: TimeInterval

    /// Maximum retry delay cap (in seconds)
    public let maxRetryDelay: TimeInterval

    public init(
        baseURL: URL,
        defaultTimeout: TimeInterval = 30.0,
        maxRetryAttempts: Int = 3,
        retryDelayBase: TimeInterval = 1.0,
        maxRetryDelay: TimeInterval = 30.0
    ) {
        self.baseURL = baseURL
        self.defaultTimeout = defaultTimeout
        self.maxRetryAttempts = maxRetryAttempts
        self.retryDelayBase = retryDelayBase
        self.maxRetryDelay = maxRetryDelay
    }

    /// Default configuration using AppConfiguration values
    public static var `default`: HTTPClientConfiguration {
        HTTPClientConfiguration(
            baseURL: AppConfiguration.baseURL,
            defaultTimeout: AppConfiguration.AASServer.requestTimeoutSeconds,
            maxRetryAttempts: AppConfiguration.OfflineSync.maxRetryAttempts,
            retryDelayBase: 1.0,
            maxRetryDelay: 30.0
        )
    }
}

// MARK: - Token Provider

/// Type alias for token provider closure
public typealias TokenProvider = @Sendable () async -> String?

// MARK: - HTTP Client

/// Robust HTTP client with retry logic and authentication support
public final class HTTPClient: HTTPClientProtocol, @unchecked Sendable {

    // MARK: - Properties

    private let configuration: HTTPClientConfiguration
    private let session: URLSession
    private let tokenProvider: TokenProvider?
    private let jsonDecoder: JSONDecoder
    private let jsonEncoder: JSONEncoder
    private let logger: Logger

    // MARK: - Initialization

    /// Initialize the HTTP client
    /// - Parameters:
    ///   - configuration: Client configuration
    ///   - tokenProvider: Optional closure to provide authentication tokens
    ///   - session: URLSession to use (defaults to shared session)
    public init(
        configuration: HTTPClientConfiguration = .default,
        tokenProvider: TokenProvider? = nil,
        session: URLSession? = nil
    ) {
        self.configuration = configuration
        self.tokenProvider = tokenProvider

        // Configure URL session
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = configuration.defaultTimeout
        sessionConfig.timeoutIntervalForResource = configuration.defaultTimeout * 2
        sessionConfig.waitsForConnectivity = true
        sessionConfig.httpMaximumConnectionsPerHost = AppConfiguration.AASServer.maxConcurrentConnections

        self.session = session ?? URLSession(configuration: sessionConfig)

        // Configure JSON decoder with snake_case conversion
        self.jsonDecoder = JSONDecoder()
        jsonDecoder.keyDecodingStrategy = .convertFromSnakeCase
        jsonDecoder.dateDecodingStrategy = .iso8601

        // Configure JSON encoder with snake_case conversion
        self.jsonEncoder = JSONEncoder()
        jsonEncoder.keyEncodingStrategy = .convertToSnakeCase
        jsonEncoder.dateEncodingStrategy = .iso8601

        // Setup logger
        self.logger = Logger(subsystem: AppConfiguration.AppInfo.bundleIdentifier, category: "HTTPClient")
    }

    // MARK: - HTTPClientProtocol Implementation

    public func request<T: Decodable>(_ endpoint: Endpoint) async throws -> T {
        let data = try await request(endpoint)

        do {
            return try jsonDecoder.decode(T.self, from: data)
        } catch {
            logError("Decoding failed for \(T.self): \(error)")
            throw HTTPError.decodingError(underlying: error)
        }
    }

    public func request(_ endpoint: Endpoint) async throws -> Data {
        let urlRequest = try await buildRequest(for: endpoint)
        return try await performRequestWithRetry(urlRequest)
    }

    public func upload(_ endpoint: Endpoint, data uploadData: Data) async throws -> Data {
        var urlRequest = try await buildRequest(for: endpoint)
        urlRequest.httpBody = uploadData

        if urlRequest.value(forHTTPHeaderField: "Content-Type") == nil {
            urlRequest.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        }

        return try await performRequestWithRetry(urlRequest)
    }

    // MARK: - Request Building

    private func buildRequest(for endpoint: Endpoint) async throws -> URLRequest {
        // Build URL with path and query items
        guard var components = URLComponents(url: configuration.baseURL.appendingPathComponent(endpoint.path), resolvingAgainstBaseURL: true) else {
            throw HTTPError.invalidURL
        }

        if let queryItems = endpoint.queryItems, !queryItems.isEmpty {
            components.queryItems = queryItems
        }

        guard let url = components.url else {
            throw HTTPError.invalidURL
        }

        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.timeoutInterval = endpoint.timeout ?? configuration.defaultTimeout

        // Set default headers
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if endpoint.body != nil && endpoint.method != .get {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        // Set user agent
        let userAgent = "\(AppConfiguration.AppInfo.appName)/\(AppConfiguration.AppInfo.version) (iOS)"
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")

        // Add authentication header if token provider is available
        if let tokenProvider = tokenProvider, let token = await tokenProvider() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        // Add custom headers from endpoint (can override defaults)
        if let headers = endpoint.headers {
            for (key, value) in headers {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }

        // Set body
        if let body = endpoint.body {
            request.httpBody = body
        }

        return request
    }

    // MARK: - Request Execution with Retry

    private func performRequestWithRetry(_ request: URLRequest) async throws -> Data {
        var lastError: HTTPError?
        var attemptCount = 0

        while attemptCount <= configuration.maxRetryAttempts {
            do {
                return try await performRequest(request)
            } catch let error as HTTPError {
                lastError = error

                // Check if error is retryable
                guard error.isRetryable else {
                    throw error
                }

                // Check if we have retries left
                guard attemptCount < configuration.maxRetryAttempts else {
                    logError("Max retries exceeded for \(request.url?.absoluteString ?? "unknown")")
                    throw error
                }

                // Calculate delay with exponential backoff and jitter
                let delay = calculateRetryDelay(attempt: attemptCount)
                logDebug("Retry \(attemptCount + 1)/\(configuration.maxRetryAttempts) after \(String(format: "%.2f", delay))s for \(request.url?.path ?? "")")

                // Wait before retrying
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

                attemptCount += 1
            } catch {
                // Convert unknown errors to HTTPError
                throw HTTPError.networkError(underlying: error)
            }
        }

        throw lastError ?? HTTPError.networkError(underlying: NSError(domain: "HTTPClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown error"]))
    }

    private func performRequest(_ request: URLRequest) async throws -> Data {
        logDebug("\(request.httpMethod ?? "GET") \(request.url?.absoluteString ?? "")")

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch let urlError as URLError {
            switch urlError.code {
            case .timedOut:
                logError("Request timed out: \(request.url?.absoluteString ?? "")")
                throw HTTPError.timeout
            case .cancelled:
                throw HTTPError.cancelled
            case .notConnectedToInternet, .networkConnectionLost:
                logError("Network unavailable: \(urlError.localizedDescription)")
                throw HTTPError.networkError(underlying: urlError)
            default:
                logError("URL error: \(urlError.localizedDescription)")
                throw HTTPError.networkError(underlying: urlError)
            }
        } catch {
            logError("Request failed: \(error.localizedDescription)")
            throw HTTPError.networkError(underlying: error)
        }

        // Validate HTTP response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw HTTPError.networkError(underlying: NSError(
                domain: "HTTPClient",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Invalid response type"]
            ))
        }

        logDebug("Response: \(httpResponse.statusCode) for \(request.url?.path ?? "")")

        // Map status code to appropriate result or error
        switch httpResponse.statusCode {
        case 200...299:
            return data
        case 401:
            throw HTTPError.unauthorized
        case 403:
            throw HTTPError.forbidden
        case 404:
            throw HTTPError.notFound
        case 429:
            throw HTTPError.tooManyRequests
        case 400...499:
            throw HTTPError.httpError(statusCode: httpResponse.statusCode, data: data)
        case 500...599:
            throw HTTPError.serverError(statusCode: httpResponse.statusCode)
        default:
            throw HTTPError.httpError(statusCode: httpResponse.statusCode, data: data)
        }
    }

    // MARK: - Retry Delay Calculation

    /// Calculate retry delay using exponential backoff with jitter
    private func calculateRetryDelay(attempt: Int) -> TimeInterval {
        // Base delay with exponential backoff: base * 2^attempt
        let exponentialDelay = configuration.retryDelayBase * pow(2.0, Double(attempt))

        // Cap the delay
        let cappedDelay = min(exponentialDelay, configuration.maxRetryDelay)

        // Add jitter (random value between 0 and 0.5 * delay) to prevent thundering herd
        let jitter = Double.random(in: 0...(cappedDelay * 0.5))

        return cappedDelay + jitter
    }

    // MARK: - Logging (Debug Builds Only)

    private func logDebug(_ message: String) {
        #if DEBUG
        logger.debug("\(message, privacy: .public)")
        #endif
    }

    private func logError(_ message: String) {
        #if DEBUG
        logger.error("\(message, privacy: .public)")
        #endif
    }
}

// MARK: - Convenience Extensions

extension HTTPClient {
    /// Create an HTTP client configured for the AAS Registry
    public static func forRegistry(tokenProvider: TokenProvider? = nil) -> HTTPClient {
        let config = HTTPClientConfiguration(
            baseURL: AppConfiguration.AASServer.registryURL,
            defaultTimeout: AppConfiguration.AASServer.requestTimeoutSeconds,
            maxRetryAttempts: AppConfiguration.OfflineSync.maxRetryAttempts
        )
        return HTTPClient(configuration: config, tokenProvider: tokenProvider)
    }

    /// Create an HTTP client configured for the AAS Repository
    public static func forRepository(tokenProvider: TokenProvider? = nil) -> HTTPClient {
        let config = HTTPClientConfiguration(
            baseURL: AppConfiguration.AASServer.repositoryURL,
            defaultTimeout: AppConfiguration.AASServer.requestTimeoutSeconds,
            maxRetryAttempts: AppConfiguration.OfflineSync.maxRetryAttempts
        )
        return HTTPClient(configuration: config, tokenProvider: tokenProvider)
    }

    /// Create an HTTP client configured for the AAS Discovery Service
    public static func forDiscovery(tokenProvider: TokenProvider? = nil) -> HTTPClient {
        let config = HTTPClientConfiguration(
            baseURL: AppConfiguration.AASServer.discoveryURL,
            defaultTimeout: AppConfiguration.AASServer.requestTimeoutSeconds,
            maxRetryAttempts: AppConfiguration.OfflineSync.maxRetryAttempts
        )
        return HTTPClient(configuration: config, tokenProvider: tokenProvider)
    }
}

// MARK: - Endpoint Builder Helpers

extension Endpoint {
    /// Create a GET endpoint
    public static func get(
        _ path: String,
        queryItems: [URLQueryItem]? = nil,
        headers: [String: String]? = nil,
        timeout: TimeInterval? = nil
    ) -> Endpoint {
        Endpoint(
            path: path,
            method: .get,
            headers: headers,
            queryItems: queryItems,
            body: nil,
            timeout: timeout
        )
    }

    /// Create a POST endpoint with JSON body
    public static func post<T: Encodable>(
        _ path: String,
        body: T,
        headers: [String: String]? = nil,
        timeout: TimeInterval? = nil
    ) throws -> Endpoint {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(body)

        return Endpoint(
            path: path,
            method: .post,
            headers: headers,
            queryItems: nil,
            body: data,
            timeout: timeout
        )
    }

    /// Create a POST endpoint with raw data body
    public static func post(
        _ path: String,
        data: Data,
        headers: [String: String]? = nil,
        timeout: TimeInterval? = nil
    ) -> Endpoint {
        Endpoint(
            path: path,
            method: .post,
            headers: headers,
            queryItems: nil,
            body: data,
            timeout: timeout
        )
    }

    /// Create a PUT endpoint with JSON body
    public static func put<T: Encodable>(
        _ path: String,
        body: T,
        headers: [String: String]? = nil,
        timeout: TimeInterval? = nil
    ) throws -> Endpoint {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(body)

        return Endpoint(
            path: path,
            method: .put,
            headers: headers,
            queryItems: nil,
            body: data,
            timeout: timeout
        )
    }

    /// Create a PATCH endpoint with JSON body
    public static func patch<T: Encodable>(
        _ path: String,
        body: T,
        headers: [String: String]? = nil,
        timeout: TimeInterval? = nil
    ) throws -> Endpoint {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(body)

        return Endpoint(
            path: path,
            method: .patch,
            headers: headers,
            queryItems: nil,
            body: data,
            timeout: timeout
        )
    }

    /// Create a DELETE endpoint
    public static func delete(
        _ path: String,
        headers: [String: String]? = nil,
        timeout: TimeInterval? = nil
    ) -> Endpoint {
        Endpoint(
            path: path,
            method: .delete,
            headers: headers,
            queryItems: nil,
            body: nil,
            timeout: timeout
        )
    }
}

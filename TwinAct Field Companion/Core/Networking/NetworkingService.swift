//
//  NetworkingService.swift
//  TwinAct Field Companion
//
//  Networking layer providing HTTP client and network monitoring services.
//

import Foundation
import Combine

// MARK: - Networking Service Protocol

/// Protocol defining networking service capabilities
public protocol NetworkingServiceProtocol: Sendable {
    /// HTTP client for making API requests
    var httpClient: HTTPClientProtocol { get }

    /// Check if network is currently available
    func isNetworkAvailable() async -> Bool

    /// Wait for network connectivity
    /// - Parameter timeout: Maximum time to wait
    /// - Returns: True if connected within timeout, false otherwise
    func waitForConnectivity(timeout: TimeInterval?) async -> Bool
}

// MARK: - Networking Service

/// Main networking service that coordinates HTTP client and network monitoring
public final class NetworkingService: NetworkingServiceProtocol, @unchecked Sendable {

    // MARK: - Properties

    /// The HTTP client for making requests
    public let httpClient: HTTPClientProtocol

    /// Network monitor for connectivity status
    private let networkMonitor: NetworkMonitor

    /// Token provider for authentication
    private let tokenProvider: TokenProvider?

    // MARK: - Singleton

    /// Shared instance with default configuration
    public static let shared = NetworkingService()

    // MARK: - Initialization

    /// Initialize networking service with custom configuration
    /// - Parameters:
    ///   - httpClient: Custom HTTP client (optional)
    ///   - networkMonitor: Custom network monitor (optional)
    ///   - tokenProvider: Token provider for authentication (optional)
    public init(
        httpClient: HTTPClientProtocol? = nil,
        networkMonitor: NetworkMonitor? = nil,
        tokenProvider: TokenProvider? = nil
    ) {
        self.tokenProvider = tokenProvider
        self.networkMonitor = networkMonitor ?? NetworkMonitor.shared

        if let client = httpClient {
            self.httpClient = client
        } else {
            self.httpClient = HTTPClient(
                configuration: .default,
                tokenProvider: tokenProvider
            )
        }
    }

    // MARK: - NetworkingServiceProtocol

    @MainActor
    public func isNetworkAvailable() async -> Bool {
        return networkMonitor.isConnected
    }

    public func waitForConnectivity(timeout: TimeInterval? = nil) async -> Bool {
        return await networkMonitor.waitForConnectivity(timeout: timeout)
    }

    // MARK: - Convenience Factory Methods

    /// Create a networking service configured for AAS Registry operations
    public static func forRegistry(tokenProvider: TokenProvider? = nil) -> NetworkingService {
        let client = HTTPClient.forRegistry(tokenProvider: tokenProvider)
        return NetworkingService(httpClient: client, tokenProvider: tokenProvider)
    }

    /// Create a networking service configured for AAS Repository operations
    public static func forRepository(tokenProvider: TokenProvider? = nil) -> NetworkingService {
        let client = HTTPClient.forRepository(tokenProvider: tokenProvider)
        return NetworkingService(httpClient: client, tokenProvider: tokenProvider)
    }

    /// Create a networking service configured for AAS Discovery operations
    public static func forDiscovery(tokenProvider: TokenProvider? = nil) -> NetworkingService {
        let client = HTTPClient.forDiscovery(tokenProvider: tokenProvider)
        return NetworkingService(httpClient: client, tokenProvider: tokenProvider)
    }
}

// MARK: - Network Status Observation

extension NetworkingService {
    /// Get the current network status
    @MainActor
    public var networkStatus: NetworkStatus {
        return networkMonitor.status
    }

    /// Get the current connection type
    @MainActor
    public var connectionType: ConnectionType {
        return networkMonitor.connectionType
    }

    /// Publisher for network status changes
    @MainActor
    public var statusPublisher: AnyPublisher<NetworkStatus, Never> {
        return networkMonitor.statusPublisher
    }

    /// Publisher for connectivity changes
    @MainActor
    public var connectivityPublisher: AnyPublisher<Bool, Never> {
        return networkMonitor.connectivityPublisher
    }

    /// Check if sync should be allowed based on current network status and app settings
    @MainActor
    public var shouldAllowSync: Bool {
        return networkMonitor.status.shouldAllowSync
    }
}

// MARK: - Request Helpers

extension NetworkingService {
    /// Perform a request with automatic network availability check
    /// - Parameters:
    ///   - endpoint: The endpoint to request
    ///   - requiresConnectivity: Whether to check connectivity first (default: true)
    /// - Returns: Decoded response
    public func request<T: Decodable>(
        _ endpoint: Endpoint,
        requiresConnectivity: Bool = true
    ) async throws -> T {
        if requiresConnectivity {
            let isAvailable = await isNetworkAvailable()
            if !isAvailable {
                throw HTTPError.networkError(underlying: NSError(
                    domain: "NetworkingService",
                    code: -1009,
                    userInfo: [NSLocalizedDescriptionKey: "No network connection available"]
                ))
            }
        }

        return try await httpClient.request(endpoint)
    }

    /// Perform a request and return raw data with automatic network availability check
    /// - Parameters:
    ///   - endpoint: The endpoint to request
    ///   - requiresConnectivity: Whether to check connectivity first (default: true)
    /// - Returns: Raw response data
    public func requestData(
        _ endpoint: Endpoint,
        requiresConnectivity: Bool = true
    ) async throws -> Data {
        if requiresConnectivity {
            let isAvailable = await isNetworkAvailable()
            if !isAvailable {
                throw HTTPError.networkError(underlying: NSError(
                    domain: "NetworkingService",
                    code: -1009,
                    userInfo: [NSLocalizedDescriptionKey: "No network connection available"]
                ))
            }
        }

        return try await httpClient.request(endpoint)
    }

    /// Upload data with automatic network availability check
    /// - Parameters:
    ///   - endpoint: The endpoint to upload to
    ///   - data: The data to upload
    ///   - requiresConnectivity: Whether to check connectivity first (default: true)
    /// - Returns: Response data
    public func upload(
        _ endpoint: Endpoint,
        data: Data,
        requiresConnectivity: Bool = true
    ) async throws -> Data {
        if requiresConnectivity {
            let isAvailable = await isNetworkAvailable()
            if !isAvailable {
                throw HTTPError.networkError(underlying: NSError(
                    domain: "NetworkingService",
                    code: -1009,
                    userInfo: [NSLocalizedDescriptionKey: "No network connection available"]
                ))
            }
        }

        return try await httpClient.upload(endpoint, data: data)
    }
}

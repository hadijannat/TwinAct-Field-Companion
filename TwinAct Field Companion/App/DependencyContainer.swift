//
//  DependencyContainer.swift
//  TwinAct Field Companion
//
//  Dependency injection container for managing service instances
//

import Foundation
import SwiftUI
import Combine

// MARK: - Protocol Abstractions

/// Protocol for the dependency container to enable testing
protocol DependencyContainerProtocol: AnyObject {
    var httpClient: HTTPClientProtocol { get }
    var authenticationManager: AuthenticationManagerProtocol { get }
    var persistenceController: PersistenceControllerProtocol { get }
    var syncEngine: SyncEngineProtocol { get }
}

/// Protocol for authentication management
protocol AuthenticationManagerProtocol: Sendable {
    var isAuthenticated: Bool { get async }
    func signIn(username: String, password: String) async throws
    func signOut() async
    func refreshToken() async throws
}

/// Protocol for data persistence operations
protocol PersistenceControllerProtocol: Sendable {
    func save<T: Encodable>(_ object: T, forKey key: String) async throws
    func load<T: Decodable>(forKey key: String) async throws -> T?
    func delete(forKey key: String) async throws
    func clearAll() async throws
}

/// Protocol for offline sync engine
protocol SyncEngineProtocol: Sendable {
    var isSyncing: Bool { get async }
    var lastSyncDate: Date? { get async }
    func startSync() async throws
    func stopSync() async
    func scheduleBackgroundSync() async
}

// MARK: - Placeholder Implementations (to be replaced with real implementations)

/// Placeholder HTTP client - replace with actual implementation
final class PlaceholderHTTPClient: HTTPClientProtocol, @unchecked Sendable {
    func request<T: Decodable>(_ endpoint: Endpoint) async throws -> T {
        fatalError("HTTPClient not yet implemented. Replace PlaceholderHTTPClient with actual implementation.")
    }

    func request(_ endpoint: Endpoint) async throws -> Data {
        fatalError("HTTPClient not yet implemented. Replace PlaceholderHTTPClient with actual implementation.")
    }

    func upload(_ endpoint: Endpoint, data: Data) async throws -> Data {
        fatalError("HTTPClient not yet implemented. Replace PlaceholderHTTPClient with actual implementation.")
    }
}

/// Placeholder authentication manager - replace with actual implementation
final class PlaceholderAuthenticationManager: AuthenticationManagerProtocol, @unchecked Sendable {
    var isAuthenticated: Bool {
        get async { false }
    }

    func signIn(username: String, password: String) async throws {
        fatalError("AuthenticationManager not yet implemented. Replace PlaceholderAuthenticationManager with actual implementation.")
    }

    func signOut() async {
        // No-op for placeholder
    }

    func refreshToken() async throws {
        fatalError("AuthenticationManager not yet implemented. Replace PlaceholderAuthenticationManager with actual implementation.")
    }
}

/// Placeholder persistence controller - replace with actual implementation
final class PlaceholderPersistenceController: PersistenceControllerProtocol, @unchecked Sendable {
    func save<T: Encodable>(_ object: T, forKey key: String) async throws {
        // No-op for placeholder - data is not persisted
    }

    func load<T: Decodable>(forKey key: String) async throws -> T? {
        return nil
    }

    func delete(forKey key: String) async throws {
        // No-op for placeholder
    }

    func clearAll() async throws {
        // No-op for placeholder
    }
}

/// Placeholder sync engine - replace with actual implementation
final class PlaceholderSyncEngine: SyncEngineProtocol, @unchecked Sendable {
    var isSyncing: Bool {
        get async { false }
    }

    var lastSyncDate: Date? {
        get async { nil }
    }

    func startSync() async throws {
        // No-op for placeholder
    }

    func stopSync() async {
        // No-op for placeholder
    }

    func scheduleBackgroundSync() async {
        // No-op for placeholder
    }
}

// MARK: - Dependency Container

/// Dependency injection container for the app
@MainActor
final class DependencyContainer: ObservableObject, DependencyContainerProtocol {

    // MARK: - Shared Instance

    static let shared = DependencyContainer()

    // MARK: - Service Factories (for testing)

    /// Factory closure for creating HTTP client instances
    nonisolated(unsafe) static var httpClientFactory: () -> HTTPClientProtocol = {
        PlaceholderHTTPClient()
    }

    /// Factory closure for creating authentication manager instances
    nonisolated(unsafe) static var authenticationManagerFactory: () -> AuthenticationManagerProtocol = {
        PlaceholderAuthenticationManager()
    }

    /// Factory closure for creating persistence controller instances
    nonisolated(unsafe) static var persistenceControllerFactory: () -> PersistenceControllerProtocol = {
        PlaceholderPersistenceController()
    }

    /// Factory closure for creating sync engine instances
    nonisolated(unsafe) static var syncEngineFactory: () -> SyncEngineProtocol = {
        PlaceholderSyncEngine()
    }

    // MARK: - Lazy Services

    /// HTTP client for network requests
    private var _httpClient: HTTPClientProtocol?
    var httpClient: HTTPClientProtocol {
        if let client = _httpClient {
            return client
        }
        let client = Self.httpClientFactory()
        _httpClient = client
        return client
    }

    /// Authentication manager for user sessions
    private var _authenticationManager: AuthenticationManagerProtocol?
    var authenticationManager: AuthenticationManagerProtocol {
        if let manager = _authenticationManager {
            return manager
        }
        let manager = Self.authenticationManagerFactory()
        _authenticationManager = manager
        return manager
    }

    /// Persistence controller for local data storage
    private var _persistenceController: PersistenceControllerProtocol?
    var persistenceController: PersistenceControllerProtocol {
        if let controller = _persistenceController {
            return controller
        }
        let controller = Self.persistenceControllerFactory()
        _persistenceController = controller
        return controller
    }

    /// Sync engine for offline data synchronization
    private var _syncEngine: SyncEngineProtocol?
    var syncEngine: SyncEngineProtocol {
        if let engine = _syncEngine {
            return engine
        }
        let engine = Self.syncEngineFactory()
        _syncEngine = engine
        return engine
    }

    // MARK: - Published State

    /// Whether the app is currently performing a sync operation
    @Published var isSyncInProgress: Bool = false

    /// The last time a successful sync completed
    @Published var lastSyncTimestamp: Date?

    /// Current network connectivity status
    @Published var isNetworkAvailable: Bool = true

    // MARK: - Initialization

    private init() {
        // Default initialization - services are lazily created
    }

    /// Creates a container with custom service implementations (for testing)
    init(
        httpClient: HTTPClientProtocol? = nil,
        authenticationManager: AuthenticationManagerProtocol? = nil,
        persistenceController: PersistenceControllerProtocol? = nil,
        syncEngine: SyncEngineProtocol? = nil
    ) {
        self._httpClient = httpClient
        self._authenticationManager = authenticationManager
        self._persistenceController = persistenceController
        self._syncEngine = syncEngine
    }

    // MARK: - Lifecycle Methods

    /// Called when the app enters the foreground - triggers sync if needed
    func handleAppWillEnterForeground() {
        Task {
            await triggerSyncIfNeeded()
        }
    }

    /// Called when the app enters the background - schedules background sync
    func handleAppDidEnterBackground() {
        Task {
            await syncEngine.scheduleBackgroundSync()
        }
    }

    // MARK: - Sync Operations

    /// Triggers a sync operation if conditions are met
    func triggerSyncIfNeeded() async {
        guard isNetworkAvailable else { return }
        guard !isSyncInProgress else { return }

        // Check if enough time has passed since last sync
        if let lastSync = lastSyncTimestamp {
            let timeSinceLastSync = Date().timeIntervalSince(lastSync)
            guard timeSinceLastSync >= AppConfiguration.OfflineSync.syncIntervalSeconds else {
                return
            }
        }

        await performSync()
    }

    /// Performs a full sync operation
    func performSync() async {
        guard !isSyncInProgress else { return }

        isSyncInProgress = true
        defer { isSyncInProgress = false }

        do {
            try await syncEngine.startSync()
            lastSyncTimestamp = Date()
        } catch {
            // Log error but don't throw - sync failures should be handled gracefully
            print("Sync failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Reset (for testing)

    /// Resets all services - useful for testing
    func reset() {
        _httpClient = nil
        _authenticationManager = nil
        _persistenceController = nil
        _syncEngine = nil
        isSyncInProgress = false
        lastSyncTimestamp = nil
    }
}

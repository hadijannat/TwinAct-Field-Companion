//
//  DependencyContainer.swift
//  TwinAct Field Companion
//
//  Dependency injection container for managing service instances
//

import Foundation
import SwiftUI
import Combine
import os.log

/// Logger for dependency container events
private let dependencyLogger = Logger(subsystem: "com.twinact.fieldcompanion", category: "Dependencies")

// MARK: - Protocol Abstractions

/// Protocol for the dependency container to enable testing and mocking.
///
/// The dependency container provides centralized access to all app services.
/// Use this protocol to create mock containers for unit testing.
///
/// ## Example
/// ```swift
/// class MockDependencyContainer: DependencyContainerProtocol {
///     var httpClient: HTTPClientProtocol { MockHTTPClient() }
///     // ...
/// }
/// ```
@MainActor
protocol DependencyContainerProtocol: AnyObject {
    /// HTTP client for network requests to AAS servers.
    var httpClient: HTTPClientProtocol { get }

    /// Manager for user authentication and token lifecycle.
    var authenticationManager: AuthenticationManagerProtocol { get }

    /// Controller for local data persistence using SwiftData.
    var persistenceController: PersistenceControllerProtocol { get }

    /// Engine for offline-first sync with conflict resolution.
    var syncEngine: SyncEngineProtocol { get }
}

/// Protocol for user authentication and session management.
///
/// Handles sign-in/sign-out flows and token refresh for authenticated API access.
/// Implementations should securely store credentials in the Keychain.
@MainActor
protocol AuthenticationManagerProtocol: Sendable {
    /// Whether the user is currently authenticated with valid credentials.
    var isAuthenticated: Bool { get async }

    /// Authenticate user with username and password.
    /// - Parameters:
    ///   - username: User's email or username.
    ///   - password: User's password.
    /// - Throws: Authentication error if credentials are invalid.
    func signIn(username: String, password: String) async throws

    /// Sign out the current user and clear stored credentials.
    func signOut() async

    /// Refresh the access token using the stored refresh token.
    /// - Throws: Authentication error if refresh fails (user must sign in again).
    func refreshToken() async throws

    /// Get a valid access token for API calls.
    func getAccessToken() async throws -> String
}

/// Protocol for key-value persistence operations.
///
/// Provides a simple interface for storing and retrieving Codable objects.
/// Used for caching and offline data storage.
@MainActor
protocol PersistenceControllerProtocol: Sendable {
    /// Save an encodable object to persistent storage.
    /// - Parameters:
    ///   - object: The object to persist.
    ///   - key: Unique key for retrieval.
    func save<T: Encodable>(_ object: T, forKey key: String) async throws

    /// Load a previously saved object from storage.
    /// - Parameter key: The key used when saving.
    /// - Returns: The decoded object, or nil if not found.
    func load<T: Decodable>(forKey key: String) async throws -> T?

    /// Delete an object from storage.
    /// - Parameter key: The key of the object to delete.
    func delete(forKey key: String) async throws

    /// Clear all persisted data. Use with caution.
    func clearAll() async throws
}

/// Protocol for offline-first synchronization between local and server data.
///
/// The sync engine manages:
/// - Outbox queue for pending local changes
/// - Conflict resolution when server and local data diverge
/// - Background sync scheduling for iOS
///
/// ## Sync Flow
/// 1. Local changes are queued in the outbox
/// 2. When online, changes are pushed to server
/// 3. Server changes are pulled and merged with local data
/// 4. Conflicts are resolved per configured strategy
@MainActor
protocol SyncEngineProtocol: Sendable {
    /// Whether a sync operation is currently in progress.
    var isSyncing: Bool { get async }

    /// Timestamp of the last successful sync, or nil if never synced.
    var lastSyncDate: Date? { get async }

    /// Start a manual sync operation.
    /// - Throws: SyncError if sync fails.
    func startSync() async throws

    /// Stop any ongoing sync operation.
    func stopSync() async

    /// Schedule background sync using BGTaskScheduler.
    func scheduleBackgroundSync() async
}

// MARK: - Placeholder Implementations (to be replaced with real implementations)

/// Placeholder HTTP client - replace with actual implementation
final class PlaceholderHTTPClient: HTTPClientProtocol, @unchecked Sendable {
    func request<T: Decodable>(_ endpoint: Endpoint) async throws -> T {
        throw HTTPError.notImplemented
    }

    func request(_ endpoint: Endpoint) async throws -> Data {
        throw HTTPError.notImplemented
    }

    func upload(_ endpoint: Endpoint, data: Data) async throws -> Data {
        throw HTTPError.notImplemented
    }
}

/// Placeholder authentication manager - replace with actual implementation
@MainActor
final class PlaceholderAuthenticationManager: AuthenticationManagerProtocol, @unchecked Sendable {
    var isAuthenticated: Bool {
        get async { false }
    }

    func signIn(username: String, password: String) async throws {
        throw AuthenticationError.configurationError(message: "Authentication is not configured.")
    }

    func signOut() async {
        // No-op for placeholder
    }

    func refreshToken() async throws {
        throw AuthenticationError.notAuthenticated
    }

    func getAccessToken() async throws -> String {
        throw AuthenticationError.notAuthenticated
    }
}

/// Placeholder persistence controller - replace with actual implementation
@MainActor
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
@MainActor
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

// MARK: - Default Implementations

@MainActor
final class AuthenticationManagerAdapter: AuthenticationManagerProtocol, @unchecked Sendable {
    private let manager: AuthenticationManager

    init(manager: AuthenticationManager) {
        self.manager = manager
    }

    var isAuthenticated: Bool {
        get async { manager.isAuthenticated }
    }

    func signIn(username: String, password: String) async throws {
        // OAuth flow does not use username/password; ignore parameters for now.
        try await manager.login()
    }

    func signOut() async {
        await manager.logout()
    }

    func refreshToken() async throws {
        try await manager.refreshTokenIfNeeded()
    }

    func getAccessToken() async throws -> String {
        try await manager.getAccessToken()
    }
}

@MainActor
final class KeyValuePersistenceController: PersistenceControllerProtocol, @unchecked Sendable {
    private let defaults: UserDefaults
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let keyPrefix: String

    init(
        defaults: UserDefaults = .standard,
        keyPrefix: String = "com.twinact.fieldcompanion.kv."
    ) {
        self.defaults = defaults
        self.keyPrefix = keyPrefix
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
    }

    func save<T: Encodable>(_ object: T, forKey key: String) async throws {
        let data = try encoder.encode(object)
        defaults.set(data, forKey: namespacedKey(key))
    }

    func load<T: Decodable>(forKey key: String) async throws -> T? {
        guard let data = defaults.data(forKey: namespacedKey(key)) else {
            return nil
        }
        return try decoder.decode(T.self, from: data)
    }

    func delete(forKey key: String) async throws {
        defaults.removeObject(forKey: namespacedKey(key))
    }

    func clearAll() async throws {
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix(keyPrefix) {
            defaults.removeObject(forKey: key)
        }
    }

    private func namespacedKey(_ key: String) -> String {
        keyPrefix + key
    }
}

@MainActor
final class SyncEngineAdapter: SyncEngineProtocol, @unchecked Sendable {
    private let syncEngine: SyncEngine

    init(syncEngine: SyncEngine) {
        self.syncEngine = syncEngine
    }

    var isSyncing: Bool {
        get async { syncEngine.isSyncing }
    }

    var lastSyncDate: Date? {
        get async { syncEngine.lastSyncDate }
    }

    func startSync() async throws {
        _ = try await syncEngine.forceSync()
    }

    func stopSync() async {
        syncEngine.cancelSync()
    }

    func scheduleBackgroundSync() async {
        syncEngine.scheduleBackgroundSync()
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
    @MainActor static var httpClientFactory: () -> HTTPClientProtocol = {
        HTTPClient()
    }

    /// Factory closure for creating authentication manager instances
    @MainActor static var authenticationManagerFactory: () -> AuthenticationManagerProtocol = {
        AuthenticationManagerAdapter(manager: AuthenticationManager())
    }

    /// Factory closure for creating persistence controller instances
    @MainActor static var persistenceControllerFactory: () -> PersistenceControllerProtocol = {
        KeyValuePersistenceController()
    }

    /// Factory closure for creating sync engine instances
    @MainActor static var syncEngineFactory: () -> SyncEngineProtocol = {
        let persistence = PersistenceService()
        let repository: RepositoryServiceProtocol = AppConfiguration.isDemoMode
            ? MockRepositoryService()
            : RepositoryService()
        let engine = SyncEngine(
            persistence: persistence,
            repositoryService: repository
        )
        return SyncEngineAdapter(syncEngine: engine)
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

    // MARK: - AAS Services (Demo Mode Aware)

    /// Cached AAS services (cleared when demo mode changes)
    private var _discoveryService: DiscoveryServiceProtocol?
    private var _registryService: RegistryServiceProtocol?
    private var _repositoryService: RepositoryServiceProtocol?
    private var _submodelService: SubmodelServiceProtocol?
    private var _assetService: AssetServiceProtocol?

    private func makeTokenProvider() -> TokenProvider {
        { [weak self] in
            guard let self else { return nil }
            return try? await self.authenticationManager.getAccessToken()
        }
    }

    /// Discovery service - returns mock in demo mode, real service otherwise.
    var discoveryService: DiscoveryServiceProtocol {
        if let service = _discoveryService {
            return service
        }
        let tokenProvider = makeTokenProvider()
        let service: DiscoveryServiceProtocol = AppConfiguration.isDemoMode
            ? MockDiscoveryService()
            : DiscoveryService(tokenProvider: tokenProvider)
        _discoveryService = service
        return service
    }

    /// Registry service - returns mock in demo mode, real service otherwise.
    var registryService: RegistryServiceProtocol {
        if let service = _registryService {
            return service
        }
        let tokenProvider = makeTokenProvider()
        let service: RegistryServiceProtocol = AppConfiguration.isDemoMode
            ? MockRegistryService()
            : RegistryService(tokenProvider: tokenProvider)
        _registryService = service
        return service
    }

    /// Repository service - returns mock in demo mode, real service otherwise.
    var repositoryService: RepositoryServiceProtocol {
        if let service = _repositoryService {
            return service
        }
        let tokenProvider = makeTokenProvider()
        let service: RepositoryServiceProtocol = AppConfiguration.isDemoMode
            ? MockRepositoryService()
            : RepositoryService(tokenProvider: tokenProvider)
        _repositoryService = service
        return service
    }

    /// Submodel service - returns mock in demo mode, real service otherwise.
    var submodelService: SubmodelServiceProtocol {
        if let service = _submodelService {
            return service
        }
        let tokenProvider = makeTokenProvider()
        let service: SubmodelServiceProtocol = AppConfiguration.isDemoMode
            ? MockSubmodelService()
            : SubmodelService(tokenProvider: tokenProvider)
        _submodelService = service
        return service
    }

    /// Asset service - provides asset browsing and lookup.
    var assetService: AssetServiceProtocol {
        if let service = _assetService {
            return service
        }
        let repository = AssetRepository(
            registryService: registryService
        )
        let service = AssetService(repository: repository)
        _assetService = service
        return service
    }

    /// Clears cached AAS services, forcing them to be recreated.
    /// Call this when demo mode changes.
    func invalidateAASServices() {
        _discoveryService = nil
        _registryService = nil
        _repositoryService = nil
        _submodelService = nil
        _assetService = nil
    }

    // MARK: - AI/Inference Services

    /// Cached AI provider key storage
    private var _aiProviderKeyStorage: AIProviderKeyStorage?

    /// Secure storage for AI provider API keys
    var aiProviderKeyStorage: AIProviderKeyStorage {
        if let storage = _aiProviderKeyStorage {
            return storage
        }
        let storage = AIProviderKeyStorage()
        _aiProviderKeyStorage = storage
        return storage
    }

    /// Cached AI provider manager
    private var _aiProviderManager: AIProviderManager?

    /// Manager for multi-provider AI inference configuration
    var aiProviderManager: AIProviderManager {
        if let manager = _aiProviderManager {
            return manager
        }
        let manager = AIProviderManager(keyStorage: aiProviderKeyStorage)
        _aiProviderManager = manager
        return manager
    }

    /// Cached inference router
    private var _inferenceRouter: InferenceRouter?

    /// Inference router for LLM requests (on-device and cloud)
    var inferenceRouter: InferenceRouter {
        if let router = _inferenceRouter {
            return router
        }
        let router = InferenceRouter(providerManager: aiProviderManager)
        _inferenceRouter = router
        return router
    }

    // MARK: - RAG Services

    /// Shared vector store for document embeddings (singleton for app-wide use)
    private var _vectorStore: VectorStore?

    /// Shared vector store - used by both KnowledgeIndexer and ChatViewModel
    var vectorStore: VectorStore {
        if let store = _vectorStore {
            return store
        }
        let store = VectorStore()
        _vectorStore = store
        return store
    }

    /// Cached knowledge indexer
    private var _knowledgeIndexer: KnowledgeIndexer?

    /// Knowledge indexer for bundled domain expertise
    var knowledgeIndexer: KnowledgeIndexer {
        if let indexer = _knowledgeIndexer {
            return indexer
        }
        let indexer = KnowledgeIndexer(vectorStore: vectorStore)
        _knowledgeIndexer = indexer
        return indexer
    }

    /// Index bundled knowledge documents (call at app startup)
    func indexBundledKnowledge() async {
        do {
            let chunkCount = try await knowledgeIndexer.indexBundledKnowledge()
            dependencyLogger.info("Indexed \(chunkCount) knowledge chunks at startup")
        } catch {
            dependencyLogger.error("Failed to index knowledge: \(error.localizedDescription)")
        }
    }

    // MARK: - Glossary Service

    /// Cached glossary service
    private var _glossaryService: GlossaryService?

    /// Glossary service for DPP Jargon Buster feature
    var glossaryService: GlossaryService {
        if let service = _glossaryService {
            return service
        }
        let service = GlossaryService(
            inferenceRouter: inferenceRouter,
            enableLLMFallback: AppConfiguration.GenAI.enableGlossaryLLMFallback,
            maxCachedTerms: AppConfiguration.GenAI.glossaryMaxCachedTerms
        )
        _glossaryService = service

        // Load glossary on first access
        Task {
            try? await service.loadGlossary()
        }

        return service
    }

    // MARK: - Published State

    /// Whether the app is currently performing a sync operation
    @Published var isSyncInProgress: Bool = false

    /// The last time a successful sync completed
    @Published var lastSyncTimestamp: Date?

    /// Current network connectivity status
    @Published var isNetworkAvailable: Bool = true

    // MARK: - Initialization

    /// Subscription for demo mode changes
    private var demoModeObserver: NSObjectProtocol?

    private init() {
        // Default initialization - services are lazily created
        setupDemoModeObserver()
    }

    /// Set up observer for demo mode changes.
    private func setupDemoModeObserver() {
        demoModeObserver = NotificationCenter.default.addObserver(
            forName: .demoModeDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.invalidateAASServices()
            }
        }
    }

    deinit {
        if let observer = demoModeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
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
        Task { @MainActor [weak self] in
            await self?.triggerSyncIfNeeded()
        }
    }

    /// Called when the app enters the background - schedules background sync
    func handleAppDidEnterBackground() {
        Task { @MainActor [weak self] in
            await self?.syncEngine.scheduleBackgroundSync()
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
            dependencyLogger.error("Sync failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Reset (for testing)

    /// Resets all services - useful for testing
    func reset() {
        _httpClient = nil
        _authenticationManager = nil
        _persistenceController = nil
        _syncEngine = nil
        _aiProviderKeyStorage = nil
        _aiProviderManager = nil
        _inferenceRouter = nil
        _glossaryService = nil
        _vectorStore = nil
        _knowledgeIndexer = nil
        invalidateAASServices()
        isSyncInProgress = false
        lastSyncTimestamp = nil
    }

    /// Inject a shared SyncEngine instance (used to keep UI and background sync in sync).
    func setSyncEngine(_ engine: SyncEngine) {
        _syncEngine = SyncEngineAdapter(syncEngine: engine)
    }
}

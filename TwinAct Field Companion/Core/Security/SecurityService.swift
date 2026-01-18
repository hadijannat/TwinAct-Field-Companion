//
//  SecurityService.swift
//  TwinAct Field Companion
//
//  Central security service providing access to authentication and session management.
//

import Foundation
import Combine
import os.log

/// Central security service for the application
@MainActor
public final class SecurityService: ObservableObject {

    // MARK: - Shared Instance

    /// Shared security service instance
    public static let shared = SecurityService()

    // MARK: - Published Properties

    /// Whether the user is authenticated
    @Published public private(set) var isAuthenticated: Bool = false

    /// The current authenticated user
    @Published public private(set) var currentUser: User?

    /// Current session state
    @Published public private(set) var sessionState: SessionState = .unknown

    /// Whether an auth operation is in progress
    @Published public private(set) var isLoading: Bool = false

    /// Last authentication error
    @Published public private(set) var error: AuthenticationError?

    // MARK: - Components

    /// Authentication manager for OAuth2 + PKCE flow
    public let authManager: AuthenticationManager

    /// Session manager for lifecycle management
    public let sessionManager: SessionManager

    /// Token storage for secure credential storage
    public let tokenStorage: TokenStorage

    // MARK: - Private Properties

    private let logger: Logger
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    /// Initialize security service with default components
    private init() {
        self.tokenStorage = TokenStorage()
        self.authManager = AuthenticationManager(tokenStorage: tokenStorage)
        self.sessionManager = SessionManager(authManager: authManager, tokenStorage: tokenStorage)
        self.logger = Logger(
            subsystem: Bundle.main.bundleIdentifier ?? "com.twinact.fieldcompanion",
            category: "SecurityService"
        )

        setupBindings()
    }

    /// Initialize with custom components (for testing)
    public init(
        authManager: AuthenticationManager,
        sessionManager: SessionManager,
        tokenStorage: TokenStorage
    ) {
        self.authManager = authManager
        self.sessionManager = sessionManager
        self.tokenStorage = tokenStorage
        self.logger = Logger(
            subsystem: Bundle.main.bundleIdentifier ?? "com.twinact.fieldcompanion",
            category: "SecurityService"
        )

        setupBindings()
    }

    // MARK: - Setup

    private func setupBindings() {
        // Bind auth manager state
        authManager.$isAuthenticated
            .receive(on: DispatchQueue.main)
            .assign(to: &$isAuthenticated)

        authManager.$currentUser
            .receive(on: DispatchQueue.main)
            .assign(to: &$currentUser)

        authManager.$isLoading
            .receive(on: DispatchQueue.main)
            .assign(to: &$isLoading)

        authManager.$error
            .receive(on: DispatchQueue.main)
            .assign(to: &$error)

        // Bind session manager state
        sessionManager.$sessionState
            .receive(on: DispatchQueue.main)
            .assign(to: &$sessionState)
    }

    // MARK: - Public API

    /// Start security services (call on app launch)
    public func start() {
        logDebug("Starting security services")
        sessionManager.startMonitoring()
    }

    /// Stop security services (call on app termination)
    public func stop() {
        logDebug("Stopping security services")
        sessionManager.stopMonitoring()
    }

    /// Perform login
    public func login() async throws {
        try await authManager.login()
    }

    /// Perform logout
    public func logout() async {
        await authManager.logout()
    }

    /// Get current access token (refreshes if needed)
    public func getAccessToken() async throws -> String {
        try await authManager.getAccessToken()
    }

    /// Check if user has technician role
    public var isTechnician: Bool {
        currentUser?.isTechnician ?? false
    }

    /// Check if user has viewer role only
    public var isViewer: Bool {
        currentUser?.isViewer ?? true
    }

    /// Token provider for HTTP clients
    public var tokenProvider: TokenProvider {
        authManager.tokenProvider
    }

    // MARK: - Demo Mode

    /// Enable demo mode with mock user (for development/testing)
    public func enableDemoMode(asTechnician: Bool = true) {
        logDebug("Enabling demo mode (technician: \(asTechnician))")

        // Store demo tokens
        tokenStorage.storeTokens(
            accessToken: "demo-access-token",
            refreshToken: "demo-refresh-token",
            idToken: nil,
            expiresIn: 86400 // 24 hours
        )

        // Set demo user
        let demoUser = asTechnician ? User.demo : User.demoViewer
        tokenStorage.userData = demoUser

        // Update state
        isAuthenticated = true
        currentUser = demoUser
    }

    /// Disable demo mode
    public func disableDemoMode() {
        logDebug("Disabling demo mode")
        tokenStorage.clearAll()
        isAuthenticated = false
        currentUser = nil
    }

    // MARK: - Logging

    private func logDebug(_ message: String) {
        #if DEBUG
        logger.debug("\(message, privacy: .public)")
        #endif
    }
}

// MARK: - Authorization Checks

extension SecurityService {
    /// Check if current user can perform technician actions
    public func canPerformTechnicianActions() -> Bool {
        isAuthenticated && isTechnician
    }

    /// Check if current user can view asset data (any authenticated user or public passport)
    public func canViewAssetData() -> Bool {
        // Public passport views don't require auth
        // Authenticated users can always view
        true
    }

    /// Check if current user can modify asset data
    public func canModifyAssetData() -> Bool {
        canPerformTechnicianActions()
    }

    /// Check if current user can create service requests
    public func canCreateServiceRequest() -> Bool {
        canPerformTechnicianActions()
    }

    /// Require authentication for an action
    /// - Returns: True if authenticated, false otherwise
    /// - Note: Call this before protected actions to ensure user is logged in
    public func requireAuthentication() async -> Bool {
        if isAuthenticated {
            return true
        }

        // Try to restore session
        if sessionManager.requiresReauthentication {
            return false
        }

        // Check if we can refresh
        if tokenStorage.hasRefreshToken {
            do {
                try await authManager.refreshTokenIfNeeded()
                return authManager.isAuthenticated
            } catch {
                return false
            }
        }

        return false
    }

    /// Require technician role for an action
    /// - Returns: True if user is authenticated technician
    public func requireTechnicianRole() async -> Bool {
        guard await requireAuthentication() else {
            return false
        }
        return isTechnician
    }
}

//
//  SessionManager.swift
//  TwinAct Field Companion
//
//  Manages user session lifecycle, expiry monitoring, and automatic refresh.
//

import Foundation
import Combine
import UIKit
import os.log

/// Session state representing the current authentication status
public enum SessionState: Equatable, Sendable {
    /// Session state is unknown (initial state)
    case unknown

    /// User is authenticated with valid session
    case authenticated(User)

    /// Session has expired and needs refresh or re-authentication
    case expired

    /// User is logged out
    case loggedOut

    /// Session is being refreshed
    case refreshing

    /// Error state
    case error(String)

    public static func == (lhs: SessionState, rhs: SessionState) -> Bool {
        switch (lhs, rhs) {
        case (.unknown, .unknown),
             (.expired, .expired),
             (.loggedOut, .loggedOut),
             (.refreshing, .refreshing):
            return true
        case let (.authenticated(user1), .authenticated(user2)):
            return user1.id == user2.id
        case let (.error(msg1), .error(msg2)):
            return msg1 == msg2
        default:
            return false
        }
    }
}

/// Manages user session lifecycle
@MainActor
public final class SessionManager: ObservableObject {

    // MARK: - Published Properties

    /// Current session state
    @Published public private(set) var sessionState: SessionState = .unknown

    /// Whether a silent refresh is in progress
    @Published public private(set) var isRefreshing: Bool = false

    /// Time until session expires (nil if unknown or not authenticated)
    @Published public private(set) var timeUntilExpiry: TimeInterval?

    // MARK: - Private Properties

    private let authManager: AuthenticationManager
    private let tokenStorage: TokenStorage
    private let logger: Logger

    private var sessionCheckTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    /// Interval for checking session validity
    private let sessionCheckInterval: TimeInterval = 60 // 1 minute

    /// Time before expiry to trigger proactive refresh
    private let refreshThreshold: TimeInterval = 300 // 5 minutes

    // MARK: - Initialization

    /// Initialize session manager
    /// - Parameters:
    ///   - authManager: The authentication manager
    ///   - tokenStorage: Token storage instance
    public init(
        authManager: AuthenticationManager,
        tokenStorage: TokenStorage = TokenStorage()
    ) {
        self.authManager = authManager
        self.tokenStorage = tokenStorage
        self.logger = Logger(
            subsystem: Bundle.main.bundleIdentifier ?? "com.twinact.fieldcompanion",
            category: "SessionManager"
        )

        setupObservers()
    }

    deinit {
        sessionCheckTimer?.invalidate()
    }

    // MARK: - Public API

    /// Start monitoring session validity
    public func startMonitoring() {
        logDebug("Starting session monitoring")

        // Initial state sync
        syncStateFromAuthManager()

        // Start periodic checks
        startSessionCheckTimer()

        // Observe app lifecycle
        setupAppLifecycleObservers()
    }

    /// Stop monitoring session
    public func stopMonitoring() {
        logDebug("Stopping session monitoring")
        sessionCheckTimer?.invalidate()
        sessionCheckTimer = nil
    }

    /// Handle session expiry
    public func handleSessionExpiry() async {
        logDebug("Handling session expiry")

        // Try silent refresh first
        if tokenStorage.hasRefreshToken {
            await attemptSilentRefresh()
        } else {
            // No refresh token, user must re-authenticate
            sessionState = .expired
            logDebug("Session expired - re-authentication required")
        }
    }

    /// Attempt to silently refresh the session
    public func attemptSilentRefresh() async {
        guard !isRefreshing else {
            logDebug("Silent refresh already in progress")
            return
        }

        isRefreshing = true
        sessionState = .refreshing

        do {
            try await authManager.refreshTokenIfNeeded()

            // Update state after successful refresh
            if authManager.isAuthenticated, let user = authManager.currentUser {
                sessionState = .authenticated(user)
                updateTimeUntilExpiry()
                logDebug("Silent refresh successful")
            } else {
                sessionState = .expired
            }
        } catch {
            logError("Silent refresh failed: \(error)")

            // Check if error requires re-authentication
            if let authError = error as? AuthenticationError, authError.requiresReauthentication {
                sessionState = .expired
            } else {
                sessionState = .error(error.localizedDescription)
            }
        }

        isRefreshing = false
    }

    /// Force logout and clear session
    public func forceLogout() async {
        await authManager.logout()
        sessionState = .loggedOut
        timeUntilExpiry = nil
        stopMonitoring()
    }

    // MARK: - Private Methods

    private func setupObservers() {
        // Observe authentication manager changes
        authManager.$isAuthenticated
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isAuthenticated in
                self?.handleAuthenticationChange(isAuthenticated: isAuthenticated)
            }
            .store(in: &cancellables)

        authManager.$currentUser
            .receive(on: DispatchQueue.main)
            .sink { [weak self] user in
                self?.handleUserChange(user: user)
            }
            .store(in: &cancellables)
    }

    private func setupAppLifecycleObservers() {
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.handleAppForeground()
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.handleAppBackground()
            }
            .store(in: &cancellables)
    }

    private func handleAuthenticationChange(isAuthenticated: Bool) {
        logDebug("Authentication state changed: \(isAuthenticated)")

        if isAuthenticated {
            if let user = authManager.currentUser {
                sessionState = .authenticated(user)
            }
            updateTimeUntilExpiry()
        } else {
            sessionState = .loggedOut
            timeUntilExpiry = nil
        }
    }

    private func handleUserChange(user: User?) {
        if let user = user {
            sessionState = .authenticated(user)
        }
    }

    private func handleAppForeground() async {
        logDebug("App entering foreground - checking session")

        // Check if session is still valid
        if !tokenStorage.isAccessTokenValid && tokenStorage.hasRefreshToken {
            await attemptSilentRefresh()
        } else {
            syncStateFromAuthManager()
            updateTimeUntilExpiry()
        }

        // Restart timer
        startSessionCheckTimer()
    }

    private func handleAppBackground() {
        logDebug("App entering background - pausing session monitoring")
        sessionCheckTimer?.invalidate()
        sessionCheckTimer = nil
    }

    private func startSessionCheckTimer() {
        sessionCheckTimer?.invalidate()

        sessionCheckTimer = Timer.scheduledTimer(
            withTimeInterval: sessionCheckInterval,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.performSessionCheck()
            }
        }
    }

    private func performSessionCheck() async {
        updateTimeUntilExpiry()

        // Check if we should proactively refresh
        if let timeUntil = timeUntilExpiry, timeUntil < refreshThreshold {
            logDebug("Token expiring soon (\(Int(timeUntil))s) - attempting refresh")
            await attemptSilentRefresh()
        }

        // Check if session has expired
        if !tokenStorage.isAccessTokenValid && !tokenStorage.hasRefreshToken {
            logDebug("Session fully expired")
            sessionState = .expired
        }
    }

    private func syncStateFromAuthManager() {
        if authManager.isAuthenticated, let user = authManager.currentUser {
            sessionState = .authenticated(user)
        } else if tokenStorage.hasRefreshToken {
            sessionState = .expired
        } else {
            sessionState = .loggedOut
        }
    }

    private func updateTimeUntilExpiry() {
        timeUntilExpiry = tokenStorage.timeUntilExpiry
    }

    // MARK: - Logging

    private func logDebug(_ message: String) {
        #if DEBUG
        logger.debug("\(message, privacy: .public)")
        #endif
    }

    private func logError(_ message: String) {
        logger.error("\(message, privacy: .public)")
    }
}

// MARK: - Session Info

extension SessionManager {
    /// Computed property for easy access to authenticated user
    public var currentUser: User? {
        if case .authenticated(let user) = sessionState {
            return user
        }
        return nil
    }

    /// Whether the user is currently authenticated
    public var isAuthenticated: Bool {
        if case .authenticated = sessionState {
            return true
        }
        return false
    }

    /// Whether re-authentication is required
    public var requiresReauthentication: Bool {
        switch sessionState {
        case .expired, .error:
            return true
        default:
            return false
        }
    }

    /// Human-readable session status
    public var statusDescription: String {
        switch sessionState {
        case .unknown:
            return "Checking session..."
        case .authenticated(let user):
            if let time = timeUntilExpiry {
                let minutes = Int(time / 60)
                return "Signed in as \(user.displayName) (\(minutes)m remaining)"
            }
            return "Signed in as \(user.displayName)"
        case .expired:
            return "Session expired - please sign in again"
        case .loggedOut:
            return "Not signed in"
        case .refreshing:
            return "Refreshing session..."
        case .error(let message):
            return "Session error: \(message)"
        }
    }
}

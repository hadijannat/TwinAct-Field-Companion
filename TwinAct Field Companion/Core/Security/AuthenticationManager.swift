//
//  AuthenticationManager.swift
//  TwinAct Field Companion
//
//  Main authentication coordinator for OAuth2 + PKCE flow.
//

import Foundation
import AuthenticationServices
import os.log
import Combine

/// Manages OAuth2 + PKCE authentication flow
@MainActor
public final class AuthenticationManager: NSObject, ObservableObject {

    // MARK: - Published State

    /// Whether the user is currently authenticated
    @Published public private(set) var isAuthenticated: Bool = false

    /// The currently authenticated user
    @Published public private(set) var currentUser: User?

    /// Whether an authentication operation is in progress
    @Published public private(set) var isLoading: Bool = false

    /// The most recent authentication error
    @Published public private(set) var error: AuthenticationError?

    // MARK: - Private Properties

    private var config: OIDCConfiguration
    private let tokenStorage: TokenStorage
    private let discoveryService: OIDCDiscoveryService
    private let logger: Logger

    /// Current PKCE parameters (kept during auth flow)
    private var currentPKCE: PKCEParameters?

    /// Current auth session
    private var authSession: ASWebAuthenticationSession?

    /// Presentation context provider for auth session
    private weak var presentationContextProvider: ASWebAuthenticationPresentationContextProviding?

    // MARK: - Initialization

    /// Initialize the authentication manager
    /// - Parameters:
    ///   - configuration: OIDC configuration (defaults to environment-specific config)
    ///   - tokenStorage: Token storage instance
    ///   - discoveryService: OIDC discovery service
    public init(
        configuration: OIDCConfiguration = .default,
        tokenStorage: TokenStorage = TokenStorage(),
        discoveryService: OIDCDiscoveryService = OIDCDiscoveryService()
    ) {
        self.config = configuration
        self.tokenStorage = tokenStorage
        self.discoveryService = discoveryService
        self.logger = Logger(
            subsystem: Bundle.main.bundleIdentifier ?? "com.twinact.fieldcompanion",
            category: "AuthenticationManager"
        )
        super.init()

        // Restore session state on init
        Task {
            await restoreSession()
        }
    }

    // MARK: - Public API

    /// Set the presentation context provider for the auth session
    /// - Parameter provider: The context provider (typically a view controller or window scene)
    public func setPresentationContextProvider(_ provider: ASWebAuthenticationPresentationContextProviding) {
        self.presentationContextProvider = provider
    }

    /// Start the login flow
    public func login() async throws {
        guard !isLoading else {
            logDebug("Login already in progress")
            return
        }

        isLoading = true
        error = nil

        do {
            // Step 1: Discover OIDC endpoints if needed
            if !config.isDiscovered {
                logDebug("Discovering OIDC endpoints")
                config = try await discoveryService.discover(configuration: config)
            }

            // Step 2: Generate PKCE parameters
            let pkce = PKCEParameters()
            currentPKCE = pkce
            logDebug("Generated PKCE parameters")

            // Step 3: Build authorization URL
            guard let authURL = buildAuthorizationURL(pkce: pkce) else {
                throw AuthenticationError.configurationError(message: "Failed to build authorization URL")
            }
            logDebug("Authorization URL: \(authURL)")

            // Step 4: Present auth session and get callback
            let callbackURL = try await presentAuthSession(url: authURL)
            logDebug("Received callback URL")

            // Step 5: Extract authorization code from callback
            let authCode = try extractAuthorizationCode(from: callbackURL, expectedState: pkce.state)
            logDebug("Extracted authorization code")

            // Step 6: Exchange code for tokens
            let tokenResponse = try await exchangeCodeForTokens(
                code: authCode,
                codeVerifier: pkce.codeVerifier
            )
            logDebug("Token exchange successful")

            // Step 7: Store tokens
            tokenStorage.storeTokens(
                accessToken: tokenResponse.accessToken,
                refreshToken: tokenResponse.refreshToken,
                idToken: tokenResponse.idToken,
                expiresIn: tokenResponse.expiresIn
            )

            // Step 8: Parse user from ID token
            if let idToken = tokenResponse.idToken, let user = User.from(idToken: idToken) {
                currentUser = user
            } else {
                // Fallback: fetch user info from endpoint
                currentUser = try await fetchUserInfo()
            }

            // Step 9: Update state
            isAuthenticated = true
            currentPKCE = nil
            logDebug("Login completed successfully")

        } catch {
            logError("Login failed: \(error)")
            currentPKCE = nil
            self.error = error as? AuthenticationError ?? .networkError(underlying: error)
            throw self.error!
        }

        isLoading = false
    }

    /// Logout and clear all tokens
    public func logout() async {
        logDebug("Logging out")

        // Try to call end_session endpoint if available
        if let endSessionEndpoint = config.endSessionEndpoint,
           let idToken = tokenStorage.idToken {
            await performLogoutRequest(endpoint: endSessionEndpoint, idToken: idToken)
        }

        // Clear local state
        tokenStorage.clearAll()
        currentUser = nil
        isAuthenticated = false
        error = nil

        logDebug("Logout completed")
    }

    /// Refresh the access token if needed
    public func refreshTokenIfNeeded() async throws {
        // Check if token is still valid
        guard !tokenStorage.isAccessTokenValid else {
            logDebug("Access token still valid")
            return
        }

        guard let refreshToken = tokenStorage.refreshToken else {
            logError("No refresh token available")
            throw AuthenticationError.noRefreshToken
        }

        logDebug("Refreshing access token")
        try await refreshAccessToken(refreshToken: refreshToken)
    }

    /// Get the current valid access token
    /// - Returns: The access token
    /// - Throws: AuthenticationError if not authenticated or token refresh fails
    public func getAccessToken() async throws -> String {
        try await refreshTokenIfNeeded()

        guard let token = tokenStorage.accessToken else {
            throw AuthenticationError.notAuthenticated
        }

        return token
    }

    /// Check if session can be restored from stored tokens
    public func canRestoreSession() -> Bool {
        tokenStorage.accessToken != nil || tokenStorage.refreshToken != nil
    }

    // MARK: - Private Methods - Auth Flow

    private func buildAuthorizationURL(pkce: PKCEParameters) -> URL? {
        guard let authEndpoint = config.authorizationEndpoint else {
            return nil
        }

        var components = URLComponents(url: authEndpoint, resolvingAgainstBaseURL: true)
        var queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: config.clientId),
            URLQueryItem(name: "redirect_uri", value: config.redirectURI.absoluteString),
            URLQueryItem(name: "scope", value: config.scopeString),
            URLQueryItem(name: "state", value: pkce.state),
            URLQueryItem(name: "code_challenge", value: pkce.codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: pkce.codeChallengeMethod)
        ]

        if let nonce = pkce.nonce {
            queryItems.append(URLQueryItem(name: "nonce", value: nonce))
        }

        components?.queryItems = queryItems
        return components?.url
    }

    private func presentAuthSession(url: URL) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let scheme = config.redirectURI.scheme

            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: scheme
            ) { callbackURL, error in
                if let error = error as? ASWebAuthenticationSessionError {
                    switch error.code {
                    case .canceledLogin:
                        continuation.resume(throwing: AuthenticationError.loginCancelled)
                    default:
                        continuation.resume(throwing: AuthenticationError.networkError(underlying: error))
                    }
                    return
                }

                if let error = error {
                    continuation.resume(throwing: AuthenticationError.networkError(underlying: error))
                    return
                }

                guard let callbackURL = callbackURL else {
                    continuation.resume(throwing: AuthenticationError.invalidResponse)
                    return
                }

                continuation.resume(returning: callbackURL)
            }

            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false

            authSession = session

            if !session.start() {
                continuation.resume(
                    throwing: AuthenticationError.configurationError(
                        message: "Failed to start authentication session"
                    )
                )
            }
        }
    }

    private func extractAuthorizationCode(from url: URL, expectedState: String) throws -> String {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
            throw AuthenticationError.invalidResponse
        }

        // Check for error response
        if let errorCode = components.queryItems?.first(where: { $0.name == "error" })?.value {
            let errorDescription = components.queryItems?
                .first(where: { $0.name == "error_description" })?.value
            throw AuthenticationError.tokenExchangeFailed(
                message: errorDescription ?? errorCode
            )
        }

        // Validate state parameter (CSRF protection)
        guard let state = components.queryItems?.first(where: { $0.name == "state" })?.value,
              state == expectedState else {
            throw AuthenticationError.invalidState
        }

        // Extract authorization code
        guard let code = components.queryItems?.first(where: { $0.name == "code" })?.value,
              !code.isEmpty else {
            throw AuthenticationError.invalidAuthorizationCode
        }

        return code
    }

    private func exchangeCodeForTokens(code: String, codeVerifier: String) async throws -> TokenResponse {
        guard let tokenEndpoint = config.tokenEndpoint else {
            throw AuthenticationError.configurationError(message: "Token endpoint not discovered")
        }

        var request = URLRequest(url: tokenEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let params: [String: String] = [
            "grant_type": "authorization_code",
            "client_id": config.clientId,
            "code": code,
            "redirect_uri": config.redirectURI.absoluteString,
            "code_verifier": codeVerifier
        ]

        request.httpBody = params
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthenticationError.invalidResponse
        }

        if httpResponse.statusCode != 200 {
            // Try to parse error response
            if let errorResponse = try? JSONDecoder().decode(TokenErrorResponse.self, from: data) {
                throw AuthenticationError.tokenExchangeFailed(
                    message: errorResponse.errorDescription ?? errorResponse.error
                )
            }
            throw AuthenticationError.tokenExchangeFailed(
                message: "HTTP \(httpResponse.statusCode)"
            )
        }

        do {
            return try JSONDecoder().decode(TokenResponse.self, from: data)
        } catch {
            throw AuthenticationError.invalidTokenResponse
        }
    }

    private func refreshAccessToken(refreshToken: String) async throws {
        guard let tokenEndpoint = config.tokenEndpoint else {
            // Try to discover endpoints
            config = try await discoveryService.discover(configuration: config)
            guard let endpoint = config.tokenEndpoint else {
                throw AuthenticationError.configurationError(message: "Token endpoint not discovered")
            }
            try await performTokenRefresh(endpoint: endpoint, refreshToken: refreshToken)
            return
        }

        try await performTokenRefresh(endpoint: tokenEndpoint, refreshToken: refreshToken)
    }

    private func performTokenRefresh(endpoint: URL, refreshToken: String) async throws {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let params: [String: String] = [
            "grant_type": "refresh_token",
            "client_id": config.clientId,
            "refresh_token": refreshToken
        ]

        request.httpBody = params
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthenticationError.invalidResponse
        }

        if httpResponse.statusCode != 200 {
            if let errorResponse = try? JSONDecoder().decode(TokenErrorResponse.self, from: data) {
                throw AuthenticationError.tokenRefreshFailed(
                    underlying: NSError(
                        domain: "OAuth",
                        code: httpResponse.statusCode,
                        userInfo: [NSLocalizedDescriptionKey: errorResponse.errorDescription ?? errorResponse.error]
                    )
                )
            }
            throw AuthenticationError.tokenRefreshFailed(
                underlying: NSError(
                    domain: "OAuth",
                    code: httpResponse.statusCode,
                    userInfo: [NSLocalizedDescriptionKey: "HTTP \(httpResponse.statusCode)"]
                )
            )
        }

        let tokenResponse: TokenResponse
        do {
            tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
        } catch {
            throw AuthenticationError.invalidTokenResponse
        }

        // Store new tokens (refresh token might be rotated)
        tokenStorage.storeTokens(
            accessToken: tokenResponse.accessToken,
            refreshToken: tokenResponse.refreshToken ?? refreshToken,
            idToken: tokenResponse.idToken ?? tokenStorage.idToken,
            expiresIn: tokenResponse.expiresIn
        )

        logDebug("Token refresh successful")
    }

    private func fetchUserInfo() async throws -> User {
        guard let userInfoEndpoint = config.userInfoEndpoint else {
            throw AuthenticationError.configurationError(message: "UserInfo endpoint not discovered")
        }

        guard let accessToken = tokenStorage.accessToken else {
            throw AuthenticationError.notAuthenticated
        }

        var request = URLRequest(url: userInfoEndpoint)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw AuthenticationError.userInfoFailed
        }

        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            return try decoder.decode(User.self, from: data)
        } catch {
            throw AuthenticationError.userInfoFailed
        }
    }

    private func performLogoutRequest(endpoint: URL, idToken: String) async {
        var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: true)
        components?.queryItems = [
            URLQueryItem(name: "id_token_hint", value: idToken),
            URLQueryItem(name: "post_logout_redirect_uri", value: config.redirectURI.absoluteString)
        ]

        guard let logoutURL = components?.url else { return }

        var request = URLRequest(url: logoutURL)
        request.httpMethod = "GET"

        do {
            _ = try await URLSession.shared.data(for: request)
            logDebug("Server logout successful")
        } catch {
            logError("Server logout failed: \(error)")
            // Continue with local logout even if server logout fails
        }
    }

    private func restoreSession() async {
        // Check if we have stored tokens
        guard let user = tokenStorage.userData else {
            logDebug("No stored session to restore")
            return
        }

        // Check if access token is valid or we have a refresh token
        if tokenStorage.isAccessTokenValid {
            currentUser = user
            isAuthenticated = true
            logDebug("Session restored with valid access token")
        } else if tokenStorage.hasRefreshToken {
            // Try to refresh the token
            do {
                try await refreshTokenIfNeeded()
                currentUser = tokenStorage.userData
                isAuthenticated = true
                logDebug("Session restored after token refresh")
            } catch {
                logError("Failed to restore session: \(error)")
                // Clear invalid session
                tokenStorage.clearAll()
            }
        } else {
            logDebug("Stored session expired and no refresh token")
            tokenStorage.clearAll()
        }
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

// MARK: - ASWebAuthenticationPresentationContextProviding

extension AuthenticationManager: ASWebAuthenticationPresentationContextProviding {
    public func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        // Try to get the key window from the connected scenes
        let scenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }

        // Strategy 1: Get key window from foreground active scene
        if let windowScene = scenes.first(where: { $0.activationState == .foregroundActive }),
           let window = windowScene.windows.first(where: { $0.isKeyWindow }) {
            return window
        }

        // Strategy 2: Get any window from any scene
        if let window = scenes.flatMap({ $0.windows }).first {
            return window
        }

        // Strategy 3: Create a new window from any available scene
        if let fallbackScene = scenes.first {
            return UIWindow(windowScene: fallbackScene)
        }

        // This should never happen in a normal iOS app lifecycle.
        // Log detailed diagnostics before failing.
        let allScenes = UIApplication.shared.connectedScenes
        logger.fault("No UIWindowScene available for authentication. Total scenes: \(allScenes.count), UIWindowScenes: \(scenes.count)")
        for (index, scene) in allScenes.enumerated() {
            logger.fault("Scene \(index): \(type(of: scene)), state: \(scene.activationState.rawValue)")
        }

        // As a last resort, try to create a window without a scene (iOS 13+)
        // This may not work correctly but is better than crashing
        if #available(iOS 15.0, *) {
            logger.warning("Attempting to create UIWindow without scene as last resort")
            return UIWindow(frame: UIScreen.main.bounds)
        }

        preconditionFailure("No UIWindowScene available for authentication presentation. Check logs for diagnostics.")
    }
}

// MARK: - Token Provider for HTTPClient

extension AuthenticationManager {
    /// Create a token provider closure for use with HTTPClient
    public var tokenProvider: TokenProvider {
        { [weak self] in
            guard let self = self else { return nil }
            return try? await self.getAccessToken()
        }
    }
}

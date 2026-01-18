//
//  OIDCConfiguration.swift
//  TwinAct Field Companion
//
//  OpenID Connect configuration and endpoint discovery.
//

import Foundation
import os.log

/// OpenID Connect / OAuth2 configuration
public struct OIDCConfiguration: Sendable {

    // MARK: - Required Properties

    /// The OIDC issuer URL (e.g., https://auth.example.com)
    public let issuer: URL

    /// OAuth2 client identifier
    public let clientId: String

    /// Redirect URI for authorization callback (e.g., twinact://callback)
    public let redirectURI: URL

    /// OAuth2 scopes to request
    public let scopes: [String]

    // MARK: - Discovered Endpoints

    /// Authorization endpoint URL
    public var authorizationEndpoint: URL?

    /// Token endpoint URL
    public var tokenEndpoint: URL?

    /// UserInfo endpoint URL
    public var userInfoEndpoint: URL?

    /// End session (logout) endpoint URL
    public var endSessionEndpoint: URL?

    /// JWKS URI for token validation
    public var jwksURI: URL?

    /// Revocation endpoint URL
    public var revocationEndpoint: URL?

    // MARK: - Initialization

    /// Create OIDC configuration with required parameters
    /// - Parameters:
    ///   - issuer: The OIDC issuer URL
    ///   - clientId: OAuth2 client identifier
    ///   - redirectURI: Redirect URI for callbacks
    ///   - scopes: OAuth2 scopes to request
    public init(
        issuer: URL,
        clientId: String,
        redirectURI: URL,
        scopes: [String] = ["openid", "profile", "email"]
    ) {
        self.issuer = issuer
        self.clientId = clientId
        self.redirectURI = redirectURI
        self.scopes = scopes
    }

    // MARK: - Discovery

    /// URL for the OpenID Connect discovery document
    public var discoveryURL: URL {
        issuer.appendingPathComponent(".well-known/openid-configuration")
    }

    /// Whether endpoints have been discovered
    public var isDiscovered: Bool {
        authorizationEndpoint != nil && tokenEndpoint != nil
    }

    /// Scopes as a space-separated string
    public var scopeString: String {
        scopes.joined(separator: " ")
    }
}

// MARK: - OIDC Discovery Response

/// Response from .well-known/openid-configuration
public struct OIDCDiscoveryDocument: Decodable, Sendable {
    public let issuer: String
    public let authorizationEndpoint: String
    public let tokenEndpoint: String
    public let userInfoEndpoint: String?
    public let endSessionEndpoint: String?
    public let jwksUri: String?
    public let revocationEndpoint: String?
    public let responseTypesSupported: [String]?
    public let subjectTypesSupported: [String]?
    public let idTokenSigningAlgValuesSupported: [String]?
    public let scopesSupported: [String]?
    public let tokenEndpointAuthMethodsSupported: [String]?
    public let claimsSupported: [String]?
    public let codeChallengeMethodsSupported: [String]?

    enum CodingKeys: String, CodingKey {
        case issuer
        case authorizationEndpoint = "authorization_endpoint"
        case tokenEndpoint = "token_endpoint"
        case userInfoEndpoint = "userinfo_endpoint"
        case endSessionEndpoint = "end_session_endpoint"
        case jwksUri = "jwks_uri"
        case revocationEndpoint = "revocation_endpoint"
        case responseTypesSupported = "response_types_supported"
        case subjectTypesSupported = "subject_types_supported"
        case idTokenSigningAlgValuesSupported = "id_token_signing_alg_values_supported"
        case scopesSupported = "scopes_supported"
        case tokenEndpointAuthMethodsSupported = "token_endpoint_auth_methods_supported"
        case claimsSupported = "claims_supported"
        case codeChallengeMethodsSupported = "code_challenge_methods_supported"
    }

    /// Whether PKCE S256 is supported
    public var supportsPKCE: Bool {
        codeChallengeMethodsSupported?.contains("S256") ?? true // Assume supported if not specified
    }
}

// MARK: - OIDC Discovery Service

/// Service for discovering OIDC endpoints
public actor OIDCDiscoveryService {

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.twinact.fieldcompanion",
        category: "OIDCDiscovery"
    )

    private let session: URLSession
    private var cachedDocument: OIDCDiscoveryDocument?
    private var cacheExpiry: Date?

    /// Cache duration for discovery document (1 hour)
    private let cacheDuration: TimeInterval = 3600

    public init(session: URLSession = .shared) {
        self.session = session
    }

    /// Discover OIDC endpoints and update configuration
    /// - Parameter configuration: The configuration to update with discovered endpoints
    /// - Returns: Updated configuration with discovered endpoints
    public func discover(
        configuration: OIDCConfiguration
    ) async throws -> OIDCConfiguration {
        // Check cache first
        if let cached = cachedDocument,
           let expiry = cacheExpiry,
           Date() < expiry {
            logDebug("Using cached discovery document")
            return configuration.withDiscoveredEndpoints(from: cached)
        }

        logDebug("Fetching discovery document from \(configuration.discoveryURL)")

        let request = URLRequest(url: configuration.discoveryURL)
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthenticationError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            logError("Discovery failed with status \(httpResponse.statusCode)")
            throw AuthenticationError.discoveryFailed(
                underlying: NSError(
                    domain: "OIDCDiscovery",
                    code: httpResponse.statusCode,
                    userInfo: [NSLocalizedDescriptionKey: "HTTP \(httpResponse.statusCode)"]
                )
            )
        }

        let decoder = JSONDecoder()
        let document: OIDCDiscoveryDocument
        do {
            document = try decoder.decode(OIDCDiscoveryDocument.self, from: data)
        } catch {
            logError("Failed to decode discovery document: \(error)")
            throw AuthenticationError.discoveryFailed(underlying: error)
        }

        // Validate PKCE support
        if !document.supportsPKCE {
            logError("OIDC provider does not support PKCE S256")
            throw AuthenticationError.configurationError(
                message: "Identity provider does not support PKCE"
            )
        }

        // Cache the document
        cachedDocument = document
        cacheExpiry = Date().addingTimeInterval(cacheDuration)

        logDebug("Discovery successful")
        return configuration.withDiscoveredEndpoints(from: document)
    }

    /// Clear the cached discovery document
    public func clearCache() {
        cachedDocument = nil
        cacheExpiry = nil
    }

    private func logDebug(_ message: String) {
        #if DEBUG
        logger.debug("\(message, privacy: .public)")
        #endif
    }

    private func logError(_ message: String) {
        logger.error("\(message, privacy: .public)")
    }
}

// MARK: - Configuration Extension

extension OIDCConfiguration {
    /// Create a new configuration with discovered endpoints
    func withDiscoveredEndpoints(from document: OIDCDiscoveryDocument) -> OIDCConfiguration {
        var config = self
        config.authorizationEndpoint = URL(string: document.authorizationEndpoint)
        config.tokenEndpoint = URL(string: document.tokenEndpoint)
        config.userInfoEndpoint = document.userInfoEndpoint.flatMap { URL(string: $0) }
        config.endSessionEndpoint = document.endSessionEndpoint.flatMap { URL(string: $0) }
        config.jwksURI = document.jwksUri.flatMap { URL(string: $0) }
        config.revocationEndpoint = document.revocationEndpoint.flatMap { URL(string: $0) }
        return config
    }
}

// MARK: - Environment-Specific Configuration

extension OIDCConfiguration {
    /// Default configuration based on current environment
    public static var `default`: OIDCConfiguration {
        switch AppConfiguration.current {
        case .development:
            return OIDCConfiguration(
                issuer: URL(string: "http://localhost:8080/auth/realms/twinact")!,
                clientId: "twinact-mobile",
                redirectURI: URL(string: "twinact://callback")!,
                scopes: ["openid", "profile", "email", "aas"]
            )
        case .staging:
            return OIDCConfiguration(
                // TODO: Replace with actual staging auth URL
                issuer: URL(string: "https://staging-auth.example.com/realms/twinact")!,
                clientId: "twinact-mobile",
                redirectURI: URL(string: "twinact://callback")!,
                scopes: ["openid", "profile", "email", "aas"]
            )
        case .production:
            return OIDCConfiguration(
                // TODO: Replace with actual production auth URL
                issuer: URL(string: "https://auth.example.com/realms/twinact")!,
                clientId: "twinact-mobile",
                redirectURI: URL(string: "twinact://callback")!,
                scopes: ["openid", "profile", "email", "aas"]
            )
        }
    }
}

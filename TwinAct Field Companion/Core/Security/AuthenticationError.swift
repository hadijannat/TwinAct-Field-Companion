//
//  AuthenticationError.swift
//  TwinAct Field Companion
//
//  Authentication-specific errors for OAuth2 + PKCE flow.
//

import Foundation

/// Errors that can occur during authentication operations
public enum AuthenticationError: Error, LocalizedError, Sendable {
    /// User is not authenticated
    case notAuthenticated

    /// User cancelled the login flow
    case loginCancelled

    /// OAuth state parameter mismatch (potential CSRF attack)
    case invalidState

    /// No refresh token available for token refresh
    case noRefreshToken

    /// Token refresh failed
    case tokenRefreshFailed(underlying: Error)

    /// OIDC discovery failed
    case discoveryFailed(underlying: Error)

    /// Network error during authentication
    case networkError(underlying: Error)

    /// Invalid response from auth server
    case invalidResponse

    /// Failed to fetch user info
    case userInfoFailed

    /// Token exchange failed
    case tokenExchangeFailed(message: String)

    /// Invalid authorization code
    case invalidAuthorizationCode

    /// Invalid token response
    case invalidTokenResponse

    /// Session expired
    case sessionExpired

    /// Configuration error
    case configurationError(message: String)

    /// Keychain error
    case keychainError(status: OSStatus)

    /// ID token parsing failed
    case idTokenParsingFailed

    public var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You are not authenticated. Please log in."
        case .loginCancelled:
            return "Login was cancelled."
        case .invalidState:
            return "Authentication failed due to invalid state. Please try again."
        case .noRefreshToken:
            return "Session expired. Please log in again."
        case .tokenRefreshFailed(let underlying):
            return "Failed to refresh session: \(underlying.localizedDescription)"
        case .discoveryFailed(let underlying):
            return "Failed to connect to authentication server: \(underlying.localizedDescription)"
        case .networkError(let underlying):
            return "Network error during authentication: \(underlying.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from authentication server."
        case .userInfoFailed:
            return "Failed to retrieve user information."
        case .tokenExchangeFailed(let message):
            return "Token exchange failed: \(message)"
        case .invalidAuthorizationCode:
            return "Invalid authorization code received."
        case .invalidTokenResponse:
            return "Invalid token response from server."
        case .sessionExpired:
            return "Your session has expired. Please log in again."
        case .configurationError(let message):
            return "Configuration error: \(message)"
        case .keychainError(let status):
            return "Secure storage error (status: \(status))"
        case .idTokenParsingFailed:
            return "Failed to parse identity token."
        }
    }

    /// Whether this error might be recoverable by retrying
    public var isRetryable: Bool {
        switch self {
        case .networkError, .discoveryFailed:
            return true
        case .notAuthenticated, .loginCancelled, .invalidState, .noRefreshToken,
             .tokenRefreshFailed, .invalidResponse, .userInfoFailed,
             .tokenExchangeFailed, .invalidAuthorizationCode, .invalidTokenResponse,
             .sessionExpired, .configurationError, .keychainError, .idTokenParsingFailed:
            return false
        }
    }

    /// Whether the user should be prompted to log in again
    public var requiresReauthentication: Bool {
        switch self {
        case .notAuthenticated, .noRefreshToken, .tokenRefreshFailed,
             .sessionExpired, .invalidState:
            return true
        case .loginCancelled, .discoveryFailed, .networkError, .invalidResponse,
             .userInfoFailed, .tokenExchangeFailed, .invalidAuthorizationCode,
             .invalidTokenResponse, .configurationError, .keychainError, .idTokenParsingFailed:
            return false
        }
    }
}

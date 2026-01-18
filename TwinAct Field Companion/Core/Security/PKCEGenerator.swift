//
//  PKCEGenerator.swift
//  TwinAct Field Companion
//
//  Generates PKCE (Proof Key for Code Exchange) parameters for OAuth2 security.
//  PKCE prevents authorization code interception attacks.
//

import Foundation
import CryptoKit

/// Generates PKCE (Proof Key for Code Exchange) parameters for secure OAuth2 flows
public struct PKCEGenerator {

    // MARK: - Constants

    /// Minimum length for code verifier per RFC 7636
    private static let minVerifierLength = 43

    /// Maximum length for code verifier per RFC 7636
    private static let maxVerifierLength = 128

    /// Number of random bytes to generate (will be base64-encoded to ~43 chars)
    private static let randomByteCount = 32

    // MARK: - Code Verifier Generation

    /// Generate a cryptographically random code verifier
    /// - Returns: A URL-safe base64-encoded string (43-128 characters)
    public static func generateCodeVerifier() -> String {
        var buffer = [UInt8](repeating: 0, count: randomByteCount)
        let status = SecRandomCopyBytes(kSecRandomDefault, buffer.count, &buffer)

        guard status == errSecSuccess else {
            // Fallback to less secure but functional random generation
            // This should rarely happen on iOS
            buffer = (0..<randomByteCount).map { _ in UInt8.random(in: 0...255) }
        }

        return Data(buffer).base64URLEncodedString()
    }

    // MARK: - Code Challenge Generation

    /// Generate code challenge from verifier using SHA256 (S256 method)
    /// - Parameter verifier: The code verifier string
    /// - Returns: Base64URL-encoded SHA256 hash of the verifier
    public static func generateCodeChallenge(from verifier: String) -> String {
        let data = Data(verifier.utf8)
        let hash = SHA256.hash(data: data)
        return Data(hash).base64URLEncodedString()
    }

    // MARK: - State Generation

    /// Generate a random state parameter for CSRF protection
    /// - Returns: A URL-safe random string
    public static func generateState() -> String {
        var buffer = [UInt8](repeating: 0, count: 16)
        let status = SecRandomCopyBytes(kSecRandomDefault, buffer.count, &buffer)

        guard status == errSecSuccess else {
            buffer = (0..<16).map { _ in UInt8.random(in: 0...255) }
        }

        return Data(buffer).base64URLEncodedString()
    }

    // MARK: - Nonce Generation

    /// Generate a random nonce for ID token validation
    /// - Returns: A URL-safe random string
    public static func generateNonce() -> String {
        var buffer = [UInt8](repeating: 0, count: 16)
        let status = SecRandomCopyBytes(kSecRandomDefault, buffer.count, &buffer)

        guard status == errSecSuccess else {
            buffer = (0..<16).map { _ in UInt8.random(in: 0...255) }
        }

        return Data(buffer).base64URLEncodedString()
    }
}

// MARK: - PKCE Parameters

/// Complete PKCE parameters for an OAuth2 authorization request
public struct PKCEParameters: Sendable {
    /// The code verifier (kept secret, used in token exchange)
    public let codeVerifier: String

    /// The code challenge (sent in authorization request)
    public let codeChallenge: String

    /// The code challenge method (always "S256" for SHA256)
    public let codeChallengeMethod: String = "S256"

    /// Random state for CSRF protection
    public let state: String

    /// Random nonce for ID token validation (optional)
    public let nonce: String?

    // MARK: - Initialization

    /// Generate new PKCE parameters
    /// - Parameter includeNonce: Whether to include a nonce for ID token validation
    public init(includeNonce: Bool = true) {
        self.codeVerifier = PKCEGenerator.generateCodeVerifier()
        self.codeChallenge = PKCEGenerator.generateCodeChallenge(from: codeVerifier)
        self.state = PKCEGenerator.generateState()
        self.nonce = includeNonce ? PKCEGenerator.generateNonce() : nil
    }

    /// Create parameters with specific values (for testing)
    internal init(
        codeVerifier: String,
        codeChallenge: String,
        state: String,
        nonce: String?
    ) {
        self.codeVerifier = codeVerifier
        self.codeChallenge = codeChallenge
        self.state = state
        self.nonce = nonce
    }
}

// MARK: - Data Extension for Base64URL

extension Data {
    /// Encode data as base64url (URL-safe base64 without padding)
    /// - Returns: Base64URL-encoded string
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    /// Decode base64url-encoded string
    /// - Parameter string: Base64URL-encoded string
    /// - Returns: Decoded data, or nil if decoding fails
    static func base64URLDecoded(from string: String) -> Data? {
        var base64 = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        // Pad to multiple of 4
        let remainder = base64.count % 4
        if remainder > 0 {
            base64 += String(repeating: "=", count: 4 - remainder)
        }

        return Data(base64Encoded: base64)
    }
}

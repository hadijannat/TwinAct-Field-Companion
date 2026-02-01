//
//  User.swift
//  TwinAct Field Companion
//
//  Authenticated user information from ID token claims.
//

import Foundation
import os.log

/// Logger for authentication-related events
private let authLogger = Logger(subsystem: "com.twinact.fieldcompanion", category: "Authentication")

/// Authenticated user information extracted from OIDC ID token claims
public struct User: Codable, Sendable, Equatable, Identifiable {
    /// Unique user identifier (sub claim from ID token)
    public let id: String

    /// User's email address
    public let email: String?

    /// User's full display name
    public let name: String?

    /// User's given/first name
    public let givenName: String?

    /// User's family/last name
    public let familyName: String?

    /// URL to user's profile picture
    public let picture: URL?

    /// User roles (custom claim for authorization)
    public let roles: [String]?

    /// Organization/tenant identifier (if multi-tenant)
    public let organization: String?

    /// Timestamp when the user was authenticated
    public let authenticatedAt: Date

    // MARK: - Initialization

    public init(
        id: String,
        email: String? = nil,
        name: String? = nil,
        givenName: String? = nil,
        familyName: String? = nil,
        picture: URL? = nil,
        roles: [String]? = nil,
        organization: String? = nil,
        authenticatedAt: Date = Date()
    ) {
        self.id = id
        self.email = email
        self.name = name
        self.givenName = givenName
        self.familyName = familyName
        self.picture = picture
        self.roles = roles
        self.organization = organization
        self.authenticatedAt = authenticatedAt
    }

    // MARK: - Computed Properties

    /// Best available display name for the user
    public var displayName: String {
        if let name = name, !name.isEmpty {
            return name
        }
        if let givenName = givenName, !givenName.isEmpty {
            if let familyName = familyName, !familyName.isEmpty {
                return "\(givenName) \(familyName)"
            }
            return givenName
        }
        if let email = email, !email.isEmpty {
            return email
        }
        return "User"
    }

    /// User's initials for avatar display
    public var initials: String {
        let components: [String?] = [givenName, familyName]
        let initials = components
            .compactMap { $0?.first }
            .map { String($0).uppercased() }

        if initials.isEmpty {
            if let first = name?.first {
                return String(first).uppercased()
            }
            if let first = email?.first {
                return String(first).uppercased()
            }
            return "U"
        }

        return initials.prefix(2).joined()
    }

    /// Whether the user has the technician role (can modify asset data)
    public var isTechnician: Bool {
        roles?.contains { $0.lowercased() == "technician" || $0.lowercased() == "admin" } ?? false
    }

    /// Whether the user has viewer-only access
    public var isViewer: Bool {
        !isTechnician
    }

    /// Whether the user has admin privileges
    public var isAdmin: Bool {
        roles?.contains { $0.lowercased() == "admin" } ?? false
    }

    // MARK: - Coding Keys

    enum CodingKeys: String, CodingKey {
        case id = "sub"
        case email
        case name
        case givenName = "given_name"
        case familyName = "family_name"
        case picture
        case roles
        case organization = "org"
        case authenticatedAt = "authenticated_at"
    }
}

// MARK: - ID Token Parsing

extension User {
    /// Parse user from JWT ID token claims
    /// - Parameter idToken: The JWT ID token string
    /// - Returns: User if parsing succeeds, nil otherwise
    public static func from(idToken: String) -> User? {
        // JWT format: header.payload.signature
        let parts = idToken.components(separatedBy: ".")
        guard parts.count == 3 else { return nil }

        // Decode the payload (second part)
        let payload = parts[1]
        guard let data = base64URLDecode(payload) else { return nil }

        do {
            let decoder = JSONDecoder()
            let claims = try decoder.decode(IDTokenClaims.self, from: data)
            return User(
                id: claims.sub,
                email: claims.email,
                name: claims.name,
                givenName: claims.givenName,
                familyName: claims.familyName,
                picture: claims.picture.flatMap { URL(string: $0) },
                roles: claims.roles,
                organization: claims.org,
                authenticatedAt: Date()
            )
        } catch {
            authLogger.warning("Failed to decode ID token claims: \(error.localizedDescription)")
            return nil
        }
    }

    /// Decode base64url-encoded string (JWT uses base64url, not standard base64)
    private static func base64URLDecode(_ string: String) -> Data? {
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

// MARK: - ID Token Claims

/// Internal structure for decoding ID token claims
private struct IDTokenClaims: Decodable {
    let sub: String
    let email: String?
    let name: String?
    let givenName: String?
    let familyName: String?
    let picture: String?
    let roles: [String]?
    let org: String?

    // Standard OIDC claims we might use later
    let iss: String?        // Issuer
    let aud: String?        // Audience (can also be array)
    let exp: Int?           // Expiration time
    let iat: Int?           // Issued at
    let nonce: String?      // Nonce for replay protection

    enum CodingKeys: String, CodingKey {
        case sub
        case email
        case name
        case givenName = "given_name"
        case familyName = "family_name"
        case picture
        case roles
        case org
        case iss
        case aud
        case exp
        case iat
        case nonce
    }
}

// MARK: - Demo User

extension User {
    /// Demo user for development and testing
    public static let demo = User(
        id: "demo-user-001",
        email: "technician@twinact.example.com",
        name: "Demo Technician",
        givenName: "Demo",
        familyName: "Technician",
        picture: nil,
        roles: ["technician"],
        organization: "TwinAct Demo",
        authenticatedAt: Date()
    )

    /// Demo viewer (read-only) user
    public static let demoViewer = User(
        id: "demo-viewer-001",
        email: "viewer@twinact.example.com",
        name: "Demo Viewer",
        givenName: "Demo",
        familyName: "Viewer",
        picture: nil,
        roles: ["viewer"],
        organization: "TwinAct Demo",
        authenticatedAt: Date()
    )
}

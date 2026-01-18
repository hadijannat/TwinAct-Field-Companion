//
//  TokenStorage.swift
//  TwinAct Field Companion
//
//  Secure Keychain storage for authentication tokens.
//

import Foundation
import Security
import os.log

/// Securely stores authentication tokens in the iOS Keychain
public final class TokenStorage: @unchecked Sendable {

    // MARK: - Keychain Keys

    private let accessTokenKey = "com.twinact.fieldcompanion.accessToken"
    private let refreshTokenKey = "com.twinact.fieldcompanion.refreshToken"
    private let idTokenKey = "com.twinact.fieldcompanion.idToken"
    private let tokenExpiryKey = "com.twinact.fieldcompanion.tokenExpiry"
    private let userDataKey = "com.twinact.fieldcompanion.userData"

    // MARK: - Properties

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.twinact.fieldcompanion",
        category: "TokenStorage"
    )

    /// Service identifier for Keychain items
    private let service: String

    /// Access group for Keychain sharing (nil = app-only)
    private let accessGroup: String?

    // MARK: - Initialization

    /// Initialize token storage
    /// - Parameters:
    ///   - service: Service identifier for Keychain
    ///   - accessGroup: Access group for Keychain sharing (nil for app-only)
    public init(
        service: String = Bundle.main.bundleIdentifier ?? "com.twinact.fieldcompanion",
        accessGroup: String? = nil
    ) {
        self.service = service
        self.accessGroup = accessGroup
    }

    // MARK: - Token Accessors

    /// The current access token
    public var accessToken: String? {
        get { getString(forKey: accessTokenKey) }
        set { setString(newValue, forKey: accessTokenKey) }
    }

    /// The refresh token for obtaining new access tokens
    public var refreshToken: String? {
        get { getString(forKey: refreshTokenKey) }
        set { setString(newValue, forKey: refreshTokenKey) }
    }

    /// The ID token containing user claims
    public var idToken: String? {
        get { getString(forKey: idTokenKey) }
        set { setString(newValue, forKey: idTokenKey) }
    }

    /// When the access token expires
    public var tokenExpiry: Date? {
        get { getDate(forKey: tokenExpiryKey) }
        set { setDate(newValue, forKey: tokenExpiryKey) }
    }

    /// Cached user data
    public var userData: User? {
        get { getDecodable(forKey: userDataKey) }
        set { setEncodable(newValue, forKey: userDataKey) }
    }

    // MARK: - Token Validation

    /// Check if the access token is valid and not expired
    public var isAccessTokenValid: Bool {
        guard let token = accessToken, !token.isEmpty else {
            return false
        }

        // If no expiry is set, assume token is valid
        guard let expiry = tokenExpiry else {
            return true
        }

        // Add 60-second buffer before actual expiry
        let expiryWithBuffer = expiry.addingTimeInterval(-60)
        return Date() < expiryWithBuffer
    }

    /// Check if a refresh token is available
    public var hasRefreshToken: Bool {
        guard let token = refreshToken, !token.isEmpty else {
            return false
        }
        return true
    }

    /// Time until access token expires (negative if expired)
    public var timeUntilExpiry: TimeInterval? {
        guard let expiry = tokenExpiry else { return nil }
        return expiry.timeIntervalSinceNow
    }

    // MARK: - Batch Operations

    /// Store all tokens from a token response
    /// - Parameters:
    ///   - accessToken: The access token
    ///   - refreshToken: The refresh token (optional)
    ///   - idToken: The ID token (optional)
    ///   - expiresIn: Seconds until access token expires
    public func storeTokens(
        accessToken: String,
        refreshToken: String?,
        idToken: String?,
        expiresIn: Int?
    ) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.idToken = idToken

        if let expiresIn = expiresIn {
            self.tokenExpiry = Date().addingTimeInterval(TimeInterval(expiresIn))
        } else {
            self.tokenExpiry = nil
        }

        // Parse and store user from ID token
        if let idToken = idToken, let user = User.from(idToken: idToken) {
            self.userData = user
        }

        logDebug("Tokens stored successfully")
    }

    /// Clear all stored authentication data
    public func clearAll() {
        deleteItem(forKey: accessTokenKey)
        deleteItem(forKey: refreshTokenKey)
        deleteItem(forKey: idTokenKey)
        deleteItem(forKey: tokenExpiryKey)
        deleteItem(forKey: userDataKey)
        logDebug("All tokens cleared")
    }

    // MARK: - Keychain Operations - String

    private func setString(_ value: String?, forKey key: String) {
        if let value = value {
            let data = Data(value.utf8)
            saveItem(data: data, forKey: key)
        } else {
            deleteItem(forKey: key)
        }
    }

    private func getString(forKey key: String) -> String? {
        guard let data = loadItem(forKey: key) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    // MARK: - Keychain Operations - Date

    private func setDate(_ value: Date?, forKey key: String) {
        if let value = value {
            let timestamp = value.timeIntervalSince1970
            let data = withUnsafeBytes(of: timestamp) { Data($0) }
            saveItem(data: data, forKey: key)
        } else {
            deleteItem(forKey: key)
        }
    }

    private func getDate(forKey key: String) -> Date? {
        guard let data = loadItem(forKey: key),
              data.count == MemoryLayout<TimeInterval>.size else {
            return nil
        }

        let timestamp = data.withUnsafeBytes { $0.load(as: TimeInterval.self) }
        return Date(timeIntervalSince1970: timestamp)
    }

    // MARK: - Keychain Operations - Codable

    private func setEncodable<T: Encodable>(_ value: T?, forKey key: String) {
        if let value = value {
            do {
                let data = try JSONEncoder().encode(value)
                saveItem(data: data, forKey: key)
            } catch {
                logError("Failed to encode value for key \(key): \(error)")
            }
        } else {
            deleteItem(forKey: key)
        }
    }

    private func getDecodable<T: Decodable>(forKey key: String) -> T? {
        guard let data = loadItem(forKey: key) else { return nil }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            logError("Failed to decode value for key \(key): \(error)")
            return nil
        }
    }

    // MARK: - Core Keychain Operations

    private func saveItem(data: Data, forKey key: String) {
        // First try to update existing item
        let updateQuery = baseQuery(forKey: key)
        let updateAttributes: [String: Any] = [
            kSecValueData as String: data
        ]

        var status = SecItemUpdate(updateQuery as CFDictionary, updateAttributes as CFDictionary)

        if status == errSecItemNotFound {
            // Item doesn't exist, add it
            var addQuery = baseQuery(forKey: key)
            addQuery[kSecValueData as String] = data

            status = SecItemAdd(addQuery as CFDictionary, nil)
        }

        if status != errSecSuccess {
            logError("Failed to save keychain item for key \(key): \(status)")
        }
    }

    private func loadItem(forKey key: String) -> Data? {
        var query = baseQuery(forKey: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecSuccess {
            return result as? Data
        } else if status != errSecItemNotFound {
            logError("Failed to load keychain item for key \(key): \(status)")
        }

        return nil
    }

    private func deleteItem(forKey key: String) {
        let query = baseQuery(forKey: key)
        let status = SecItemDelete(query as CFDictionary)

        if status != errSecSuccess && status != errSecItemNotFound {
            logError("Failed to delete keychain item for key \(key): \(status)")
        }
    }

    private func baseQuery(forKey key: String) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }

        return query
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

// MARK: - Token Response

/// Response from OAuth2 token endpoint
public struct TokenResponse: Decodable, Sendable {
    public let accessToken: String
    public let tokenType: String
    public let expiresIn: Int?
    public let refreshToken: String?
    public let idToken: String?
    public let scope: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
        case refreshToken = "refresh_token"
        case idToken = "id_token"
        case scope
    }
}

/// Error response from OAuth2 token endpoint
public struct TokenErrorResponse: Decodable, Sendable {
    public let error: String
    public let errorDescription: String?
    public let errorUri: String?

    enum CodingKeys: String, CodingKey {
        case error
        case errorDescription = "error_description"
        case errorUri = "error_uri"
    }
}

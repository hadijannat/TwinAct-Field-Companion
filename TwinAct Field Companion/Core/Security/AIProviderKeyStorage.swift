//
//  AIProviderKeyStorage.swift
//  TwinAct Field Companion
//
//  Secure Keychain storage for AI provider API keys.
//

import Foundation
import Security
import os.log

/// Securely stores AI provider API keys in the iOS Keychain
public final class AIProviderKeyStorage: @unchecked Sendable {

    // MARK: - Properties

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.twinact.fieldcompanion",
        category: "AIProviderKeyStorage"
    )

    /// Service identifier for Keychain items
    private let service: String

    /// Base key prefix for provider API keys
    private let keyPrefix = "com.twinact.fieldcompanion.ai"

    // MARK: - Initialization

    /// Initialize API key storage
    /// - Parameter service: Service identifier for Keychain
    public init(
        service: String = Bundle.main.bundleIdentifier ?? "com.twinact.fieldcompanion"
    ) {
        self.service = service
    }

    // MARK: - Public API

    /// Store an API key for a provider
    /// - Parameters:
    ///   - apiKey: The API key to store
    ///   - provider: The provider type
    public func storeAPIKey(_ apiKey: String, for provider: AIProviderType) {
        let key = keychainKey(for: provider)
        let data = Data(apiKey.utf8)
        saveItem(data: data, forKey: key)
        logDebug("API key stored for provider: \(provider.rawValue)")
    }

    /// Retrieve the API key for a provider
    /// - Parameter provider: The provider type
    /// - Returns: The stored API key, or nil if not found
    public func apiKey(for provider: AIProviderType) -> String? {
        let key = keychainKey(for: provider)
        guard let data = loadItem(forKey: key) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Delete the API key for a provider
    /// - Parameter provider: The provider type
    public func deleteAPIKey(for provider: AIProviderType) {
        let key = keychainKey(for: provider)
        deleteItem(forKey: key)
        logDebug("API key deleted for provider: \(provider.rawValue)")
    }

    /// Check if an API key exists for a provider
    /// - Parameter provider: The provider type
    /// - Returns: True if an API key is stored
    public func hasAPIKey(for provider: AIProviderType) -> Bool {
        return apiKey(for: provider) != nil
    }

    /// Clear all stored API keys
    public func clearAll() {
        for provider in AIProviderType.allCases {
            deleteAPIKey(for: provider)
        }
        logDebug("All API keys cleared")
    }

    /// Get providers that have stored API keys
    /// - Returns: Array of provider types with stored keys
    public func providersWithStoredKeys() -> [AIProviderType] {
        AIProviderType.allCases.filter { hasAPIKey(for: $0) }
    }

    // MARK: - Private Helpers

    private func keychainKey(for provider: AIProviderType) -> String {
        "\(keyPrefix).\(provider.rawValue).apiKey"
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
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
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

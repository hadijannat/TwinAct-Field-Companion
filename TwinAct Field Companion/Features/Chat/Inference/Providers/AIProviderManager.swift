//
//  AIProviderManager.swift
//  TwinAct Field Companion
//
//  Manages AI provider lifecycle, configuration, and connection testing.
//

import Foundation
import os.log
import Combine

// MARK: - AI Provider Manager

/// Manages AI provider lifecycle, configuration, and instances
@MainActor
public final class AIProviderManager: ObservableObject {

    // MARK: - Published Properties

    /// Current configurations for all providers
    @Published public private(set) var configurations: [AIProviderType: AIProviderConfiguration] = [:]

    /// Currently active provider type
    @Published public var activeProviderType: AIProviderType {
        didSet {
            UserDefaults.standard.set(activeProviderType.rawValue, forKey: activeProviderKey)
            objectWillChange.send()
        }
    }

    /// Connection status for each provider
    @Published public private(set) var connectionStatus: [AIProviderType: AIProviderConnectionStatus] = [:]

    // MARK: - Private Properties

    private let keyStorage: AIProviderKeyStorage
    private let logger: Logger
    private var providerCache: [AIProviderType: any CloudAIProvider] = [:]

    private let configurationsKey = "com.twinact.fieldcompanion.ai.configurations"
    private let activeProviderKey = "com.twinact.fieldcompanion.ai.activeProvider"

    // MARK: - Initialization

    /// Initialize provider manager
    /// - Parameter keyStorage: Keychain storage for API keys
    public init(keyStorage: AIProviderKeyStorage = AIProviderKeyStorage()) {
        self.keyStorage = keyStorage
        self.logger = Logger(
            subsystem: AppConfiguration.AppInfo.bundleIdentifier,
            category: "AIProviderManager"
        )

        // Load active provider from UserDefaults
        if let storedType = UserDefaults.standard.string(forKey: activeProviderKey),
           let providerType = AIProviderType(rawValue: storedType) {
            self.activeProviderType = providerType
        } else {
            self.activeProviderType = AppConfiguration.GenAI.defaultProviderType
        }

        // Initialize connection status
        for provider in AIProviderType.allCases {
            connectionStatus[provider] = .unknown
        }

        // Load saved configurations
        loadConfigurations()
    }

    // MARK: - Configuration Management

    /// Get configuration for a provider
    /// - Parameter provider: Provider type
    /// - Returns: Configuration or default
    public func configuration(for provider: AIProviderType) -> AIProviderConfiguration {
        configurations[provider] ?? AIProviderConfiguration.defaultConfiguration(for: provider)
    }

    /// Save configuration for a provider
    /// - Parameter config: Configuration to save
    public func saveConfiguration(_ config: AIProviderConfiguration) {
        configurations[config.providerType] = config
        persistConfigurations()
        invalidateProvider(config.providerType)
        logger.info("Configuration saved for provider: \(config.providerType.rawValue)")
    }

    /// Reset configuration to defaults
    /// - Parameter provider: Provider to reset
    public func resetConfiguration(for provider: AIProviderType) {
        configurations[provider] = AIProviderConfiguration.defaultConfiguration(for: provider)
        persistConfigurations()
        invalidateProvider(provider)
        logger.info("Configuration reset for provider: \(provider.rawValue)")
    }

    // MARK: - API Key Management

    /// Store API key for a provider
    /// - Parameters:
    ///   - apiKey: API key to store
    ///   - provider: Provider type
    public func storeAPIKey(_ apiKey: String, for provider: AIProviderType) {
        keyStorage.storeAPIKey(apiKey, for: provider)
        invalidateProvider(provider)
        connectionStatus[provider] = .unknown
    }

    /// Get API key for a provider
    /// - Parameter provider: Provider type
    /// - Returns: API key or nil
    public func apiKey(for provider: AIProviderType) -> String? {
        keyStorage.apiKey(for: provider)
    }

    /// Check if API key exists for provider
    /// - Parameter provider: Provider type
    /// - Returns: True if key exists
    public func hasAPIKey(for provider: AIProviderType) -> Bool {
        keyStorage.hasAPIKey(for: provider)
    }

    /// Delete API key for a provider
    /// - Parameter provider: Provider type
    public func deleteAPIKey(for provider: AIProviderType) {
        keyStorage.deleteAPIKey(for: provider)
        invalidateProvider(provider)
        connectionStatus[provider] = .unknown
    }

    // MARK: - Provider Access

    /// Get or create a provider instance
    /// - Parameter type: Provider type
    /// - Returns: Provider instance
    public func provider(for type: AIProviderType) -> (any CloudAIProvider)? {
        // Return cached provider if available
        if let cached = providerCache[type] {
            return cached
        }

        // Create new provider
        var config = configuration(for: type)
        if type == .openRouter {
            config.baseURL = normalizedOpenRouterBaseURL(config.baseURL)
            config.modelId = normalizedOpenRouterModelId(config.modelId)
        }
        guard config.isEnabled else { return nil }

        let apiKey = self.apiKey(for: type)

        // Check if API key is required but missing
        if type.requiresAPIKey && apiKey == nil {
            logger.warning("API key required but not configured for: \(type.rawValue)")
            return nil
        }

        let provider = createProvider(type: type, config: config, apiKey: apiKey)
        providerCache[type] = provider
        return provider
    }

    /// Get the currently active provider
    /// - Returns: Active provider instance or nil
    public func activeProvider() -> (any CloudAIProvider)? {
        provider(for: activeProviderType)
    }

    /// Invalidate cached provider
    /// - Parameter type: Provider type to invalidate
    public func invalidateProvider(_ type: AIProviderType) {
        providerCache.removeValue(forKey: type)
    }

    /// Invalidate all cached providers
    public func invalidateAllProviders() {
        providerCache.removeAll()
    }

    // MARK: - Connection Testing

    /// Test connection to a provider
    /// - Parameter type: Provider type to test
    /// - Returns: True if connection successful
    @discardableResult
    public func testConnection(for type: AIProviderType) async -> Bool {
        connectionStatus[type] = .checking

        guard let provider = provider(for: type) else {
            connectionStatus[type] = .disconnected(error: "Provider not configured")
            return false
        }

        do {
            let isAvailable = try await provider.testConnection()
            if isAvailable {
                connectionStatus[type] = .connected
                logger.info("Connection test successful for: \(type.rawValue)")
                return true
            } else {
                connectionStatus[type] = .disconnected(error: "Provider unavailable")
                return false
            }
        } catch {
            connectionStatus[type] = .disconnected(error: error.localizedDescription)
            logger.error("Connection test failed for \(type.rawValue): \(error.localizedDescription)")
            return false
        }
    }

    /// Test connection to active provider
    /// - Returns: True if connection successful
    public func testActiveConnection() async -> Bool {
        await testConnection(for: activeProviderType)
    }

    // MARK: - Provider Factory

    private func createProvider(
        type: AIProviderType,
        config: AIProviderConfiguration,
        apiKey: String?
    ) -> any CloudAIProvider {
        switch type {
        case .anthropic:
            return AnthropicProvider(configuration: config, apiKey: apiKey)
        case .openai:
            return OpenAIProvider(configuration: config, apiKey: apiKey)
        case .openRouter:
            return OpenRouterProvider(configuration: config, apiKey: apiKey)
        case .ollama:
            return OllamaProvider(configuration: config)
        case .custom:
            return CustomEndpointProvider(configuration: config, apiKey: apiKey)
        }
    }

    // MARK: - Persistence

    private func loadConfigurations() {
        guard let data = UserDefaults.standard.data(forKey: configurationsKey) else {
            // Initialize with defaults
            for provider in AIProviderType.allCases {
                configurations[provider] = AIProviderConfiguration.defaultConfiguration(for: provider)
            }
            return
        }

        do {
            let decoded = try JSONDecoder().decode([String: AIProviderConfiguration].self, from: data)
            for (key, config) in decoded {
                if let providerType = AIProviderType(rawValue: key) {
                    var normalizedConfig = config
                    if providerType == .openRouter {
                        normalizedConfig.baseURL = normalizedOpenRouterBaseURL(config.baseURL)
                        normalizedConfig.modelId = normalizedOpenRouterModelId(config.modelId)
                    }
                    configurations[providerType] = normalizedConfig
                }
            }

            // Fill in any missing providers with defaults
            for provider in AIProviderType.allCases where configurations[provider] == nil {
                configurations[provider] = AIProviderConfiguration.defaultConfiguration(for: provider)
            }

            logger.debug("Configurations loaded from storage")
        } catch {
            logger.error("Failed to decode configurations: \(error.localizedDescription)")
            // Initialize with defaults on failure
            for provider in AIProviderType.allCases {
                configurations[provider] = AIProviderConfiguration.defaultConfiguration(for: provider)
            }
        }
    }

    private func normalizedOpenRouterBaseURL(_ url: URL) -> URL {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url
        }

        var path = components.path

        if path.isEmpty || path == "/" {
            if let host = components.host, host.contains("openrouter.ai") {
                path = "/api"
            }
        }

        if let host = components.host, host.contains("openrouter.ai") {
            if !path.contains("/api") {
                path = "/api"
            }
        }

        if path.hasSuffix("/") && path != "/" {
            path.removeLast()
        }

        components.path = path
        return components.url ?? url
    }

    private func normalizedOpenRouterModelId(_ modelId: String) -> String {
        let trimmed = modelId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return modelId }
        if trimmed.contains("/") { return trimmed }

        let lower = trimmed.lowercased()
        if lower.contains("claude") {
            return "anthropic/\(trimmed)"
        }
        if lower == "o1" || lower.hasPrefix("gpt-") {
            return "openai/\(trimmed)"
        }

        return trimmed
    }

    private func persistConfigurations() {
        let toEncode = configurations.reduce(into: [String: AIProviderConfiguration]()) { result, pair in
            result[pair.key.rawValue] = pair.value
        }

        do {
            let data = try JSONEncoder().encode(toEncode)
            UserDefaults.standard.set(data, forKey: configurationsKey)
            logger.debug("Configurations persisted to storage")
        } catch {
            logger.error("Failed to encode configurations: \(error.localizedDescription)")
        }
    }

    // MARK: - Utilities

    /// Get all providers that are ready to use (configured and enabled)
    public var availableProviders: [AIProviderType] {
        AIProviderType.allCases.filter { type in
            let config = configuration(for: type)
            guard config.isEnabled else { return false }
            if type.requiresAPIKey && !hasAPIKey(for: type) {
                return false
            }
            return true
        }
    }

    /// Check if a provider is ready to use
    /// - Parameter type: Provider type
    /// - Returns: True if provider is configured and ready
    public func isProviderReady(_ type: AIProviderType) -> Bool {
        let config = configuration(for: type)
        guard config.isEnabled else { return false }
        if type.requiresAPIKey && !hasAPIKey(for: type) {
            return false
        }
        return true
    }
}

// MARK: - Cloud AI Provider Protocol

/// Protocol for cloud AI providers that can test connections
public protocol CloudAIProvider: InferenceProvider {
    /// Test the connection to the provider
    /// - Returns: True if connection is successful
    func testConnection() async throws -> Bool

    /// List available models (if supported)
    func listModels() async throws -> [AIProviderModel]
}

extension CloudAIProvider {
    /// Default implementation returns empty model list
    public func listModels() async throws -> [AIProviderModel] {
        []
    }
}

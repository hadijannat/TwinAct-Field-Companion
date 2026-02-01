//
//  AIProviderModels.swift
//  TwinAct Field Companion
//
//  Data models for multi-provider AI inference system.
//

import Foundation

// MARK: - AI Provider Type

/// Supported AI provider types for cloud inference
public enum AIProviderType: String, Codable, Sendable, CaseIterable, Identifiable {
    case anthropic
    case openai
    case openRouter
    case ollama
    case custom

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .anthropic:
            return "Anthropic (Claude)"
        case .openai:
            return "OpenAI"
        case .openRouter:
            return "OpenRouter"
        case .ollama:
            return "Ollama (Local)"
        case .custom:
            return "Custom Endpoint"
        }
    }

    public var defaultBaseURL: URL? {
        switch self {
        case .anthropic:
            return URL(string: "https://api.anthropic.com")
        case .openai:
            return URL(string: "https://api.openai.com")
        case .openRouter:
            return URL(string: "https://openrouter.ai/api")
        case .ollama:
            return URL(string: "http://localhost:11434")
        case .custom:
            return nil
        }
    }

    public var requiresAPIKey: Bool {
        switch self {
        case .anthropic, .openai, .openRouter:
            return true
        case .ollama, .custom:
            return false
        }
    }

    public var supportsModelListing: Bool {
        switch self {
        case .ollama, .openRouter:
            return true
        default:
            return false
        }
    }

    public var iconName: String {
        switch self {
        case .anthropic:
            return "brain.head.profile"
        case .openai:
            return "sparkles"
        case .openRouter:
            return "arrow.triangle.branch"
        case .ollama:
            return "desktopcomputer"
        case .custom:
            return "server.rack"
        }
    }
}

// MARK: - AI Provider Configuration

/// Configuration for an AI provider
public struct AIProviderConfiguration: Codable, Sendable, Identifiable, Equatable {
    public var id: String { providerType.rawValue }

    /// Provider type
    public var providerType: AIProviderType

    /// Base URL for API requests
    public var baseURL: URL

    /// Model identifier to use
    public var modelId: String

    /// Request timeout in seconds
    public var timeout: TimeInterval

    /// Maximum retry attempts on failure
    public var maxRetries: Int

    /// Whether this configuration is enabled
    public var isEnabled: Bool

    /// Custom headers (for custom endpoints)
    public var customHeaders: [String: String]?

    /// API format for custom endpoints
    public var apiFormat: APIFormat

    public init(
        providerType: AIProviderType,
        baseURL: URL? = nil,
        modelId: String? = nil,
        timeout: TimeInterval = 60.0,
        maxRetries: Int = 2,
        isEnabled: Bool = true,
        customHeaders: [String: String]? = nil,
        apiFormat: APIFormat = .openAICompatible
    ) {
        self.providerType = providerType
        self.baseURL = baseURL ?? providerType.defaultBaseURL ?? URL(string: "http://localhost:8080")!
        self.modelId = modelId ?? Self.defaultModel(for: providerType)
        self.timeout = timeout
        self.maxRetries = maxRetries
        self.isEnabled = isEnabled
        self.customHeaders = customHeaders
        self.apiFormat = apiFormat
    }

    /// Default model for each provider
    public static func defaultModel(for provider: AIProviderType) -> String {
        switch provider {
        case .anthropic:
            return "claude-sonnet-4-20250514"
        case .openai:
            return "gpt-4o"
        case .openRouter:
            return "anthropic/claude-sonnet-4"
        case .ollama:
            return "llama3.2"
        case .custom:
            return "default"
        }
    }

    /// Create default configuration for a provider
    public static func defaultConfiguration(for provider: AIProviderType) -> AIProviderConfiguration {
        AIProviderConfiguration(providerType: provider)
    }

    public static func == (lhs: AIProviderConfiguration, rhs: AIProviderConfiguration) -> Bool {
        lhs.providerType == rhs.providerType &&
        lhs.baseURL == rhs.baseURL &&
        lhs.modelId == rhs.modelId &&
        lhs.timeout == rhs.timeout &&
        lhs.maxRetries == rhs.maxRetries &&
        lhs.isEnabled == rhs.isEnabled &&
        lhs.apiFormat == rhs.apiFormat
    }
}

// MARK: - API Format

/// API format for communication with provider
public enum APIFormat: String, Codable, Sendable, CaseIterable {
    /// OpenAI-compatible chat completions format
    case openAICompatible

    /// Anthropic Messages API format
    case anthropic

    /// Simple request/response format
    case simple

    public var displayName: String {
        switch self {
        case .openAICompatible:
            return "OpenAI Compatible"
        case .anthropic:
            return "Anthropic Messages"
        case .simple:
            return "Simple (prompt/response)"
        }
    }
}

// MARK: - AI Provider Model

/// Information about an available model from a provider
public struct AIProviderModel: Codable, Sendable, Identifiable, Hashable {
    public var id: String { modelId }

    /// Model identifier
    public let modelId: String

    /// Human-readable name
    public let displayName: String

    /// Context window size (tokens)
    public let contextWindow: Int

    /// Maximum output tokens
    public let maxOutputTokens: Int?

    /// Whether the model supports vision/images
    public let supportsVision: Bool

    /// Provider this model belongs to
    public let provider: AIProviderType

    public init(
        modelId: String,
        displayName: String,
        contextWindow: Int,
        maxOutputTokens: Int? = nil,
        supportsVision: Bool = false,
        provider: AIProviderType
    ) {
        self.modelId = modelId
        self.displayName = displayName
        self.contextWindow = contextWindow
        self.maxOutputTokens = maxOutputTokens
        self.supportsVision = supportsVision
        self.provider = provider
    }
}

// MARK: - Predefined Models

public extension AIProviderModel {

    // MARK: Anthropic Models

    static let claudeOpus = AIProviderModel(
        modelId: "claude-opus-4-20250514",
        displayName: "Claude Opus 4",
        contextWindow: 200_000,
        maxOutputTokens: 32_000,
        supportsVision: true,
        provider: .anthropic
    )

    static let claudeSonnet = AIProviderModel(
        modelId: "claude-sonnet-4-20250514",
        displayName: "Claude Sonnet 4",
        contextWindow: 200_000,
        maxOutputTokens: 64_000,
        supportsVision: true,
        provider: .anthropic
    )

    static let claudeHaiku = AIProviderModel(
        modelId: "claude-3-5-haiku-20241022",
        displayName: "Claude 3.5 Haiku",
        contextWindow: 200_000,
        maxOutputTokens: 8_192,
        supportsVision: true,
        provider: .anthropic
    )

    // MARK: OpenAI Models

    static let gpt4o = AIProviderModel(
        modelId: "gpt-4o",
        displayName: "GPT-4o",
        contextWindow: 128_000,
        maxOutputTokens: 16_384,
        supportsVision: true,
        provider: .openai
    )

    static let gpt4oMini = AIProviderModel(
        modelId: "gpt-4o-mini",
        displayName: "GPT-4o Mini",
        contextWindow: 128_000,
        maxOutputTokens: 16_384,
        supportsVision: true,
        provider: .openai
    )

    static let o1 = AIProviderModel(
        modelId: "o1",
        displayName: "O1",
        contextWindow: 200_000,
        maxOutputTokens: 100_000,
        supportsVision: true,
        provider: .openai
    )

    // MARK: Provider Model Lists

    static var anthropicModels: [AIProviderModel] {
        [.claudeOpus, .claudeSonnet, .claudeHaiku]
    }

    static var openAIModels: [AIProviderModel] {
        [.gpt4o, .gpt4oMini, .o1]
    }

    static func models(for provider: AIProviderType) -> [AIProviderModel] {
        switch provider {
        case .anthropic:
            return anthropicModels
        case .openai:
            return openAIModels
        case .openRouter:
            // Fallback set (if live listing fails). Use OpenRouter-prefixed IDs.
            let anthropicFallback = anthropicModels.map { model in
                AIProviderModel(
                    modelId: "anthropic/\(model.modelId)",
                    displayName: model.displayName,
                    contextWindow: model.contextWindow,
                    maxOutputTokens: model.maxOutputTokens,
                    supportsVision: model.supportsVision,
                    provider: .openRouter
                )
            }
            let openAIFallback = openAIModels.map { model in
                AIProviderModel(
                    modelId: "openai/\(model.modelId)",
                    displayName: model.displayName,
                    contextWindow: model.contextWindow,
                    maxOutputTokens: model.maxOutputTokens,
                    supportsVision: model.supportsVision,
                    provider: .openRouter
                )
            }
            return anthropicFallback + openAIFallback
        case .ollama:
            // Ollama models are dynamic; return empty (fetched at runtime)
            return []
        case .custom:
            return []
        }
    }
}

// MARK: - Connection Status

/// Connection status for a provider
public enum AIProviderConnectionStatus: Sendable, Equatable {
    case unknown
    case checking
    case connected
    case disconnected(error: String)

    public var isConnected: Bool {
        if case .connected = self {
            return true
        }
        return false
    }

    public var displayText: String {
        switch self {
        case .unknown:
            return "Not tested"
        case .checking:
            return "Testing..."
        case .connected:
            return "Connected"
        case .disconnected(let error):
            return "Error: \(error)"
        }
    }

    public var iconName: String {
        switch self {
        case .unknown:
            return "questionmark.circle"
        case .checking:
            return "arrow.clockwise"
        case .connected:
            return "checkmark.circle.fill"
        case .disconnected:
            return "xmark.circle.fill"
        }
    }

    public var color: String {
        switch self {
        case .unknown:
            return "secondary"
        case .checking:
            return "blue"
        case .connected:
            return "green"
        case .disconnected:
            return "red"
        }
    }
}

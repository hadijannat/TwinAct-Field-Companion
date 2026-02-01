//
//  InferenceProvider.swift
//  TwinAct Field Companion
//
//  Protocol and common types for LLM inference providers.
//

import Foundation

// MARK: - Inference Errors

/// Errors that can occur during inference
public enum InferenceError: Error, LocalizedError, Sendable {
    case modelNotLoaded
    case endpointNotConfigured
    case noProviderAvailable
    case generationFailed(reason: String)
    case timeout
    case cancelled
    case rateLimited(retryAfter: TimeInterval?)
    case invalidResponse
    case contextTooLong(maxTokens: Int)
    case safetyViolation(reason: String)
    case networkError(underlying: Error)

    public var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return "On-device model is not loaded"
        case .endpointNotConfigured:
            return "Cloud API endpoint is not configured"
        case .noProviderAvailable:
            return "No inference provider is available"
        case .generationFailed(let reason):
            return "Generation failed: \(reason)"
        case .timeout:
            return "Inference request timed out"
        case .cancelled:
            return "Inference was cancelled"
        case .rateLimited(let retryAfter):
            if let seconds = retryAfter {
                return "Rate limited. Retry after \(Int(seconds)) seconds"
            }
            return "Rate limited. Please try again later"
        case .invalidResponse:
            return "Invalid response from inference provider"
        case .contextTooLong(let maxTokens):
            return "Context too long. Maximum \(maxTokens) tokens allowed"
        case .safetyViolation(let reason):
            return "Safety policy violation: \(reason)"
        case .networkError(let underlying):
            return "Network error: \(underlying.localizedDescription)"
        }
    }

    /// Whether this error is transient and may succeed on retry
    public var isRetryable: Bool {
        switch self {
        case .timeout, .rateLimited, .networkError:
            return true
        default:
            return false
        }
    }
}

// MARK: - Generation Options

/// Options for text generation
public struct GenerationOptions: Sendable {
    /// Maximum tokens to generate
    public var maxTokens: Int

    /// Temperature for sampling (0.0 = deterministic, 1.0 = creative)
    public var temperature: Double

    /// Top-p (nucleus) sampling parameter
    public var topP: Double?

    /// Stop sequences to end generation
    public var stopSequences: [String]?

    /// System prompt override (if supported)
    public var systemPrompt: String?

    public init(
        maxTokens: Int = 512,
        temperature: Double = 0.7,
        topP: Double? = nil,
        stopSequences: [String]? = nil,
        systemPrompt: String? = nil
    ) {
        self.maxTokens = maxTokens
        self.temperature = temperature
        self.topP = topP
        self.stopSequences = stopSequences
        self.systemPrompt = systemPrompt
    }

    /// Default options using app configuration
    public static var `default`: GenerationOptions {
        GenerationOptions(
            maxTokens: AppConfiguration.GenAI.maxResponseTokens,
            temperature: AppConfiguration.GenAI.inferenceTemperature
        )
    }

    /// Options for factual/technical responses
    public static var factual: GenerationOptions {
        GenerationOptions(
            maxTokens: 1024,
            temperature: 0.3
        )
    }

    /// Options for creative/explanatory responses
    public static var explanatory: GenerationOptions {
        GenerationOptions(
            maxTokens: 2048,
            temperature: 0.7
        )
    }
}

// MARK: - Generation Result

/// Result from inference generation
public struct GenerationResult: Sendable {
    /// Generated text
    public let text: String

    /// Number of tokens in the prompt
    public let promptTokens: Int?

    /// Number of tokens generated
    public let completionTokens: Int?

    /// Which provider was used
    public let provider: InferenceProviderType

    /// Time taken for generation (in seconds)
    public let duration: TimeInterval?

    /// Whether the response was truncated
    public let wasTruncated: Bool

    /// Finish reason (if provided by the model)
    public let finishReason: String?

    public init(
        text: String,
        promptTokens: Int? = nil,
        completionTokens: Int? = nil,
        provider: InferenceProviderType,
        duration: TimeInterval? = nil,
        wasTruncated: Bool = false,
        finishReason: String? = nil
    ) {
        self.text = text
        self.promptTokens = promptTokens
        self.completionTokens = completionTokens
        self.provider = provider
        self.duration = duration
        self.wasTruncated = wasTruncated
        self.finishReason = finishReason
    }

    /// Total tokens used
    public var totalTokens: Int? {
        guard let prompt = promptTokens, let completion = completionTokens else {
            return nil
        }
        return prompt + completion
    }
}

// MARK: - Provider Type

/// Type of inference provider
public enum InferenceProviderType: String, Sendable, CaseIterable {
    case onDevice = "on_device"
    case cloud = "cloud"

    // Cloud provider subtypes (for tracking which specific provider was used)
    case anthropic
    case openai
    case openRouter
    case ollama
    case custom

    public var displayName: String {
        switch self {
        case .onDevice:
            return "On-Device"
        case .cloud:
            return "Cloud"
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

    /// Whether this is a cloud-based provider (as opposed to on-device)
    public var isCloudProvider: Bool {
        self != .onDevice
    }
}

// MARK: - Inference Provider Protocol

/// Protocol for LLM inference providers
public protocol InferenceProvider: Sendable {
    /// Provider type identifier
    var providerType: InferenceProviderType { get }

    /// Whether this provider is currently available
    var isAvailable: Bool { get async }

    /// Generate text from a prompt
    /// - Parameters:
    ///   - prompt: The input prompt
    ///   - options: Generation options
    /// - Returns: Generation result
    func generate(
        prompt: String,
        options: GenerationOptions
    ) async throws -> GenerationResult

    /// Cancel any ongoing generation
    func cancel() async
}

// MARK: - Default Implementation

extension InferenceProvider {
    /// Generate text with default options
    public func generate(prompt: String) async throws -> GenerationResult {
        try await generate(prompt: prompt, options: .default)
    }

    /// Simple generate returning just the text
    public func generateText(
        prompt: String,
        options: GenerationOptions = .default
    ) async throws -> String {
        let result = try await generate(prompt: prompt, options: options)
        return result.text
    }
}

// MARK: - Provider Status

/// Status information for an inference provider
public struct InferenceProviderStatus: Sendable {
    public let providerType: InferenceProviderType
    public let isAvailable: Bool
    public let modelName: String?
    public let modelVersion: String?
    public let lastError: String?

    public init(
        providerType: InferenceProviderType,
        isAvailable: Bool,
        modelName: String? = nil,
        modelVersion: String? = nil,
        lastError: String? = nil
    ) {
        self.providerType = providerType
        self.isAvailable = isAvailable
        self.modelName = modelName
        self.modelVersion = modelVersion
        self.lastError = lastError
    }
}

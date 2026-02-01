//
//  AnthropicProvider.swift
//  TwinAct Field Companion
//
//  Anthropic (Claude) API provider implementation.
//

import Foundation
import os.log

// MARK: - Anthropic Provider

/// Provider for Anthropic's Claude API
public actor AnthropicProvider: CloudAIProvider {

    // MARK: - Properties

    public nonisolated let providerType: InferenceProviderType = .cloud

    private let configuration: AIProviderConfiguration
    private let apiKey: String?
    private let httpClient: HTTPClient
    private let safetyPolicy: SafetyPolicy
    private var currentTask: Task<GenerationResult, Error>?
    private let logger: Logger

    private let anthropicVersion = "2023-06-01"

    // MARK: - Initialization

    /// Initialize Anthropic provider
    /// - Parameters:
    ///   - configuration: Provider configuration
    ///   - apiKey: API key for authentication
    public init(
        configuration: AIProviderConfiguration,
        apiKey: String?
    ) {
        self.configuration = configuration
        self.apiKey = apiKey
        self.safetyPolicy = SafetyPolicy()
        self.logger = Logger(
            subsystem: AppConfiguration.AppInfo.bundleIdentifier,
            category: "AnthropicProvider"
        )

        let httpConfig = HTTPClientConfiguration(
            baseURL: configuration.baseURL,
            defaultTimeout: configuration.timeout,
            maxRetryAttempts: configuration.maxRetries
        )
        self.httpClient = HTTPClient(configuration: httpConfig)
    }

    // MARK: - InferenceProvider

    public var isAvailable: Bool {
        get async {
            apiKey != nil && !apiKey!.isEmpty
        }
    }

    public func generate(
        prompt: String,
        options: GenerationOptions
    ) async throws -> GenerationResult {
        guard let apiKey = apiKey, !apiKey.isEmpty else {
            throw InferenceError.endpointNotConfigured
        }

        let startTime = Date()

        // Apply safety policy to filter PII
        let filteredPrompt = SafetyPolicy.filterPII(prompt)

        let task = Task<GenerationResult, Error> {
            try await performGeneration(
                prompt: filteredPrompt,
                options: options,
                apiKey: apiKey
            )
        }

        currentTask = task
        defer { currentTask = nil }

        do {
            let result = try await task.value
            let duration = Date().timeIntervalSince(startTime)

            // Validate response safety
            if !SafetyPolicy.validateResponse(result.text) {
                throw InferenceError.safetyViolation(reason: "Response failed safety validation")
            }

            return GenerationResult(
                text: result.text,
                promptTokens: result.promptTokens,
                completionTokens: result.completionTokens,
                provider: .cloud,
                duration: duration,
                wasTruncated: result.wasTruncated,
                finishReason: result.finishReason
            )
        } catch is CancellationError {
            throw InferenceError.cancelled
        } catch let error as InferenceError {
            throw error
        } catch {
            throw InferenceError.networkError(underlying: error)
        }
    }

    public func cancel() async {
        currentTask?.cancel()
    }

    // MARK: - CloudAIProvider

    public func testConnection() async throws -> Bool {
        guard let apiKey = apiKey, !apiKey.isEmpty else {
            return false
        }

        // Make a minimal request to verify API key
        let headers = buildHeaders(apiKey: apiKey)

        let endpoint = Endpoint(
            path: "/v1/messages",
            method: .post,
            headers: headers,
            body: try JSONEncoder().encode(AnthropicTestRequest()),
            timeout: 10.0
        )

        do {
            let _: AnthropicResponse = try await httpClient.request(endpoint)
            return true
        } catch let error as HTTPError {
            switch error {
            case .unauthorized, .forbidden:
                return false
            default:
                // Other errors might be transient
                throw error
            }
        }
    }

    public func listModels() async throws -> [AIProviderModel] {
        // Anthropic doesn't have a models endpoint; return predefined models
        return AIProviderModel.anthropicModels
    }

    // MARK: - Private Methods

    private func performGeneration(
        prompt: String,
        options: GenerationOptions,
        apiKey: String
    ) async throws -> GenerationResult {
        let headers = buildHeaders(apiKey: apiKey)

        // Build messages array
        var messages: [AnthropicMessage] = []

        // Add user message
        messages.append(AnthropicMessage(role: "user", content: prompt))

        let requestBody = AnthropicRequest(
            model: configuration.modelId,
            maxTokens: options.maxTokens,
            messages: messages,
            system: options.systemPrompt,
            temperature: options.temperature,
            stopSequences: options.stopSequences
        )

        let endpoint = try Endpoint.post(
            "/v1/messages",
            body: requestBody,
            headers: headers,
            timeout: configuration.timeout
        )

        logger.info("Sending request to Anthropic API")
        let response: AnthropicResponse = try await httpClient.request(endpoint)

        try Task.checkCancellation()

        // Extract text from response
        let text = response.content.compactMap { block -> String? in
            if case .text(let textContent) = block {
                return textContent.text
            }
            return nil
        }.joined()

        return GenerationResult(
            text: text,
            promptTokens: response.usage.inputTokens,
            completionTokens: response.usage.outputTokens,
            provider: .cloud,
            wasTruncated: response.stopReason == "max_tokens",
            finishReason: response.stopReason
        )
    }

    private func buildHeaders(apiKey: String) -> [String: String] {
        [
            "Content-Type": "application/json",
            "x-api-key": apiKey,
            "anthropic-version": anthropicVersion
        ]
    }
}

// MARK: - Anthropic API Models

private struct AnthropicRequest: Codable, Sendable {
    let model: String
    let maxTokens: Int
    let messages: [AnthropicMessage]
    let system: String?
    let temperature: Double?
    let stopSequences: [String]?

    enum CodingKeys: String, CodingKey {
        case model
        case maxTokens = "max_tokens"
        case messages
        case system
        case temperature
        case stopSequences = "stop_sequences"
    }
}

private struct AnthropicTestRequest: Codable, Sendable {
    let model = "claude-3-5-haiku-20241022"
    let maxTokens = 1
    let messages = [AnthropicMessage(role: "user", content: "Hi")]

    enum CodingKeys: String, CodingKey {
        case model
        case maxTokens = "max_tokens"
        case messages
    }
}

private struct AnthropicMessage: Codable, Sendable {
    let role: String
    let content: String
}

private struct AnthropicResponse: Codable, Sendable {
    let id: String
    let type: String
    let role: String
    let content: [ContentBlock]
    let model: String
    let stopReason: String?
    let usage: Usage

    enum CodingKeys: String, CodingKey {
        case id, type, role, content, model
        case stopReason = "stop_reason"
        case usage
    }

    enum ContentBlock: Codable, Sendable {
        case text(TextContent)
        case unknown

        struct TextContent: Codable, Sendable {
            let type: String
            let text: String
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let textContent = try? container.decode(TextContent.self),
               textContent.type == "text" {
                self = .text(textContent)
            } else {
                self = .unknown
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .text(let content):
                try container.encode(content)
            case .unknown:
                try container.encodeNil()
            }
        }
    }

    struct Usage: Codable, Sendable {
        let inputTokens: Int
        let outputTokens: Int

        enum CodingKeys: String, CodingKey {
            case inputTokens = "input_tokens"
            case outputTokens = "output_tokens"
        }
    }
}

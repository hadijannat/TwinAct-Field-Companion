//
//  CustomEndpointProvider.swift
//  TwinAct Field Companion
//
//  Custom endpoint provider for user-defined APIs.
//

import Foundation
import os.log

// MARK: - Custom Endpoint Provider

/// Provider for custom/self-hosted API endpoints
/// Supports OpenAI-compatible and simple request/response formats.
public actor CustomEndpointProvider: CloudAIProvider {

    // MARK: - Properties

    public nonisolated let providerType: InferenceProviderType = .cloud

    private let configuration: AIProviderConfiguration
    private let apiKey: String?
    private let httpClient: HTTPClient
    private let safetyPolicy: SafetyPolicy
    private var currentTask: Task<GenerationResult, Error>?
    private let logger: Logger

    // MARK: - Initialization

    /// Initialize custom endpoint provider
    /// - Parameters:
    ///   - configuration: Provider configuration
    ///   - apiKey: Optional API key for authentication
    public init(
        configuration: AIProviderConfiguration,
        apiKey: String?
    ) {
        self.configuration = configuration
        self.apiKey = apiKey
        self.safetyPolicy = SafetyPolicy()
        self.logger = Logger(
            subsystem: AppConfiguration.AppInfo.bundleIdentifier,
            category: "CustomEndpointProvider"
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
            // Custom endpoints are available if configured
            return true
        }
    }

    public func generate(
        prompt: String,
        options: GenerationOptions
    ) async throws -> GenerationResult {
        let startTime = Date()

        // Apply safety policy
        let filteredPrompt = SafetyPolicy.filterPII(prompt)

        let task = Task<GenerationResult, Error> {
            switch configuration.apiFormat {
            case .openAICompatible:
                return try await performOpenAIGeneration(
                    prompt: filteredPrompt,
                    options: options
                )
            case .anthropic:
                return try await performAnthropicGeneration(
                    prompt: filteredPrompt,
                    options: options
                )
            case .simple:
                return try await performSimpleGeneration(
                    prompt: filteredPrompt,
                    options: options
                )
            }
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
        // Try a minimal request based on format
        switch configuration.apiFormat {
        case .openAICompatible:
            return try await testOpenAIConnection()
        case .anthropic:
            return try await testAnthropicConnection()
        case .simple:
            return try await testSimpleConnection()
        }
    }

    public func listModels() async throws -> [AIProviderModel] {
        // Custom endpoints don't typically list models
        return []
    }

    // MARK: - OpenAI-Compatible Format

    private func performOpenAIGeneration(
        prompt: String,
        options: GenerationOptions
    ) async throws -> GenerationResult {
        var messages: [[String: String]] = []

        if let systemPrompt = options.systemPrompt {
            messages.append(["role": "system", "content": systemPrompt])
        }
        messages.append(["role": "user", "content": prompt])

        let requestBody: [String: Any] = [
            "model": configuration.modelId,
            "messages": messages,
            "max_tokens": options.maxTokens,
            "temperature": options.temperature
        ]

        let bodyData = try JSONSerialization.data(withJSONObject: requestBody)

        let endpoint = Endpoint(
            path: "/v1/chat/completions",
            method: .post,
            headers: buildHeaders(),
            body: bodyData,
            timeout: configuration.timeout
        )

        let response: OpenAICompatibleResponse = try await httpClient.request(endpoint)

        guard let choice = response.choices.first else {
            throw InferenceError.invalidResponse
        }

        return GenerationResult(
            text: choice.message.content ?? "",
            promptTokens: response.usage?.promptTokens,
            completionTokens: response.usage?.completionTokens,
            provider: .cloud,
            wasTruncated: choice.finishReason == "length",
            finishReason: choice.finishReason
        )
    }

    private func testOpenAIConnection() async throws -> Bool {
        let headers = buildHeaders()

        // Try models endpoint first
        let endpoint = Endpoint(
            path: "/v1/models",
            method: .get,
            headers: headers,
            timeout: 10.0
        )

        do {
            let _: OpenAIModelsListResponse = try await httpClient.request(endpoint)
            return true
        } catch {
            // Fall back to a minimal chat request
            return try await testWithMinimalRequest()
        }
    }

    // MARK: - Anthropic Format

    private func performAnthropicGeneration(
        prompt: String,
        options: GenerationOptions
    ) async throws -> GenerationResult {
        let messages = [["role": "user", "content": prompt]]

        var requestBody: [String: Any] = [
            "model": configuration.modelId,
            "max_tokens": options.maxTokens,
            "messages": messages
        ]

        if let systemPrompt = options.systemPrompt {
            requestBody["system"] = systemPrompt
        }

        let bodyData = try JSONSerialization.data(withJSONObject: requestBody)

        var headers = buildHeaders()
        headers["anthropic-version"] = "2023-06-01"

        let endpoint = Endpoint(
            path: "/v1/messages",
            method: .post,
            headers: headers,
            body: bodyData,
            timeout: configuration.timeout
        )

        let response: AnthropicCompatibleResponse = try await httpClient.request(endpoint)

        let text = response.content.compactMap { block -> String? in
            if block.type == "text" {
                return block.text
            }
            return nil
        }.joined()

        return GenerationResult(
            text: text,
            promptTokens: response.usage?.inputTokens,
            completionTokens: response.usage?.outputTokens,
            provider: .cloud,
            wasTruncated: response.stopReason == "max_tokens",
            finishReason: response.stopReason
        )
    }

    private func testAnthropicConnection() async throws -> Bool {
        try await testWithMinimalRequest()
    }

    // MARK: - Simple Format

    private func performSimpleGeneration(
        prompt: String,
        options: GenerationOptions
    ) async throws -> GenerationResult {
        let requestBody: [String: Any] = [
            "prompt": prompt,
            "max_tokens": options.maxTokens,
            "temperature": options.temperature
        ]

        let bodyData = try JSONSerialization.data(withJSONObject: requestBody)

        let endpoint = Endpoint(
            path: "/generate",
            method: .post,
            headers: buildHeaders(),
            body: bodyData,
            timeout: configuration.timeout
        )

        let response: SimpleResponse = try await httpClient.request(endpoint)

        return GenerationResult(
            text: response.text ?? response.response ?? "",
            promptTokens: response.promptTokens,
            completionTokens: response.completionTokens,
            provider: .cloud,
            wasTruncated: false,
            finishReason: nil
        )
    }

    private func testSimpleConnection() async throws -> Bool {
        let endpoint = Endpoint(
            path: "/health",
            method: .get,
            headers: buildHeaders(),
            timeout: 5.0
        )

        do {
            let _: Data = try await httpClient.request(endpoint)
            return true
        } catch {
            return try await testWithMinimalRequest()
        }
    }

    // MARK: - Helpers

    private func buildHeaders() -> [String: String] {
        var headers: [String: String] = ["Content-Type": "application/json"]

        if let apiKey = apiKey, !apiKey.isEmpty {
            headers["Authorization"] = "Bearer \(apiKey)"
        }

        // Add custom headers from configuration
        if let customHeaders = configuration.customHeaders {
            for (key, value) in customHeaders {
                headers[key] = value
            }
        }

        return headers
    }

    private func testWithMinimalRequest() async throws -> Bool {
        // This is a best-effort test; we try to make a minimal request
        // and check if we get any valid response
        do {
            let result = try await generate(
                prompt: "Hi",
                options: GenerationOptions(maxTokens: 1, temperature: 0.0)
            )
            return !result.text.isEmpty
        } catch {
            return false
        }
    }
}

// MARK: - Response Models

private struct OpenAICompatibleResponse: Codable, Sendable {
    let id: String?
    let choices: [Choice]
    let usage: Usage?

    struct Choice: Codable, Sendable {
        let index: Int?
        let message: Message
        let finishReason: String?

        enum CodingKeys: String, CodingKey {
            case index, message
            case finishReason = "finish_reason"
        }

        struct Message: Codable, Sendable {
            let role: String?
            let content: String?
        }
    }

    struct Usage: Codable, Sendable {
        let promptTokens: Int?
        let completionTokens: Int?

        enum CodingKeys: String, CodingKey {
            case promptTokens = "prompt_tokens"
            case completionTokens = "completion_tokens"
        }
    }
}

private struct OpenAIModelsListResponse: Codable, Sendable {
    let data: [ModelInfo]?
    let object: String?

    struct ModelInfo: Codable, Sendable {
        let id: String
    }
}

private struct AnthropicCompatibleResponse: Codable, Sendable {
    let id: String?
    let content: [ContentBlock]
    let stopReason: String?
    let usage: Usage?

    enum CodingKeys: String, CodingKey {
        case id, content
        case stopReason = "stop_reason"
        case usage
    }

    struct ContentBlock: Codable, Sendable {
        let type: String
        let text: String?
    }

    struct Usage: Codable, Sendable {
        let inputTokens: Int?
        let outputTokens: Int?

        enum CodingKeys: String, CodingKey {
            case inputTokens = "input_tokens"
            case outputTokens = "output_tokens"
        }
    }
}

private struct SimpleResponse: Codable, Sendable {
    let text: String?
    let response: String?
    let promptTokens: Int?
    let completionTokens: Int?

    enum CodingKeys: String, CodingKey {
        case text, response
        case promptTokens = "prompt_tokens"
        case completionTokens = "completion_tokens"
    }
}

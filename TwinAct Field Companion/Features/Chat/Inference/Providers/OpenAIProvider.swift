//
//  OpenAIProvider.swift
//  TwinAct Field Companion
//
//  OpenAI API provider implementation.
//

import Foundation
import os.log

// MARK: - OpenAI Provider

/// Provider for OpenAI's Chat Completions API
public actor OpenAIProvider: CloudAIProvider {

    // MARK: - Properties

    public nonisolated let providerType: InferenceProviderType = .cloud

    private let configuration: AIProviderConfiguration
    private let apiKey: String?
    private let httpClient: HTTPClient
    private let safetyPolicy: SafetyPolicy
    private var currentTask: Task<GenerationResult, Error>?
    private let logger: Logger

    // MARK: - Initialization

    /// Initialize OpenAI provider
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
            category: "OpenAIProvider"
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

        let headers = buildHeaders(apiKey: apiKey)

        // Test with models endpoint (lighter than chat)
        let endpoint = Endpoint(
            path: "/v1/models",
            method: .get,
            headers: headers,
            timeout: 10.0
        )

        do {
            let _: OpenAIModelsResponse = try await httpClient.request(endpoint)
            return true
        } catch let error as HTTPError {
            switch error {
            case .unauthorized, .forbidden:
                return false
            default:
                throw error
            }
        }
    }

    public func listModels() async throws -> [AIProviderModel] {
        // Return predefined models (OpenAI models endpoint returns all models including fine-tunes)
        return AIProviderModel.openAIModels
    }

    // MARK: - Private Methods

    private func performGeneration(
        prompt: String,
        options: GenerationOptions,
        apiKey: String
    ) async throws -> GenerationResult {
        let headers = buildHeaders(apiKey: apiKey)

        // Build messages array
        var messages: [OpenAIMessage] = []

        // Add system message if provided
        if let systemPrompt = options.systemPrompt {
            messages.append(OpenAIMessage(role: "system", content: systemPrompt))
        }

        // Add user message
        messages.append(OpenAIMessage(role: "user", content: prompt))

        let requestBody = OpenAIRequest(
            model: configuration.modelId,
            messages: messages,
            maxTokens: options.maxTokens,
            temperature: options.temperature,
            topP: options.topP,
            stop: options.stopSequences
        )

        let endpoint = try Endpoint.post(
            "/v1/chat/completions",
            body: requestBody,
            headers: headers,
            timeout: configuration.timeout
        )

        logger.info("Sending request to OpenAI API")
        let response: OpenAIResponse = try await httpClient.request(endpoint)

        try Task.checkCancellation()

        // Extract text from first choice
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

    private func buildHeaders(apiKey: String) -> [String: String] {
        [
            "Content-Type": "application/json",
            "Authorization": "Bearer \(apiKey)"
        ]
    }
}

// MARK: - OpenAI API Models

private struct OpenAIRequest: Codable, Sendable {
    let model: String
    let messages: [OpenAIMessage]
    let maxTokens: Int?
    let temperature: Double?
    let topP: Double?
    let stop: [String]?

    enum CodingKeys: String, CodingKey {
        case model, messages
        case maxTokens = "max_tokens"
        case temperature
        case topP = "top_p"
        case stop
    }
}

private struct OpenAIMessage: Codable, Sendable {
    let role: String
    let content: String
}

private struct OpenAIResponse: Codable, Sendable {
    let id: String
    let object: String
    let created: Int
    let model: String
    let choices: [Choice]
    let usage: Usage?

    struct Choice: Codable, Sendable {
        let index: Int
        let message: Message
        let finishReason: String?

        enum CodingKeys: String, CodingKey {
            case index, message
            case finishReason = "finish_reason"
        }

        struct Message: Codable, Sendable {
            let role: String
            let content: String?
        }
    }

    struct Usage: Codable, Sendable {
        let promptTokens: Int?
        let completionTokens: Int?
        let totalTokens: Int?

        enum CodingKeys: String, CodingKey {
            case promptTokens = "prompt_tokens"
            case completionTokens = "completion_tokens"
            case totalTokens = "total_tokens"
        }
    }
}

private struct OpenAIModelsResponse: Codable, Sendable {
    let object: String
    let data: [ModelInfo]

    struct ModelInfo: Codable, Sendable {
        let id: String
        let object: String
        let created: Int?
        let ownedBy: String?

        enum CodingKeys: String, CodingKey {
            case id, object, created
            case ownedBy = "owned_by"
        }
    }
}

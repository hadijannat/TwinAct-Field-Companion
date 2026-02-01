//
//  OllamaProvider.swift
//  TwinAct Field Companion
//
//  Ollama (local) API provider implementation.
//

import Foundation
import os.log

// MARK: - Ollama Provider

/// Provider for Ollama's local API
/// Ollama runs locally and doesn't require API keys.
public actor OllamaProvider: CloudAIProvider {

    // MARK: - Properties

    public nonisolated let providerType: InferenceProviderType = .cloud

    private let configuration: AIProviderConfiguration
    private let httpClient: HTTPClient
    private let safetyPolicy: SafetyPolicy
    private var currentTask: Task<GenerationResult, Error>?
    private let logger: Logger

    // MARK: - Initialization

    /// Initialize Ollama provider
    /// - Parameter configuration: Provider configuration
    public init(configuration: AIProviderConfiguration) {
        self.configuration = configuration
        self.safetyPolicy = SafetyPolicy()
        self.logger = Logger(
            subsystem: AppConfiguration.AppInfo.bundleIdentifier,
            category: "OllamaProvider"
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
            // Ollama is available if we can reach the server
            do {
                return try await testConnection()
            } catch {
                return false
            }
        }
    }

    public func generate(
        prompt: String,
        options: GenerationOptions
    ) async throws -> GenerationResult {
        let startTime = Date()

        // Apply safety policy (even for local models)
        let filteredPrompt = SafetyPolicy.filterPII(prompt)

        let task = Task<GenerationResult, Error> {
            try await performGeneration(
                prompt: filteredPrompt,
                options: options
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
        // Ollama has a simple tags endpoint to list models
        let endpoint = Endpoint(
            path: "/api/tags",
            method: .get,
            headers: ["Content-Type": "application/json"],
            timeout: 5.0
        )

        do {
            let _: OllamaModelsResponse = try await httpClient.request(endpoint)
            return true
        } catch {
            // Connection failed
            return false
        }
    }

    public func listModels() async throws -> [AIProviderModel] {
        let endpoint = Endpoint(
            path: "/api/tags",
            method: .get,
            headers: ["Content-Type": "application/json"],
            timeout: 10.0
        )

        let response: OllamaModelsResponse = try await httpClient.request(endpoint)

        return response.models.map { model in
            AIProviderModel(
                modelId: model.name,
                displayName: model.name,
                contextWindow: 4096, // Default; Ollama doesn't report this
                maxOutputTokens: nil,
                supportsVision: model.name.contains("llava") || model.name.contains("vision"),
                provider: .ollama
            )
        }
    }

    /// Check if Ollama server is running
    public func checkConnection() async -> Bool {
        do {
            return try await testConnection()
        } catch {
            return false
        }
    }

    // MARK: - Private Methods

    private func performGeneration(
        prompt: String,
        options: GenerationOptions
    ) async throws -> GenerationResult {
        // Build messages for chat endpoint
        var messages: [OllamaMessage] = []

        // Add system message if provided
        if let systemPrompt = options.systemPrompt {
            messages.append(OllamaMessage(role: "system", content: systemPrompt))
        }

        // Add user message
        messages.append(OllamaMessage(role: "user", content: prompt))

        let requestBody = OllamaChatRequest(
            model: configuration.modelId,
            messages: messages,
            stream: false,
            options: OllamaOptions(
                numPredict: options.maxTokens,
                temperature: options.temperature,
                topP: options.topP,
                stop: options.stopSequences
            )
        )

        let endpoint = try Endpoint.post(
            "/api/chat",
            body: requestBody,
            headers: ["Content-Type": "application/json"],
            timeout: configuration.timeout
        )

        logger.info("Sending request to Ollama")
        let response: OllamaChatResponse = try await httpClient.request(endpoint)

        try Task.checkCancellation()

        return GenerationResult(
            text: response.message.content,
            promptTokens: response.promptEvalCount,
            completionTokens: response.evalCount,
            provider: .cloud,
            wasTruncated: response.doneReason == "length",
            finishReason: response.doneReason
        )
    }
}

// MARK: - Ollama API Models

private struct OllamaChatRequest: Codable, Sendable {
    let model: String
    let messages: [OllamaMessage]
    let stream: Bool
    let options: OllamaOptions?
}

private struct OllamaMessage: Codable, Sendable {
    let role: String
    let content: String
}

private struct OllamaOptions: Codable, Sendable {
    let numPredict: Int?
    let temperature: Double?
    let topP: Double?
    let stop: [String]?

    enum CodingKeys: String, CodingKey {
        case numPredict = "num_predict"
        case temperature
        case topP = "top_p"
        case stop
    }
}

private struct OllamaChatResponse: Codable, Sendable {
    let model: String
    let createdAt: String
    let message: Message
    let done: Bool
    let doneReason: String?
    let totalDuration: Int?
    let loadDuration: Int?
    let promptEvalCount: Int?
    let promptEvalDuration: Int?
    let evalCount: Int?
    let evalDuration: Int?

    enum CodingKeys: String, CodingKey {
        case model
        case createdAt = "created_at"
        case message
        case done
        case doneReason = "done_reason"
        case totalDuration = "total_duration"
        case loadDuration = "load_duration"
        case promptEvalCount = "prompt_eval_count"
        case promptEvalDuration = "prompt_eval_duration"
        case evalCount = "eval_count"
        case evalDuration = "eval_duration"
    }

    struct Message: Codable, Sendable {
        let role: String
        let content: String
    }
}

private struct OllamaModelsResponse: Codable, Sendable {
    let models: [ModelInfo]

    struct ModelInfo: Codable, Sendable {
        let name: String
        let model: String?
        let modifiedAt: String?
        let size: Int?
        let digest: String?

        enum CodingKeys: String, CodingKey {
            case name, model
            case modifiedAt = "modified_at"
            case size, digest
        }
    }
}

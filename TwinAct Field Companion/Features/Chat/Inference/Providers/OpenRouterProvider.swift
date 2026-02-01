//
//  OpenRouterProvider.swift
//  TwinAct Field Companion
//
//  OpenRouter API provider implementation.
//

import Foundation
import os.log

// MARK: - OpenRouter Provider

/// Provider for OpenRouter's API (unified access to multiple models)
/// OpenRouter uses an OpenAI-compatible format with additional headers.
public actor OpenRouterProvider: CloudAIProvider {

    // MARK: - Properties

    public nonisolated let providerType: InferenceProviderType = .cloud

    private let configuration: AIProviderConfiguration
    private let apiKey: String?
    private let httpClient: HTTPClient
    private let safetyPolicy: SafetyPolicy
    private var currentTask: Task<GenerationResult, Error>?
    private let logger: Logger

    private let appName = "TwinAct Field Companion"

    // MARK: - Initialization

    /// Initialize OpenRouter provider
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
            category: "OpenRouterProvider"
        )

        let httpConfig = HTTPClientConfiguration(
            baseURL: configuration.baseURL,
            defaultTimeout: configuration.timeout,
            maxRetryAttempts: configuration.maxRetries
        )
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = configuration.timeout
        sessionConfig.timeoutIntervalForResource = configuration.timeout * 2
        sessionConfig.waitsForConnectivity = false
        sessionConfig.httpMaximumConnectionsPerHost = AppConfiguration.AASServer.maxConcurrentConnections
        let session = URLSession(configuration: sessionConfig)
        self.httpClient = HTTPClient(configuration: httpConfig, session: session)
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
        let prefix = apiVersionPathPrefix

        // Test with models endpoint
        let endpoint = Endpoint(
            path: "\(prefix)/models",
            method: .get,
            headers: headers,
            timeout: 10.0
        )

        do {
            let _: OpenRouterModelsResponse = try await httpClient.request(endpoint)
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
        guard let apiKey = apiKey, !apiKey.isEmpty else {
            return []
        }

        let headers = buildHeaders(apiKey: apiKey)
        let prefix = apiVersionPathPrefix

        let endpoint = Endpoint(
            path: "\(prefix)/models",
            method: .get,
            headers: headers,
            timeout: 30.0
        )

        let response: OpenRouterModelsResponse = try await httpClient.request(endpoint)

        return response.data.compactMap { model -> AIProviderModel? in
            // Parse context length from model info
            let contextWindow = model.contextLength ?? 4096

            return AIProviderModel(
                modelId: model.id,
                displayName: model.name ?? model.id,
                contextWindow: contextWindow,
                maxOutputTokens: model.topProvider?.maxCompletionTokens,
                supportsVision: false,
                provider: .openRouter
            )
        }
    }

    // MARK: - Private Methods

    private func performGeneration(
        prompt: String,
        options: GenerationOptions,
        apiKey: String
    ) async throws -> GenerationResult {
        // Unique build marker - if you see this, the Feb 1 2026 code is running
        logger.info("🔵 OpenRouterProvider v2.1 - performGeneration called")

        let headers = buildHeaders(apiKey: apiKey)

        // Build messages array (OpenAI-compatible format)
        var messages: [OpenRouterMessage] = []

        // Add system message if provided
        if let systemPrompt = options.systemPrompt {
            messages.append(OpenRouterMessage(role: "system", content: systemPrompt))
        }

        // Add user message
        messages.append(OpenRouterMessage(role: "user", content: prompt))

        let requestBody = OpenRouterRequest(
            model: configuration.modelId,
            messages: messages,
            maxTokens: options.maxTokens,
            temperature: options.temperature,
            topP: options.topP,
            stop: options.stopSequences,
            stream: false  // Disable streaming - we don't support SSE parsing yet
        )

        // Log request body to verify stream=false is included
        // Using same encoder as Endpoint.post to match actual request
        let debugEncoder = JSONEncoder()
        debugEncoder.keyEncodingStrategy = .convertToSnakeCase
        if let jsonData = try? debugEncoder.encode(requestBody),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            logger.info("OpenRouter request body: \(jsonString)")
        }

        let prefix = apiVersionPathPrefix
        let endpoint = try Endpoint.post(
            "\(prefix)/chat/completions",
            body: requestBody,
            headers: headers,
            timeout: configuration.timeout
        )

        logger.info("Sending request to OpenRouter API (stream=false)")

        // Get raw response data first to handle error responses
        let responseData: Data = try await httpClient.request(endpoint)

        // Check for SSE streaming response (OpenRouter may ignore stream:false)
        if let responsePreview = String(data: responseData.prefix(100), encoding: .utf8) {
            logger.info("Response preview (first 100 chars): \(responsePreview)")
            if responsePreview.hasPrefix("data:") || responsePreview.contains("\ndata:") {
                logger.error("OpenRouter returned SSE streaming response despite stream:false")
                throw InferenceError.providerError(
                    provider: "OpenRouter",
                    message: "Server returned streaming response. Please try a different model or contact support.",
                    code: "streaming_response"
                )
            }
        }

        try Task.checkCancellation()

        // Try to decode as error response first
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        if let errorResponse = try? decoder.decode(OpenRouterErrorResponse.self, from: responseData),
           let errorDetail = errorResponse.error {
            logger.error("OpenRouter API error: \(errorDetail.message)")
            throw InferenceError.providerError(
                provider: "OpenRouter",
                message: errorDetail.message,
                code: errorDetail.code
            )
        }

        // Decode as success response
        let response: OpenRouterResponse
        do {
            response = try decoder.decode(OpenRouterResponse.self, from: responseData)
        } catch {
            // Log raw response preview for debugging (truncated for security)
            let preview = String(data: responseData.prefix(500), encoding: .utf8) ?? "Unable to decode"
            logger.error("Failed to decode OpenRouter response: \(error.localizedDescription)")
            logger.debug("Response preview: \(preview)")
            throw InferenceError.invalidResponse
        }

        logger.debug("OpenRouter response: choices=\(response.choices.count)")

        // Extract text from first choice with validation
        guard let choice = response.choices.first else {
            logger.error("OpenRouter returned empty choices array")
            throw InferenceError.invalidResponse
        }

        // Try to get content - for reasoning models, content might be in 'reasoning' field
        // or some models return content separately from reasoning
        let responseContent: String
        if let content = choice.message.content, !content.isEmpty {
            responseContent = content
            logger.debug("Response content length: \(content.count) characters")
        } else if let reasoning = choice.message.reasoning, !reasoning.isEmpty {
            // Fallback: some reasoning models might only return reasoning
            responseContent = reasoning
            logger.info("Using reasoning field as response (content was empty)")
        } else {
            // Log what we actually received for debugging
            logger.error("OpenRouter returned empty response - content: \(choice.message.content ?? "nil"), reasoning: \(choice.message.reasoning ?? "nil")")
            throw InferenceError.invalidResponse
        }

        return GenerationResult(
            text: responseContent,
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
            "Authorization": "Bearer \(apiKey)",
            "HTTP-Referer": "https://twinact.example.com",
            "X-Title": appName
        ]
    }

    private var apiVersionPathPrefix: String {
        let pathComponents = configuration.baseURL.path
            .split(separator: "/")
            .map { $0.lowercased() }
        if pathComponents.contains("v1") {
            return ""
        }
        return "/v1"
    }
}

// MARK: - OpenRouter API Models

private struct OpenRouterRequest: Codable, Sendable {
    let model: String
    let messages: [OpenRouterMessage]
    let maxTokens: Int?
    let temperature: Double?
    let topP: Double?
    let stop: [String]?
    let stream: Bool

    enum CodingKeys: String, CodingKey {
        case model, messages
        case maxTokens = "max_tokens"
        case temperature
        case topP = "top_p"
        case stop
        case stream
    }
}

private struct OpenRouterMessage: Codable, Sendable {
    let role: String
    let content: String
}

private struct OpenRouterResponse: Codable, Sendable {
    let id: String
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
            let reasoning: String?  // For reasoning models (o1, o4-mini, etc.)
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

private struct OpenRouterModelsResponse: Codable, Sendable {
    let data: [ModelInfo]

    struct ModelInfo: Codable, Sendable {
        let id: String
        let name: String?
        let contextLength: Int?
        let topProvider: TopProvider?

        enum CodingKeys: String, CodingKey {
            case id, name
            case contextLength = "context_length"
            case topProvider = "top_provider"
        }

        struct TopProvider: Codable, Sendable {
            let maxCompletionTokens: Int?

            enum CodingKeys: String, CodingKey {
                case maxCompletionTokens = "max_completion_tokens"
            }
        }
    }
}

// MARK: - OpenRouter Error Response

/// Error response format returned by OpenRouter API
private struct OpenRouterErrorResponse: Codable, Sendable {
    let error: ErrorDetail?

    struct ErrorDetail: Codable, Sendable {
        let message: String
        let type: String?
        let code: String?
    }
}

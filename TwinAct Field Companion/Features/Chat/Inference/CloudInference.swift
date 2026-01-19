//
//  CloudInference.swift
//  TwinAct Field Companion
//
//  Cloud-based LLM inference via API.
//

import Foundation
import os.log

// MARK: - Cloud Inference

/// Cloud LLM inference via API
/// Used as fallback when on-device inference is unavailable or for higher quality responses.
public final class CloudInference: InferenceProvider, @unchecked Sendable {

    // MARK: - Properties

    public let providerType: InferenceProviderType = .cloud

    private let httpClient: HTTPClient
    private let endpoint: URL
    private let apiKey: String?
    private let safetyPolicy: SafetyPolicy
    private var currentTask: Task<GenerationResult, Error>?
    private let logger: Logger

    private let lock = NSLock()

    /// Whether cloud inference is available (endpoint configured)
    public var isAvailable: Bool {
        get async {
            // Check if we have a valid endpoint
            return true  // Endpoint is always configured via AppConfiguration
        }
    }

    // MARK: - Initialization

    /// Initialize cloud inference
    /// - Parameters:
    ///   - endpoint: API endpoint URL (defaults to app configuration)
    ///   - apiKey: Optional API key for authentication
    ///   - httpClient: HTTP client to use
    public init(
        endpoint: URL? = nil,
        apiKey: String? = nil,
        httpClient: HTTPClient? = nil
    ) {
        self.endpoint = endpoint ?? AppConfiguration.GenAI.cloudAPIEndpoint
        self.apiKey = apiKey
        self.safetyPolicy = SafetyPolicy()
        self.logger = Logger(
            subsystem: AppConfiguration.AppInfo.bundleIdentifier,
            category: "CloudInference"
        )

        // Create HTTP client configured for GenAI endpoint
        if let client = httpClient {
            self.httpClient = client
        } else {
            let config = HTTPClientConfiguration(
                baseURL: self.endpoint,
                defaultTimeout: 60.0,  // Longer timeout for generation
                maxRetryAttempts: 2
            )
            self.httpClient = HTTPClient(configuration: config)
        }
    }

    // MARK: - Generation

    /// Generate text from a prompt
    public func generate(
        prompt: String,
        options: GenerationOptions
    ) async throws -> GenerationResult {
        let startTime = Date()

        // Apply safety policy to filter PII before sending to cloud
        let filteredPrompt = SafetyPolicy.filterPII(prompt)

        // Create cancellable task
        let task = Task<GenerationResult, Error> {
            try await performCloudGeneration(
                prompt: filteredPrompt,
                options: options
            )
        }

        lock.lock()
        currentTask = task
        lock.unlock()

        defer {
            lock.lock()
            currentTask = nil
            lock.unlock()
        }

        do {
            var result = try await task.value
            let duration = Date().timeIntervalSince(startTime)

            // Validate response safety
            if !SafetyPolicy.validateResponse(result.text) {
                throw InferenceError.safetyViolation(
                    reason: "Response failed safety validation"
                )
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
        } catch let error as HTTPError {
            throw mapHTTPError(error)
        } catch {
            throw InferenceError.networkError(underlying: error)
        }
    }

    /// Cancel ongoing generation
    public func cancel() async {
        lock.lock()
        let task = currentTask
        lock.unlock()

        task?.cancel()
    }

    // MARK: - Private Methods

    private func performCloudGeneration(
        prompt: String,
        options: GenerationOptions
    ) async throws -> GenerationResult {
        // Build request body
        let requestBody = CloudGenerationRequest(
            prompt: prompt,
            maxTokens: options.maxTokens,
            temperature: options.temperature,
            topP: options.topP,
            stopSequences: options.stopSequences,
            systemPrompt: options.systemPrompt
        )

        // Create endpoint
        var headers: [String: String] = [
            "Content-Type": "application/json"
        ]

        if let apiKey = apiKey {
            headers["Authorization"] = "Bearer \(apiKey)"
        }

        let endpoint = try Endpoint.post(
            "/generate",
            body: requestBody,
            headers: headers,
            timeout: 60.0
        )

        // Make request
        logger.info("Sending cloud generation request")
        let response: CloudGenerationResponse = try await httpClient.request(endpoint)

        try Task.checkCancellation()

        // Parse response
        guard let text = response.text ?? response.choices?.first?.text else {
            throw InferenceError.invalidResponse
        }

        return GenerationResult(
            text: text,
            promptTokens: response.usage?.promptTokens,
            completionTokens: response.usage?.completionTokens,
            provider: .cloud,
            wasTruncated: response.choices?.first?.finishReason == "length",
            finishReason: response.choices?.first?.finishReason
        )
    }

    /// Map HTTP errors to inference errors
    private func mapHTTPError(_ error: HTTPError) -> InferenceError {
        switch error {
        case .timeout:
            return .timeout
        case .cancelled:
            return .cancelled
        case .tooManyRequests:
            return .rateLimited(retryAfter: nil)
        case .networkError(let underlying):
            return .networkError(underlying: underlying)
        case .unauthorized, .forbidden:
            return .generationFailed(reason: "Authentication failed")
        default:
            return .generationFailed(reason: error.localizedDescription ?? "Unknown error")
        }
    }

    // MARK: - Status

    /// Get provider status information
    public func getStatus() async -> InferenceProviderStatus {
        InferenceProviderStatus(
            providerType: .cloud,
            isAvailable: await isAvailable,
            modelName: "Cloud LLM",
            modelVersion: nil,
            lastError: nil
        )
    }
}

// MARK: - API Request/Response Models

/// Request body for cloud generation
private struct CloudGenerationRequest: Codable, Sendable {
    let prompt: String
    let maxTokens: Int
    let temperature: Double
    let topP: Double?
    let stopSequences: [String]?
    let systemPrompt: String?

    enum CodingKeys: String, CodingKey {
        case prompt
        case maxTokens = "max_tokens"
        case temperature
        case topP = "top_p"
        case stopSequences = "stop_sequences"
        case systemPrompt = "system_prompt"
    }
}

/// Response from cloud generation
private struct CloudGenerationResponse: Codable, Sendable {
    /// Direct text response (simple API format)
    let text: String?

    /// Choices array (OpenAI-compatible format)
    let choices: [Choice]?

    /// Token usage statistics
    let usage: Usage?

    /// Response ID
    let id: String?

    struct Choice: Codable, Sendable {
        let text: String?
        let message: Message?
        let finishReason: String?

        enum CodingKeys: String, CodingKey {
            case text
            case message
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
        let totalTokens: Int?

        enum CodingKeys: String, CodingKey {
            case promptTokens = "prompt_tokens"
            case completionTokens = "completion_tokens"
            case totalTokens = "total_tokens"
        }
    }
}

// MARK: - Cloud Inference Factory

/// Factory for creating cloud inference providers with different configurations
public struct CloudInferenceFactory {

    /// Create cloud inference with API key from environment
    public static func fromEnvironment() -> CloudInference? {
        guard let apiKey = ProcessInfo.processInfo.environment["GENAI_API_KEY"] else {
            return nil
        }
        return CloudInference(apiKey: apiKey)
    }

    /// Create cloud inference with custom endpoint
    public static func withEndpoint(_ endpoint: URL, apiKey: String? = nil) -> CloudInference {
        CloudInference(endpoint: endpoint, apiKey: apiKey)
    }
}

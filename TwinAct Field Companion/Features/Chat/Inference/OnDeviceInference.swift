//
//  OnDeviceInference.swift
//  TwinAct Field Companion
//
//  On-device LLM inference using Core ML.
//

import Foundation
import CoreML
import os.log

// MARK: - On-Device Inference

/// On-device LLM inference using Core ML
/// Provides privacy-preserving local inference without network connectivity.
public actor OnDeviceInference: InferenceProvider {

    // MARK: - Properties

    public nonisolated let providerType: InferenceProviderType = .onDevice

    private var model: MLModel?
    private var tokenizer: Tokenizer?
    private var isModelLoading: Bool = false
    private var currentTask: Task<GenerationResult, Error>?
    private let modelName: String
    private let logger: Logger

    /// Whether the on-device model is available
    public var isAvailable: Bool {
        get async {
            return model != nil
        }
    }

    // MARK: - Initialization

    /// Initialize with a specific model name
    /// - Parameter modelName: Name of the Core ML model bundle (without .mlmodelc extension)
    public init(modelName: String = "TwinActLLM") {
        self.modelName = modelName
        self.logger = Logger(
            subsystem: AppConfiguration.AppInfo.bundleIdentifier,
            category: "OnDeviceInference"
        )

        // Attempt to load model on initialization
        Task {
            await loadModel()
        }
    }

    // MARK: - Model Loading

    /// Load the Core ML model
    @discardableResult
    public func loadModel() async -> Bool {
        guard model == nil && !isModelLoading else {
            return model != nil
        }
        isModelLoading = true
        defer { isModelLoading = false }

        logger.info("Loading on-device model: \(self.modelName)")

        do {
            // Look for the model in the app bundle
            guard let modelURL = Bundle.main.url(
                forResource: modelName,
                withExtension: "mlmodelc"
            ) else {
                logger.warning("On-device model \(self.modelName).mlmodelc not found in bundle")
                return false
            }

            // Configure model for optimal performance
            let config = MLModelConfiguration()
            config.computeUnits = .cpuAndNeuralEngine  // Use Neural Engine when available

            // Load the model
            let loadedModel = try await MLModel.load(contentsOf: modelURL, configuration: config)

            self.model = loadedModel

            // Initialize tokenizer
            await loadTokenizer()

            logger.info("On-device model loaded successfully")
            return true

        } catch {
            logger.error("Failed to load on-device model: \(error.localizedDescription)")
            return false
        }
    }

    /// Load the tokenizer for the model
    private func loadTokenizer() async {
        // Look for tokenizer configuration in bundle
        if let tokenizerURL = Bundle.main.url(forResource: "\(modelName)-tokenizer", withExtension: "json") {
            do {
                let data = try Data(contentsOf: tokenizerURL)
                self.tokenizer = try JSONDecoder().decode(Tokenizer.self, from: data)
                logger.info("Tokenizer loaded")
            } catch {
                logger.warning("Failed to load tokenizer: \(error.localizedDescription)")
                // Use default tokenizer
                self.tokenizer = Tokenizer.default
            }
        } else {
            // Use default simple tokenizer
            self.tokenizer = Tokenizer.default
        }
    }

    /// Unload the model to free memory
    public func unloadModel() async {
        model = nil
        tokenizer = nil
        logger.info("On-device model unloaded")
    }

    // MARK: - Generation

    /// Generate text from a prompt
    public func generate(
        prompt: String,
        options: GenerationOptions
    ) async throws -> GenerationResult {
        guard let model = model else {
            throw InferenceError.modelNotLoaded
        }

        let startTime = Date()

        // Create cancellable task
        let task = Task<GenerationResult, Error> {
            try await performGeneration(
                prompt: prompt,
                options: options,
                model: model
            )
        }

        currentTask = task
        defer { currentTask = nil }

        do {
            let result = try await task.value
            let duration = Date().timeIntervalSince(startTime)

            return GenerationResult(
                text: result.text,
                promptTokens: result.promptTokens,
                completionTokens: result.completionTokens,
                provider: .onDevice,
                duration: duration,
                wasTruncated: result.wasTruncated,
                finishReason: result.finishReason
            )
        } catch is CancellationError {
            throw InferenceError.cancelled
        }
    }

    /// Cancel ongoing generation
    public func cancel() async {
        currentTask?.cancel()
    }

    // MARK: - Private Generation

    private func performGeneration(
        prompt: String,
        options: GenerationOptions,
        model: MLModel
    ) async throws -> GenerationResult {
        // Tokenize input
        let inputTokens = tokenizer?.encode(prompt) ?? simpleTokenize(prompt)
        let promptTokenCount = inputTokens.count

        // Check context length
        let maxContextLength = 2048  // Typical for small on-device models
        if promptTokenCount > maxContextLength - options.maxTokens {
            throw InferenceError.contextTooLong(maxTokens: maxContextLength)
        }

        // For actual Core ML model inference, you would:
        // 1. Convert tokens to MLMultiArray input
        // 2. Run model.prediction()
        // 3. Decode output tokens
        // 4. Handle autoregressive generation loop

        // Since we don't have an actual model bundled, provide a placeholder response
        // In production, this would be replaced with actual model inference
        let generatedText = await simulateGeneration(prompt: prompt, options: options)

        try Task.checkCancellation()

        let completionTokens = tokenizer?.encode(generatedText).count ?? simpleTokenize(generatedText).count

        return GenerationResult(
            text: generatedText,
            promptTokens: promptTokenCount,
            completionTokens: completionTokens,
            provider: .onDevice,
            wasTruncated: completionTokens >= options.maxTokens,
            finishReason: completionTokens >= options.maxTokens ? "length" : "stop"
        )
    }

    /// Simulate generation for development/testing
    /// This would be replaced by actual model inference in production
    private func simulateGeneration(prompt: String, options: GenerationOptions) async -> String {
        // Small delay to simulate inference time
        try? await Task.sleep(nanoseconds: 500_000_000)  // 0.5 seconds

        // Return a placeholder indicating on-device inference
        return """
        [On-device model response]

        I'm processing your question locally on this device for privacy. \
        The actual response would be generated by the bundled Core ML model.

        For full functionality, ensure the on-device model (\(modelName).mlmodelc) \
        is included in the app bundle.
        """
    }

    /// Simple tokenization fallback
    private func simpleTokenize(_ text: String) -> [Int] {
        // Very basic word-level tokenization
        // Real tokenization would use BPE or similar
        return text.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .enumerated()
            .map { $0.offset }
    }

    // MARK: - Status

    /// Get provider status information
    public func getStatus() async -> InferenceProviderStatus {
        InferenceProviderStatus(
            providerType: .onDevice,
            isAvailable: await isAvailable,
            modelName: modelName,
            modelVersion: nil,
            lastError: model == nil ? "Model not loaded" : nil
        )
    }
}

// MARK: - Tokenizer

/// Simple tokenizer for on-device models
public struct Tokenizer: Codable, Sendable {
    public let vocabSize: Int
    public let bosToken: Int
    public let eosToken: Int
    public let padToken: Int

    private let vocab: [String: Int]?
    private let reverseVocab: [Int: String]?

    public init(
        vocabSize: Int = 32000,
        bosToken: Int = 1,
        eosToken: Int = 2,
        padToken: Int = 0,
        vocab: [String: Int]? = nil
    ) {
        self.vocabSize = vocabSize
        self.bosToken = bosToken
        self.eosToken = eosToken
        self.padToken = padToken
        self.vocab = vocab
        self.reverseVocab = vocab?.reduce(into: [:]) { $0[$1.value] = $1.key }
    }

    /// Default tokenizer for when no specific tokenizer is available
    public static let `default` = Tokenizer()

    /// Encode text to token IDs (simplified)
    public func encode(_ text: String) -> [Int] {
        if let vocab = vocab {
            // Use vocabulary for encoding
            var tokens = [bosToken]
            let words = text.lowercased().components(separatedBy: .whitespacesAndNewlines)
            for word in words where !word.isEmpty {
                if let id = vocab[word] {
                    tokens.append(id)
                } else {
                    // Unknown token handling
                    tokens.append(3)  // <unk>
                }
            }
            return tokens
        } else {
            // Simple hash-based encoding
            var tokens = [bosToken]
            let words = text.components(separatedBy: .whitespacesAndNewlines)
            for word in words where !word.isEmpty {
                let hash = abs(word.hashValue) % (vocabSize - 4) + 4
                tokens.append(hash)
            }
            return tokens
        }
    }

    /// Decode token IDs to text (simplified)
    public func decode(_ tokens: [Int]) -> String {
        if let reverseVocab = reverseVocab {
            return tokens
                .filter { $0 != bosToken && $0 != eosToken && $0 != padToken }
                .compactMap { reverseVocab[$0] }
                .joined(separator: " ")
        } else {
            return "[Decoded output]"
        }
    }
}

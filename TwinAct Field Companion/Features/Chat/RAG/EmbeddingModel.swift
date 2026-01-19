//
//  EmbeddingModel.swift
//  TwinAct Field Companion
//
//  Generates embeddings using on-device NaturalLanguage framework.
//

import Foundation
import NaturalLanguage
import os.log

// MARK: - Embedding Errors

/// Errors that can occur during embedding generation
public enum EmbeddingError: Error, LocalizedError {
    case modelNotAvailable
    case embeddingFailed(text: String)
    case dimensionMismatch(expected: Int, got: Int)
    case emptyInput

    public var errorDescription: String? {
        switch self {
        case .modelNotAvailable:
            return "Embedding model is not available for this language"
        case .embeddingFailed(let text):
            return "Failed to generate embedding for text: \(text.prefix(50))..."
        case .dimensionMismatch(let expected, let got):
            return "Embedding dimension mismatch: expected \(expected), got \(got)"
        case .emptyInput:
            return "Cannot generate embedding for empty text"
        }
    }
}

// MARK: - Embedding Model Protocol

/// Protocol for embedding models
public protocol EmbeddingModelProtocol: Sendable {
    /// The dimension of generated embeddings
    var dimension: Int { get }

    /// Whether the model is ready for use
    var isAvailable: Bool { get }

    /// Generate embedding for a single text
    func embed(_ text: String) throws -> [Float]

    /// Generate embeddings for multiple texts
    func embedBatch(_ texts: [String]) throws -> [[Float]]
}

// MARK: - On-Device Embedding Model

/// Generates embeddings using Apple's built-in NLEmbedding
public final class EmbeddingModel: EmbeddingModelProtocol, @unchecked Sendable {

    // MARK: - Properties

    private let embedding: NLEmbedding?
    private let language: NLLanguage
    private let logger: Logger

    /// The dimension of the embedding vectors
    public var dimension: Int {
        embedding?.dimension ?? 0
    }

    /// Whether the embedding model is available
    public var isAvailable: Bool {
        embedding != nil
    }

    // MARK: - Initialization

    /// Initialize embedding model for a specific language
    /// - Parameter language: Language for embeddings (default: English)
    public init(language: NLLanguage = .english) {
        self.language = language
        self.logger = Logger(
            subsystem: AppConfiguration.AppInfo.bundleIdentifier,
            category: "EmbeddingModel"
        )

        // Use Apple's built-in sentence embedding
        self.embedding = NLEmbedding.sentenceEmbedding(for: language)

        if embedding != nil {
            logger.info("Initialized embedding model for \(language.rawValue) with dimension \(self.dimension)")
        } else {
            logger.warning("Sentence embedding not available for \(language.rawValue)")
        }
    }

    /// Initialize with automatic language detection
    public convenience init() {
        self.init(language: .english)
    }

    // MARK: - Public API

    /// Generate embedding for text
    /// - Parameter text: Text to embed
    /// - Returns: Float array of embedding values
    public func embed(_ text: String) throws -> [Float] {
        guard let embedding = embedding else {
            throw EmbeddingError.modelNotAvailable
        }

        let cleanedText = preprocessText(text)

        guard !cleanedText.isEmpty else {
            throw EmbeddingError.emptyInput
        }

        // NLEmbedding returns Double array, convert to Float
        guard let vector = embedding.vector(for: cleanedText) else {
            logger.error("Failed to generate embedding for: \(cleanedText.prefix(100))")
            throw EmbeddingError.embeddingFailed(text: cleanedText)
        }

        return vector.map { Float($0) }
    }

    /// Generate embedding or return nil on failure
    /// - Parameter text: Text to embed
    /// - Returns: Float array or nil if embedding fails
    public func embedOrNil(_ text: String) -> [Float]? {
        try? embed(text)
    }

    /// Generate embeddings for multiple texts
    /// - Parameter texts: Array of texts to embed
    /// - Returns: Array of embedding vectors
    public func embedBatch(_ texts: [String]) throws -> [[Float]] {
        try texts.map { try embed($0) }
    }

    /// Generate embeddings for multiple texts, returning nil for failures
    /// - Parameter texts: Array of texts to embed
    /// - Returns: Array of optional embedding vectors
    public func embedBatchOrNil(_ texts: [String]) -> [[Float]?] {
        texts.map { embedOrNil($0) }
    }

    // MARK: - Similarity Computation

    /// Compute cosine similarity between two texts
    /// - Parameters:
    ///   - text1: First text
    ///   - text2: Second text
    /// - Returns: Similarity score between -1 and 1
    public func similarity(between text1: String, and text2: String) throws -> Float {
        let embedding1 = try embed(text1)
        let embedding2 = try embed(text2)
        return cosineSimilarity(embedding1, embedding2)
    }

    /// Compute cosine similarity between two embedding vectors
    /// - Parameters:
    ///   - a: First embedding vector
    ///   - b: Second embedding vector
    /// - Returns: Similarity score between -1 and 1
    public func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count else { return 0 }

        var dotProduct: Float = 0
        var normA: Float = 0
        var normB: Float = 0

        for i in 0..<a.count {
            dotProduct += a[i] * b[i]
            normA += a[i] * a[i]
            normB += b[i] * b[i]
        }

        let denominator = sqrt(normA) * sqrt(normB)
        guard denominator > 0 else { return 0 }

        return dotProduct / denominator
    }

    // MARK: - Text Preprocessing

    /// Preprocess text before embedding
    private func preprocessText(_ text: String) -> String {
        var processed = text

        // Normalize whitespace
        processed = processed.replacingOccurrences(
            of: "\\s+",
            with: " ",
            options: .regularExpression
        )

        // Trim
        processed = processed.trimmingCharacters(in: .whitespacesAndNewlines)

        // Truncate very long text (NLEmbedding may have limits)
        if processed.count > 10000 {
            processed = String(processed.prefix(10000))
        }

        return processed
    }
}

// MARK: - Embedding Model Factory

/// Factory for creating embedding models
public struct EmbeddingModelFactory {

    /// Create an embedding model for the specified language
    /// - Parameter languageCode: ISO 639-1 language code
    /// - Returns: An embedding model if available
    public static func create(for languageCode: String) -> EmbeddingModel? {
        let language = NLLanguage(languageCode)

        // Check if sentence embedding is available for this language
        guard NLEmbedding.sentenceEmbedding(for: language) != nil else {
            return nil
        }

        return EmbeddingModel(language: language)
    }

    /// Create embedding model with automatic language detection
    /// - Parameter text: Sample text for language detection
    /// - Returns: An embedding model for the detected language or English fallback
    public static func createWithLanguageDetection(from text: String) -> EmbeddingModel {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)

        if let detectedLanguage = recognizer.dominantLanguage,
           NLEmbedding.sentenceEmbedding(for: detectedLanguage) != nil {
            return EmbeddingModel(language: detectedLanguage)
        }

        // Fallback to English
        return EmbeddingModel(language: .english)
    }

    /// List all available languages for sentence embedding
    public static var availableLanguages: [NLLanguage] {
        // Check common languages
        let candidateLanguages: [NLLanguage] = [
            .english, .german, .french, .spanish, .italian,
            .portuguese, .dutch, .swedish, .danish, .norwegian,
            .finnish, .polish, .russian, .japanese, .simplifiedChinese,
            .traditionalChinese, .korean, .arabic, .hindi, .turkish
        ]

        return candidateLanguages.filter { language in
            NLEmbedding.sentenceEmbedding(for: language) != nil
        }
    }
}

// MARK: - Document Chunk Extension

extension DocumentChunk {
    /// Create a new chunk with embedding
    public func withEmbedding(_ embedding: [Float]) -> DocumentChunk {
        var newChunk = self
        newChunk.embedding = embedding
        return newChunk
    }
}

// MARK: - Batch Embedding Utility

/// Utility for embedding multiple document chunks
public actor ChunkEmbedder {

    private let embeddingModel: EmbeddingModel
    private let batchSize: Int

    public init(embeddingModel: EmbeddingModel = EmbeddingModel(), batchSize: Int = 50) {
        self.embeddingModel = embeddingModel
        self.batchSize = batchSize
    }

    /// Embed all chunks in a document
    /// - Parameter chunks: Array of document chunks without embeddings
    /// - Returns: Array of chunks with embeddings
    public func embedChunks(_ chunks: [DocumentChunk]) async throws -> [DocumentChunk] {
        var embeddedChunks: [DocumentChunk] = []
        embeddedChunks.reserveCapacity(chunks.count)

        for chunk in chunks {
            let embedding = try embeddingModel.embed(chunk.text)
            embeddedChunks.append(chunk.withEmbedding(embedding))

            // Yield to allow cancellation
            await Task.yield()
        }

        return embeddedChunks
    }

    /// Embed chunks with progress reporting
    /// - Parameters:
    ///   - chunks: Array of document chunks
    ///   - progress: Closure called with progress (0.0 to 1.0)
    /// - Returns: Array of chunks with embeddings
    public func embedChunks(
        _ chunks: [DocumentChunk],
        progress: @Sendable (Double) async -> Void
    ) async throws -> [DocumentChunk] {
        var embeddedChunks: [DocumentChunk] = []
        embeddedChunks.reserveCapacity(chunks.count)

        let total = Double(chunks.count)

        for (index, chunk) in chunks.enumerated() {
            let embedding = try embeddingModel.embed(chunk.text)
            embeddedChunks.append(chunk.withEmbedding(embedding))

            let currentProgress = Double(index + 1) / total
            await progress(currentProgress)

            // Yield occasionally for responsiveness
            if index % 10 == 0 {
                await Task.yield()
            }
        }

        return embeddedChunks
    }
}

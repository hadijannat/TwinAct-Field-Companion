//
//  ContextRetriever.swift
//  TwinAct Field Companion
//
//  Retrieves relevant context for questions using semantic search.
//

import Foundation
import os.log

// MARK: - Context Retriever Errors

/// Errors that can occur during context retrieval
public enum ContextRetrieverError: Error, LocalizedError {
    case embeddingFailed
    case noContextFound
    case documentNotIndexed(documentId: String)

    public var errorDescription: String? {
        switch self {
        case .embeddingFailed:
            return "Failed to generate embedding for the query"
        case .noContextFound:
            return "No relevant context found for the question"
        case .documentNotIndexed(let documentId):
            return "Document \(documentId) has not been indexed"
        }
    }
}

// MARK: - Retrieved Context

/// Context retrieved for a question
public struct RetrievedContext: Sendable {
    /// Retrieved document chunks
    public let chunks: [DocumentChunk]

    /// Search scores for each chunk
    public let scores: [Float]

    /// Combined context text
    public var combinedText: String {
        chunks.map { $0.text }.joined(separator: "\n\n---\n\n")
    }

    /// Source document IDs
    public var sourceDocumentIds: [String] {
        Array(Set(chunks.map { $0.documentId }))
    }

    /// Source document titles
    public var sourceDocumentTitles: [String] {
        Array(Set(chunks.map { $0.documentTitle }))
    }

    /// Average relevance score
    public var averageScore: Float {
        guard !scores.isEmpty else { return 0 }
        return scores.reduce(0, +) / Float(scores.count)
    }

    /// Whether any relevant context was found
    public var isEmpty: Bool {
        chunks.isEmpty
    }

    public init(chunks: [DocumentChunk], scores: [Float]) {
        self.chunks = chunks
        self.scores = scores
    }

    public static let empty = RetrievedContext(chunks: [], scores: [])
}

// MARK: - Context Retriever Configuration

/// Configuration for context retrieval
public struct ContextRetrieverConfig: Sendable {
    /// Number of chunks to retrieve
    public var topK: Int

    /// Minimum similarity score for inclusion
    public var minScore: Float

    /// Maximum total context length in characters
    public var maxContextLength: Int

    /// Whether to deduplicate overlapping content
    public var deduplicateOverlaps: Bool

    /// Whether to include source citations
    public var includeCitations: Bool

    public init(
        topK: Int = 5,
        minScore: Float = 0.3,
        maxContextLength: Int = 8000,
        deduplicateOverlaps: Bool = true,
        includeCitations: Bool = true
    ) {
        self.topK = topK
        self.minScore = minScore
        self.maxContextLength = maxContextLength
        self.deduplicateOverlaps = deduplicateOverlaps
        self.includeCitations = includeCitations
    }

    public static let `default` = ContextRetrieverConfig()

    /// Configuration for precise retrieval (fewer, more relevant results)
    public static let precise = ContextRetrieverConfig(
        topK: 3,
        minScore: 0.5,
        maxContextLength: 4000
    )

    /// Configuration for broad retrieval (more context)
    public static let broad = ContextRetrieverConfig(
        topK: 10,
        minScore: 0.2,
        maxContextLength: 12000
    )
}

// MARK: - Context Retriever

/// Retrieves relevant context for questions using semantic search
public final class ContextRetriever: Sendable {

    // MARK: - Properties

    private let vectorStore: VectorStore
    private let embeddingModel: EmbeddingModel
    private let config: ContextRetrieverConfig
    private let logger: Logger

    // MARK: - Initialization

    public init(
        vectorStore: VectorStore,
        embeddingModel: EmbeddingModel = EmbeddingModel(),
        config: ContextRetrieverConfig = .default
    ) {
        self.vectorStore = vectorStore
        self.embeddingModel = embeddingModel
        self.config = config
        self.logger = Logger(
            subsystem: AppConfiguration.AppInfo.bundleIdentifier,
            category: "ContextRetriever"
        )
    }

    // MARK: - Public API

    /// Retrieve context for a question
    /// - Parameters:
    ///   - question: The user's question
    ///   - topK: Override for number of results (optional)
    /// - Returns: Retrieved context with chunks and scores
    public func retrieveContext(
        for question: String,
        topK: Int? = nil
    ) async -> RetrievedContext {
        let k = topK ?? config.topK

        // Generate query embedding
        guard let queryEmbedding = embeddingModel.embedOrNil(question) else {
            logger.error("Failed to embed query: \(question.prefix(100))")
            return .empty
        }

        // Search vector store
        let results = await vectorStore.search(
            queryEmbedding: queryEmbedding,
            topK: k,
            minScore: config.minScore
        )

        if results.isEmpty {
            logger.info("No results found for query: \(question.prefix(50))")
            return .empty
        }

        // Process results
        var chunks = results.map { $0.chunk }
        var scores = results.map { $0.score }

        // Deduplicate overlapping content if enabled
        if config.deduplicateOverlaps {
            (chunks, scores) = deduplicateChunks(chunks, scores: scores)
        }

        // Trim to max context length
        (chunks, scores) = trimToMaxLength(chunks, scores: scores)

        logger.info("Retrieved \(chunks.count) chunks for query")

        return RetrievedContext(chunks: chunks, scores: scores)
    }

    /// Retrieve context from specific documents only
    /// - Parameters:
    ///   - question: The user's question
    ///   - documentIds: Document IDs to search within
    ///   - topK: Override for number of results
    /// - Returns: Retrieved context
    public func retrieveContext(
        for question: String,
        fromDocuments documentIds: Set<String>,
        topK: Int? = nil
    ) async -> RetrievedContext {
        let k = topK ?? config.topK

        guard let queryEmbedding = embeddingModel.embedOrNil(question) else {
            logger.error("Failed to embed query")
            return .empty
        }

        let results = await vectorStore.search(
            queryEmbedding: queryEmbedding,
            withinDocuments: documentIds,
            topK: k
        )

        let filteredResults = results.filter { $0.score >= config.minScore }

        var chunks = filteredResults.map { $0.chunk }
        var scores = filteredResults.map { $0.score }

        if config.deduplicateOverlaps {
            (chunks, scores) = deduplicateChunks(chunks, scores: scores)
        }

        (chunks, scores) = trimToMaxLength(chunks, scores: scores)

        return RetrievedContext(chunks: chunks, scores: scores)
    }

    // MARK: - Prompt Building

    /// Build a prompt with retrieved context for LLM inference
    /// - Parameters:
    ///   - question: The user's question
    ///   - context: Retrieved context
    ///   - assetName: Optional asset name for context
    /// - Returns: Formatted prompt string
    public func buildPromptWithContext(
        question: String,
        context: RetrievedContext,
        assetName: String? = nil
    ) -> String {
        let assetContext = assetName.map { "for asset \"\($0)\"" } ?? ""

        if context.isEmpty {
            return """
            You are an assistant helping a technician \(assetContext).
            The user has asked a question, but no relevant documentation was found.
            Please indicate that you don't have documentation to answer this specific question,
            and suggest they consult the original documentation or contact support.

            Question: \(question)

            Answer:
            """
        }

        let contextText: String
        if config.includeCitations {
            contextText = context.chunks.enumerated().map { index, chunk in
                let citation = "[Source \(index + 1): \(chunk.documentTitle)"
                let pageInfo = chunk.pageNumber.map { ", Page \($0)" } ?? ""
                return "\(citation)\(pageInfo)]\n\(chunk.text)"
            }.joined(separator: "\n\n---\n\n")
        } else {
            contextText = context.combinedText
        }

        return """
        You are an assistant helping a technician with an industrial asset \(assetContext).
        Use the following documentation excerpts to answer the question.
        If the answer is not clearly stated in the documentation, say so.
        Be concise and technical. Reference specific procedures or warnings when relevant.

        Documentation:
        \(contextText)

        Question: \(question)

        Answer:
        """
    }

    /// Build a prompt for follow-up questions in a conversation
    /// - Parameters:
    ///   - question: The follow-up question
    ///   - context: Retrieved context
    ///   - previousMessages: Previous conversation messages for context
    /// - Returns: Formatted prompt string
    public func buildConversationalPrompt(
        question: String,
        context: RetrievedContext,
        previousMessages: [(role: String, content: String)]
    ) -> String {
        var prompt = """
        You are an assistant helping a technician with an industrial asset.
        Use the following documentation excerpts and conversation history to answer the question.

        Documentation:
        \(context.combinedText)

        Conversation history:
        """

        for message in previousMessages.suffix(6) {  // Last 3 exchanges
            prompt += "\n\(message.role.capitalized): \(message.content)"
        }

        prompt += """

        Current question: \(question)

        Answer:
        """

        return prompt
    }

    // MARK: - Private Methods

    /// Remove overlapping content between chunks
    private func deduplicateChunks(
        _ chunks: [DocumentChunk],
        scores: [Float]
    ) -> ([DocumentChunk], [Float]) {
        guard chunks.count > 1 else { return (chunks, scores) }

        var result: [DocumentChunk] = []
        var resultScores: [Float] = []
        var seenContent = Set<String>()

        for (index, chunk) in chunks.enumerated() {
            // Create a simplified key for overlap detection
            let key = simplifyForComparison(chunk.text)

            // Check for significant overlap with already added chunks
            var hasSignificantOverlap = false
            for seen in seenContent {
                if calculateOverlap(key, seen) > 0.7 {
                    hasSignificantOverlap = true
                    break
                }
            }

            if !hasSignificantOverlap {
                result.append(chunk)
                resultScores.append(scores[index])
                seenContent.insert(key)
            }
        }

        return (result, resultScores)
    }

    /// Simplify text for comparison
    private func simplifyForComparison(_ text: String) -> String {
        text.lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .prefix(50)
            .joined(separator: " ")
    }

    /// Calculate overlap ratio between two strings
    private func calculateOverlap(_ a: String, _ b: String) -> Float {
        let wordsA = Set(a.components(separatedBy: " "))
        let wordsB = Set(b.components(separatedBy: " "))

        let intersection = wordsA.intersection(wordsB).count
        let union = wordsA.union(wordsB).count

        guard union > 0 else { return 0 }
        return Float(intersection) / Float(union)
    }

    /// Trim chunks to fit within max context length
    private func trimToMaxLength(
        _ chunks: [DocumentChunk],
        scores: [Float]
    ) -> ([DocumentChunk], [Float]) {
        var result: [DocumentChunk] = []
        var resultScores: [Float] = []
        var totalLength = 0

        for (index, chunk) in chunks.enumerated() {
            let chunkLength = chunk.text.count

            if totalLength + chunkLength <= config.maxContextLength {
                result.append(chunk)
                resultScores.append(scores[index])
                totalLength += chunkLength
            } else {
                // Partial inclusion if there's room
                let remainingSpace = config.maxContextLength - totalLength
                if remainingSpace > 200 {  // At least 200 chars of useful content
                    var truncatedChunk = chunk
                    let truncatedText = String(chunk.text.prefix(remainingSpace))
                    // Note: We'd need to create a new chunk with truncated text
                    // For simplicity, we'll just stop here
                }
                break
            }
        }

        return (result, resultScores)
    }
}

// MARK: - Convenience Extensions

extension ContextRetriever {

    /// Quick check if documents have been indexed
    public func hasIndexedDocuments() async -> Bool {
        await vectorStore.chunkCount > 0
    }

    /// Get list of indexed document IDs
    public func indexedDocumentIds() async -> Set<String> {
        await vectorStore.documentIds
    }
}

//
//  VectorStore.swift
//  TwinAct Field Companion
//
//  Local vector store for document embeddings and similarity search.
//

import Foundation
import os.log

// MARK: - Search Result

/// Result from a vector similarity search
public struct SearchResult: Identifiable, Sendable {
    /// Unique identifier for the result
    public var id: UUID { chunk.id }

    /// The matching document chunk
    public let chunk: DocumentChunk

    /// Similarity score (0.0 to 1.0, higher is more similar)
    public let score: Float

    /// Rank in the search results (1-indexed)
    public let rank: Int

    public init(chunk: DocumentChunk, score: Float, rank: Int = 0) {
        self.chunk = chunk
        self.score = score
        self.rank = rank
    }
}

// MARK: - Vector Store Errors

/// Errors that can occur during vector store operations
public enum VectorStoreError: Error, LocalizedError {
    case chunkNotFound(id: UUID)
    case documentNotFound(id: String)
    case embeddingMissing(chunkId: UUID)
    case dimensionMismatch(expected: Int, got: Int)
    case storageError(underlying: Error)

    public var errorDescription: String? {
        switch self {
        case .chunkNotFound(let id):
            return "Chunk not found: \(id)"
        case .documentNotFound(let id):
            return "Document not found: \(id)"
        case .embeddingMissing(let chunkId):
            return "Embedding missing for chunk: \(chunkId)"
        case .dimensionMismatch(let expected, let got):
            return "Embedding dimension mismatch: expected \(expected), got \(got)"
        case .storageError(let underlying):
            return "Storage error: \(underlying.localizedDescription)"
        }
    }
}

// MARK: - Vector Store Protocol

/// Protocol for vector stores
public protocol VectorStoreProtocol: Actor {
    /// Add chunks to the store
    func addChunks(_ chunks: [DocumentChunk]) async throws

    /// Remove chunks for a document
    func removeDocument(_ documentId: String) async

    /// Search for similar chunks
    func search(queryEmbedding: [Float], topK: Int) async -> [SearchResult]

    /// Get total number of chunks
    var chunkCount: Int { get async }

    /// Get all indexed document IDs
    var documentIds: Set<String> { get async }
}

// MARK: - In-Memory Vector Store

/// Local in-memory vector store for document embeddings
public actor VectorStore: VectorStoreProtocol {

    // MARK: - Properties

    /// All stored chunks indexed by ID
    private var chunksById: [UUID: DocumentChunk] = [:]

    /// Chunk IDs organized by document ID for efficient removal
    private var chunkIdsByDocument: [String: Set<UUID>] = [:]

    /// Precomputed embedding index for fast lookup
    private var embeddingIndex: [UUID: [Float]] = [:]

    /// Expected embedding dimension (set from first chunk)
    private var embeddingDimension: Int?

    private let logger: Logger

    // MARK: - Computed Properties

    /// Total number of chunks in the store
    public var chunkCount: Int {
        chunksById.count
    }

    /// Set of all indexed document IDs
    public var documentIds: Set<String> {
        Set(chunkIdsByDocument.keys)
    }

    // MARK: - Initialization

    public init() {
        self.logger = Logger(
            subsystem: AppConfiguration.AppInfo.bundleIdentifier,
            category: "VectorStore"
        )
    }

    // MARK: - Add Chunks

    /// Add indexed chunks to the store
    /// - Parameter newChunks: Chunks with embeddings to add
    public func addChunks(_ newChunks: [DocumentChunk]) async throws {
        for chunk in newChunks {
            guard let embedding = chunk.embedding else {
                logger.warning("Skipping chunk \(chunk.id) without embedding")
                continue
            }

            // Validate embedding dimension
            if let expectedDim = embeddingDimension {
                guard embedding.count == expectedDim else {
                    throw VectorStoreError.dimensionMismatch(
                        expected: expectedDim,
                        got: embedding.count
                    )
                }
            } else {
                embeddingDimension = embedding.count
                logger.info("Set embedding dimension to \(embedding.count)")
            }

            // Store chunk
            chunksById[chunk.id] = chunk
            embeddingIndex[chunk.id] = embedding

            // Track by document
            if chunkIdsByDocument[chunk.documentId] == nil {
                chunkIdsByDocument[chunk.documentId] = []
            }
            chunkIdsByDocument[chunk.documentId]?.insert(chunk.id)
        }

        logger.info("Added \(newChunks.count) chunks. Total: \(self.chunksById.count)")
    }

    /// Add a single chunk
    public func addChunk(_ chunk: DocumentChunk) async throws {
        try await addChunks([chunk])
    }

    // MARK: - Remove Chunks

    /// Remove all chunks for a document
    /// - Parameter documentId: ID of the document to remove
    public func removeDocument(_ documentId: String) async {
        guard let chunkIds = chunkIdsByDocument[documentId] else {
            logger.debug("No chunks found for document \(documentId)")
            return
        }

        for chunkId in chunkIds {
            chunksById.removeValue(forKey: chunkId)
            embeddingIndex.removeValue(forKey: chunkId)
        }

        chunkIdsByDocument.removeValue(forKey: documentId)
        logger.info("Removed \(chunkIds.count) chunks for document \(documentId)")
    }

    /// Remove a specific chunk
    public func removeChunk(_ chunkId: UUID) async {
        guard let chunk = chunksById[chunkId] else { return }

        chunksById.removeValue(forKey: chunkId)
        embeddingIndex.removeValue(forKey: chunkId)
        chunkIdsByDocument[chunk.documentId]?.remove(chunkId)

        // Clean up empty document entries
        if chunkIdsByDocument[chunk.documentId]?.isEmpty == true {
            chunkIdsByDocument.removeValue(forKey: chunk.documentId)
        }
    }

    /// Clear all chunks from the store
    public func clear() async {
        chunksById.removeAll()
        embeddingIndex.removeAll()
        chunkIdsByDocument.removeAll()
        embeddingDimension = nil
        logger.info("Cleared all chunks from store")
    }

    // MARK: - Search

    /// Search for similar chunks using cosine similarity
    /// - Parameters:
    ///   - queryEmbedding: Query vector
    ///   - topK: Maximum number of results to return
    /// - Returns: Array of search results sorted by similarity (highest first)
    public func search(queryEmbedding: [Float], topK: Int = 5) async -> [SearchResult] {
        guard !chunksById.isEmpty else {
            return []
        }

        // Validate query dimension
        if let expectedDim = embeddingDimension, queryEmbedding.count != expectedDim {
            logger.error("Query embedding dimension \(queryEmbedding.count) does not match store dimension \(expectedDim)")
            return []
        }

        // Compute similarities
        var results: [(chunk: DocumentChunk, score: Float)] = []
        results.reserveCapacity(chunksById.count)

        for (chunkId, chunk) in chunksById {
            guard let embedding = embeddingIndex[chunkId] else { continue }

            let similarity = cosineSimilarity(queryEmbedding, embedding)
            results.append((chunk, similarity))
        }

        // Sort by similarity (descending) and take top K
        let sortedResults = results
            .sorted { $0.score > $1.score }
            .prefix(topK)
            .enumerated()
            .map { SearchResult(chunk: $0.element.chunk, score: $0.element.score, rank: $0.offset + 1) }

        return Array(sortedResults)
    }

    /// Search for similar chunks with a minimum score threshold
    /// - Parameters:
    ///   - queryEmbedding: Query vector
    ///   - topK: Maximum number of results
    ///   - minScore: Minimum similarity score (0.0 to 1.0)
    /// - Returns: Array of search results meeting the threshold
    public func search(
        queryEmbedding: [Float],
        topK: Int = 5,
        minScore: Float = 0.0
    ) async -> [SearchResult] {
        let results = await search(queryEmbedding: queryEmbedding, topK: topK)
        return results.filter { $0.score >= minScore }
    }

    /// Search within specific documents only
    /// - Parameters:
    ///   - queryEmbedding: Query vector
    ///   - documentIds: Document IDs to search within
    ///   - topK: Maximum number of results
    /// - Returns: Array of search results
    public func search(
        queryEmbedding: [Float],
        withinDocuments documentIds: Set<String>,
        topK: Int = 5
    ) async -> [SearchResult] {
        guard !chunksById.isEmpty else {
            return []
        }

        var results: [(chunk: DocumentChunk, score: Float)] = []

        for documentId in documentIds {
            guard let chunkIds = chunkIdsByDocument[documentId] else { continue }

            for chunkId in chunkIds {
                guard let chunk = chunksById[chunkId],
                      let embedding = embeddingIndex[chunkId] else { continue }

                let similarity = cosineSimilarity(queryEmbedding, embedding)
                results.append((chunk, similarity))
            }
        }

        let sortedResults = results
            .sorted { $0.score > $1.score }
            .prefix(topK)
            .enumerated()
            .map { SearchResult(chunk: $0.element.chunk, score: $0.element.score, rank: $0.offset + 1) }

        return Array(sortedResults)
    }

    // MARK: - Retrieval

    /// Get a specific chunk by ID
    public func getChunk(_ id: UUID) async -> DocumentChunk? {
        chunksById[id]
    }

    /// Get all chunks for a document
    public func getChunks(forDocument documentId: String) async -> [DocumentChunk] {
        guard let chunkIds = chunkIdsByDocument[documentId] else {
            return []
        }
        return chunkIds.compactMap { chunksById[$0] }
            .sorted { $0.chunkIndex < $1.chunkIndex }
    }

    /// Check if a document has been indexed
    public func hasDocument(_ documentId: String) async -> Bool {
        chunkIdsByDocument[documentId] != nil
    }

    // MARK: - Similarity Computation

    /// Compute cosine similarity between two vectors
    private func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count else { return 0 }

        var dotProduct: Float = 0
        var normA: Float = 0
        var normB: Float = 0

        // SIMD-friendly loop (compiler can vectorize)
        for i in 0..<a.count {
            dotProduct += a[i] * b[i]
            normA += a[i] * a[i]
            normB += b[i] * b[i]
        }

        let denominator = sqrt(normA) * sqrt(normB)
        guard denominator > 0 else { return 0 }

        return dotProduct / denominator
    }

    // MARK: - Statistics

    /// Get statistics about the store
    public func getStatistics() async -> VectorStoreStatistics {
        VectorStoreStatistics(
            totalChunks: chunksById.count,
            totalDocuments: chunkIdsByDocument.count,
            embeddingDimension: embeddingDimension,
            documentsWithChunkCounts: chunkIdsByDocument.mapValues { $0.count }
        )
    }
}

// MARK: - Vector Store Statistics

/// Statistics about the vector store
public struct VectorStoreStatistics: Sendable {
    public let totalChunks: Int
    public let totalDocuments: Int
    public let embeddingDimension: Int?
    public let documentsWithChunkCounts: [String: Int]

    public var averageChunksPerDocument: Double {
        guard totalDocuments > 0 else { return 0 }
        return Double(totalChunks) / Double(totalDocuments)
    }
}

// MARK: - Persistent Vector Store

/// Vector store with persistence to disk
public actor PersistentVectorStore: VectorStoreProtocol {

    // MARK: - Properties

    private var memoryStore: VectorStore
    private let storageURL: URL
    private var isDirty: Bool = false
    private let logger: Logger

    public var chunkCount: Int {
        get async {
            await memoryStore.chunkCount
        }
    }

    public var documentIds: Set<String> {
        get async {
            await memoryStore.documentIds
        }
    }

    // MARK: - Initialization

    public init(storageURL: URL? = nil) {
        self.memoryStore = VectorStore()
        self.logger = Logger(
            subsystem: AppConfiguration.AppInfo.bundleIdentifier,
            category: "PersistentVectorStore"
        )

        if let url = storageURL {
            self.storageURL = url
        } else {
            let documentsPath = FileManager.default.urls(
                for: .documentDirectory,
                in: .userDomainMask
            ).first ?? FileManager.default.temporaryDirectory
            self.storageURL = documentsPath.appendingPathComponent("vectorstore.json")
        }
    }

    // MARK: - Public API

    public func addChunks(_ chunks: [DocumentChunk]) async throws {
        try await memoryStore.addChunks(chunks)
        isDirty = true
    }

    public func removeDocument(_ documentId: String) async {
        await memoryStore.removeDocument(documentId)
        isDirty = true
    }

    public func search(queryEmbedding: [Float], topK: Int) async -> [SearchResult] {
        await memoryStore.search(queryEmbedding: queryEmbedding, topK: topK)
    }

    // MARK: - Persistence

    /// Load the store from disk
    public func load() async throws {
        guard FileManager.default.fileExists(atPath: storageURL.path) else {
            logger.info("No existing store found at \(self.storageURL.path)")
            return
        }

        do {
            let data = try Data(contentsOf: storageURL)
            let chunks = try JSONDecoder().decode([DocumentChunk].self, from: data)
            try await memoryStore.addChunks(chunks)
            logger.info("Loaded \(chunks.count) chunks from disk")
        } catch {
            logger.error("Failed to load store: \(error.localizedDescription)")
            throw VectorStoreError.storageError(underlying: error)
        }
    }

    /// Save the store to disk
    public func save() async throws {
        guard isDirty else {
            logger.debug("Store not dirty, skipping save")
            return
        }

        do {
            // Collect all chunks
            var allChunks: [DocumentChunk] = []
            for documentId in await memoryStore.documentIds {
                let chunks = await memoryStore.getChunks(forDocument: documentId)
                allChunks.append(contentsOf: chunks)
            }

            let data = try JSONEncoder().encode(allChunks)
            try data.write(to: storageURL, options: .atomic)
            isDirty = false
            logger.info("Saved \(allChunks.count) chunks to disk")
        } catch {
            logger.error("Failed to save store: \(error.localizedDescription)")
            throw VectorStoreError.storageError(underlying: error)
        }
    }

    /// Clear the store and remove persisted data
    public func clearAndDelete() async throws {
        await memoryStore.clear()
        isDirty = false

        if FileManager.default.fileExists(atPath: storageURL.path) {
            try FileManager.default.removeItem(at: storageURL)
            logger.info("Deleted store file")
        }
    }
}

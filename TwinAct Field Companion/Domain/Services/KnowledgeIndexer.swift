//
//  KnowledgeIndexer.swift
//  TwinAct Field Companion
//
//  Indexes bundled knowledge documents for RAG-based domain expertise.
//

import Foundation
import os.log

// Import types from other modules - these are in the same target so should be accessible
// VectorStore, EmbeddingModel, ChunkEmbedder, DocumentChunk are defined in Features/Chat/RAG/

// MARK: - Knowledge Document

/// A bundled knowledge document from the app resources
public struct KnowledgeDocument: Codable, Sendable {
    public let id: String
    public let title: String
    public let path: String
    public let category: String
    public let keywords: [String]
}

// MARK: - Knowledge Index

/// Index manifest for bundled knowledge documents
public struct KnowledgeIndex: Codable, Sendable {
    public let version: String
    public let lastUpdated: String
    public let description: String
    public let documents: [KnowledgeDocument]
}

// MARK: - Knowledge Indexer Errors

/// Errors during knowledge indexing
public enum KnowledgeIndexerError: Error, LocalizedError {
    case indexNotFound
    case documentNotFound(String)
    case parsingFailed(String)
    case embeddingFailed(String)

    public var errorDescription: String? {
        switch self {
        case .indexNotFound:
            return "Knowledge index.json not found in app bundle"
        case .documentNotFound(let path):
            return "Knowledge document not found: \(path)"
        case .parsingFailed(let reason):
            return "Failed to parse knowledge document: \(reason)"
        case .embeddingFailed(let reason):
            return "Failed to generate embeddings: \(reason)"
        }
    }
}

// MARK: - Knowledge Indexer

/// Indexes bundled knowledge documents for AI Chat RAG
public actor KnowledgeIndexer {

    // MARK: - Properties

    private let vectorStore: VectorStore
    private let embeddingModel: EmbeddingModel
    private let chunkEmbedder: ChunkEmbedder
    private let logger: Logger

    /// Prefix for knowledge document IDs to distinguish from asset documents
    public static let knowledgeDocumentPrefix = "knowledge_"

    /// Whether knowledge has been indexed
    private var isIndexed: Bool = false

    /// Number of indexed chunks
    private var indexedChunkCount: Int = 0

    // MARK: - Initialization

    /// Initialize knowledge indexer
    /// - Parameters:
    ///   - vectorStore: Shared vector store for embeddings
    ///   - embeddingModel: Model for generating embeddings
    public init(
        vectorStore: VectorStore,
        embeddingModel: EmbeddingModel = EmbeddingModel()
    ) {
        self.vectorStore = vectorStore
        self.embeddingModel = embeddingModel
        self.chunkEmbedder = ChunkEmbedder(embeddingModel: embeddingModel)
        self.logger = Logger(
            subsystem: AppConfiguration.AppInfo.bundleIdentifier,
            category: "KnowledgeIndexer"
        )
    }

    // MARK: - Public API

    /// Index all bundled knowledge documents
    /// - Parameter forceReindex: If true, reindex even if already indexed
    /// - Returns: Number of chunks indexed
    @discardableResult
    public func indexBundledKnowledge(forceReindex: Bool = false) async throws -> Int {
        // Skip if already indexed (unless forced)
        if isIndexed && !forceReindex {
            logger.info("Knowledge already indexed (\(self.indexedChunkCount) chunks)")
            return indexedChunkCount
        }

        logger.info("Starting knowledge indexing...")

        // Load index manifest
        let index = try loadIndex()
        logger.info("Found \(index.documents.count) knowledge documents")

        var totalChunks = 0

        // Process each document
        for document in index.documents {
            do {
                let chunks = try await indexDocument(document)
                totalChunks += chunks
                logger.info("Indexed \(document.id): \(chunks) chunks")
            } catch {
                logger.error("Failed to index \(document.id): \(error.localizedDescription)")
                // Continue with other documents
            }
        }

        isIndexed = true
        indexedChunkCount = totalChunks

        logger.info("Knowledge indexing complete: \(totalChunks) total chunks")
        return totalChunks
    }

    /// Check if knowledge has been indexed
    public func hasIndexedKnowledge() -> Bool {
        isIndexed
    }

    /// Get indexed chunk count
    public func getIndexedChunkCount() -> Int {
        indexedChunkCount
    }

    /// Clear indexed knowledge from vector store
    public func clearKnowledge() async {
        let documentIds = await vectorStore.documentIds
        for docId in documentIds where docId.hasPrefix(Self.knowledgeDocumentPrefix) {
            await vectorStore.removeDocument(docId)
        }
        isIndexed = false
        indexedChunkCount = 0
        logger.info("Cleared knowledge from vector store")
    }

    // MARK: - Private Methods

    /// Load the knowledge index manifest
    private func loadIndex() throws -> KnowledgeIndex {
        // Try with subdirectory first (for structured bundles)
        if let indexURL = Bundle.main.url(
            forResource: "index",
            withExtension: "json",
            subdirectory: "Knowledge"
        ) {
            let data = try Data(contentsOf: indexURL)
            return try JSONDecoder().decode(KnowledgeIndex.self, from: data)
        }

        // Fall back to root bundle (Xcode flattens Resources in some cases)
        guard let indexURL = Bundle.main.url(
            forResource: "index",
            withExtension: "json"
        ) else {
            throw KnowledgeIndexerError.indexNotFound
        }

        let data = try Data(contentsOf: indexURL)
        return try JSONDecoder().decode(KnowledgeIndex.self, from: data)
    }

    /// Index a single knowledge document
    private func indexDocument(_ document: KnowledgeDocument) async throws -> Int {
        // Extract filename from path (e.g., "aas/aas-overview.md" -> "aas-overview")
        let pathComponents = document.path.split(separator: "/")
        let filename = String(pathComponents.last ?? "")
        let name = filename.replacingOccurrences(of: ".md", with: "")
        let subdirectory = pathComponents.dropLast().joined(separator: "/")

        // Try with Knowledge subdirectory first
        var fileURL = Bundle.main.url(
            forResource: name,
            withExtension: "md",
            subdirectory: "Knowledge/\(subdirectory)"
        )

        // Fall back to root bundle if not found (Xcode may flatten)
        if fileURL == nil {
            fileURL = Bundle.main.url(
                forResource: name,
                withExtension: "md"
            )
        }

        guard let resolvedURL = fileURL else {
            throw KnowledgeIndexerError.documentNotFound(document.path)
        }

        // Read markdown content
        let content = try String(contentsOf: resolvedURL, encoding: .utf8)

        // Parse and chunk markdown
        let chunks = parseMarkdown(
            content,
            documentId: Self.knowledgeDocumentPrefix + document.id,
            documentTitle: document.title
        )

        guard !chunks.isEmpty else {
            throw KnowledgeIndexerError.parsingFailed("No content extracted")
        }

        // Generate embeddings
        let embeddedChunks = try await chunkEmbedder.embedChunks(chunks)

        // Add to vector store
        try await vectorStore.addChunks(embeddedChunks)

        return embeddedChunks.count
    }

    /// Parse markdown into chunks by headers and paragraphs
    private func parseMarkdown(
        _ content: String,
        documentId: String,
        documentTitle: String
    ) -> [DocumentChunk] {
        var chunks: [DocumentChunk] = []
        var chunkIndex = 0

        // Split by headers (## and ###)
        let sections = splitByHeaders(content)

        for section in sections {
            let sectionTitle = section.title
            let sectionContent = section.content.trimmingCharacters(in: .whitespacesAndNewlines)

            // Skip empty sections
            guard !sectionContent.isEmpty else { continue }

            // If section is small enough, keep as single chunk
            if estimateTokens(sectionContent) <= 400 {
                chunks.append(DocumentChunk(
                    documentId: documentId,
                    documentTitle: documentTitle,
                    text: formatChunkText(title: sectionTitle, content: sectionContent),
                    sectionTitle: sectionTitle,
                    chunkIndex: chunkIndex,
                    startOffset: section.startOffset
                ))
                chunkIndex += 1
            } else {
                // Split large sections by paragraphs
                let paragraphs = sectionContent.components(separatedBy: "\n\n")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }

                var currentChunkParagraphs: [String] = []
                var currentTokens = 0

                for paragraph in paragraphs {
                    let paragraphTokens = estimateTokens(paragraph)

                    if currentTokens + paragraphTokens > 400 && !currentChunkParagraphs.isEmpty {
                        // Create chunk from accumulated paragraphs
                        let chunkContent = currentChunkParagraphs.joined(separator: "\n\n")
                        chunks.append(DocumentChunk(
                            documentId: documentId,
                            documentTitle: documentTitle,
                            text: formatChunkText(title: sectionTitle, content: chunkContent),
                            sectionTitle: sectionTitle,
                            chunkIndex: chunkIndex,
                            startOffset: section.startOffset
                        ))
                        chunkIndex += 1
                        currentChunkParagraphs = []
                        currentTokens = 0
                    }

                    currentChunkParagraphs.append(paragraph)
                    currentTokens += paragraphTokens
                }

                // Add remaining paragraphs
                if !currentChunkParagraphs.isEmpty {
                    let chunkContent = currentChunkParagraphs.joined(separator: "\n\n")
                    chunks.append(DocumentChunk(
                        documentId: documentId,
                        documentTitle: documentTitle,
                        text: formatChunkText(title: sectionTitle, content: chunkContent),
                        sectionTitle: sectionTitle,
                        chunkIndex: chunkIndex,
                        startOffset: section.startOffset
                    ))
                    chunkIndex += 1
                }
            }
        }

        return chunks
    }

    /// Split markdown by header levels
    private func splitByHeaders(_ content: String) -> [(title: String?, content: String, startOffset: Int)] {
        var sections: [(title: String?, content: String, startOffset: Int)] = []

        // Regex for markdown headers (## or ###)
        let headerPattern = #"^(#{1,3})\s+(.+)$"#
        let lines = content.components(separatedBy: .newlines)

        var currentTitle: String? = nil
        var currentContent: [String] = []
        var currentStartOffset = 0
        var offset = 0

        for line in lines {
            if let match = line.range(of: headerPattern, options: .regularExpression) {
                // Save previous section
                if !currentContent.isEmpty || currentTitle != nil {
                    sections.append((
                        title: currentTitle,
                        content: currentContent.joined(separator: "\n"),
                        startOffset: currentStartOffset
                    ))
                }

                // Extract header text (remove # symbols)
                let headerLine = String(line[match])
                let title = headerLine.replacingOccurrences(of: #"^#+\s*"#, with: "", options: .regularExpression)

                currentTitle = title
                currentContent = []
                currentStartOffset = offset
            } else {
                currentContent.append(line)
            }
            offset += line.count + 1 // +1 for newline
        }

        // Add final section
        if !currentContent.isEmpty || currentTitle != nil {
            sections.append((
                title: currentTitle,
                content: currentContent.joined(separator: "\n"),
                startOffset: currentStartOffset
            ))
        }

        return sections
    }

    /// Estimate token count (roughly words * 1.3)
    private func estimateTokens(_ text: String) -> Int {
        let words = text.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .count
        return Int(Double(words) * 1.3)
    }

    /// Format chunk text with optional section title
    private func formatChunkText(title: String?, content: String) -> String {
        if let title = title {
            return "\(title)\n\n\(content)"
        }
        return content
    }
}

// MARK: - Knowledge Chunk Identification

extension DocumentChunk {
    /// Whether this chunk is from bundled knowledge (vs. asset documentation)
    public var isKnowledgeChunk: Bool {
        documentId.hasPrefix(KnowledgeIndexer.knowledgeDocumentPrefix)
    }

    /// Get display source label
    public var sourceLabel: String {
        if isKnowledgeChunk {
            return "Reference: \(documentTitle)"
        }
        return "Asset Doc: \(documentTitle)"
    }
}

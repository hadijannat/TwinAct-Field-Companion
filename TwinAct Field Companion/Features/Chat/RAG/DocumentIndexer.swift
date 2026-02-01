//
//  DocumentIndexer.swift
//  TwinAct Field Companion
//
//  Extracts text from PDFs and chunks for RAG embedding.
//

import Foundation
import PDFKit
import NaturalLanguage
import os.log

// MARK: - Indexer Errors

/// Errors that can occur during document indexing
public enum IndexerError: Error, LocalizedError {
    case cannotOpenPDF
    case noTextExtracted
    case invalidDocument
    case chunkingFailed(reason: String)

    public var errorDescription: String? {
        switch self {
        case .cannotOpenPDF:
            return "Unable to open PDF document"
        case .noTextExtracted:
            return "No text could be extracted from the document"
        case .invalidDocument:
            return "Invalid document format"
        case .chunkingFailed(let reason):
            return "Chunking failed: \(reason)"
        }
    }
}

// MARK: - Document Chunk

/// A chunk of text from a document with metadata
public struct DocumentChunk: Codable, Identifiable, Sendable, Hashable {
    /// Unique chunk identifier
    public let id: UUID

    /// ID of the source document
    public let documentId: String

    /// Document title for display
    public let documentTitle: String

    /// The chunk text content
    public let text: String

    /// Page number in the source document (1-indexed)
    public let pageNumber: Int?

    /// Section or heading title if detected
    public let sectionTitle: String?

    /// Position within the document (0-indexed chunk number)
    public let chunkIndex: Int

    /// Character offset in original document
    public let startOffset: Int

    /// Vector embedding (set after embedding generation)
    public var embedding: [Float]?

    public init(
        id: UUID = UUID(),
        documentId: String,
        documentTitle: String,
        text: String,
        pageNumber: Int? = nil,
        sectionTitle: String? = nil,
        chunkIndex: Int,
        startOffset: Int,
        embedding: [Float]? = nil
    ) {
        self.id = id
        self.documentId = documentId
        self.documentTitle = documentTitle
        self.text = text
        self.pageNumber = pageNumber
        self.sectionTitle = sectionTitle
        self.chunkIndex = chunkIndex
        self.startOffset = startOffset
        self.embedding = embedding
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public static func == (lhs: DocumentChunk, rhs: DocumentChunk) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Chunk Configuration

/// Configuration for document chunking
public struct ChunkConfig: Sendable {
    /// Maximum chunk size in approximate tokens (words * 1.3)
    public var maxChunkSize: Int

    /// Number of tokens to overlap between consecutive chunks
    public var overlapSize: Int

    /// Minimum viable chunk size in tokens
    public var minChunkSize: Int

    /// Whether to detect and preserve section boundaries
    public var preserveSectionBoundaries: Bool

    /// Whether to include page numbers in chunk metadata
    public var trackPageNumbers: Bool

    public init(
        maxChunkSize: Int = 512,
        overlapSize: Int = 50,
        minChunkSize: Int = 100,
        preserveSectionBoundaries: Bool = true,
        trackPageNumbers: Bool = true
    ) {
        self.maxChunkSize = maxChunkSize
        self.overlapSize = overlapSize
        self.minChunkSize = minChunkSize
        self.preserveSectionBoundaries = preserveSectionBoundaries
        self.trackPageNumbers = trackPageNumbers
    }

    /// Default configuration for technical documentation
    public static let `default` = ChunkConfig()

    /// Smaller chunks for more precise retrieval
    public static let precise = ChunkConfig(
        maxChunkSize: 256,
        overlapSize: 30,
        minChunkSize: 50
    )

    /// Larger chunks for more context
    public static let contextual = ChunkConfig(
        maxChunkSize: 1024,
        overlapSize: 100,
        minChunkSize: 200
    )
}

// MARK: - Page Text Info

/// Text content from a single PDF page
private struct PageTextInfo {
    let pageNumber: Int
    let text: String
    let startOffset: Int
}

// MARK: - Document Indexer

/// Extracts text from PDFs and chunks for embedding
public struct DocumentIndexer: Sendable {

    private static let logger = Logger(
        subsystem: AppConfiguration.AppInfo.bundleIdentifier,
        category: "DocumentIndexer"
    )

    // MARK: - Public API

    /// Index a document from a URL into chunks
    /// - Parameters:
    ///   - url: URL to the PDF document
    ///   - documentId: Unique identifier for the document
    ///   - documentTitle: Display title for the document
    ///   - config: Chunking configuration
    /// - Returns: Array of document chunks ready for embedding
    public static func indexDocument(
        at url: URL,
        documentId: String,
        documentTitle: String,
        config: ChunkConfig = .default
    ) throws -> [DocumentChunk] {
        logger.info("Indexing document: \(documentTitle) from \(url.lastPathComponent)")

        // Extract text from PDF
        let pageTexts = try extractTextByPage(from: url)

        guard !pageTexts.isEmpty else {
            throw IndexerError.noTextExtracted
        }

        // Combine all text for chunking
        let fullText = pageTexts.map { $0.text }.joined(separator: "\n\n")

        // Create chunks with overlap
        let chunks = createChunks(
            from: fullText,
            pageTexts: pageTexts,
            documentId: documentId,
            documentTitle: documentTitle,
            config: config
        )

        logger.info("Created \(chunks.count) chunks from \(documentTitle)")

        return chunks
    }

    /// Index a Document model (from HandoverDocumentation) into chunks
    /// - Parameters:
    ///   - document: The Document model to index
    ///   - config: Chunking configuration
    /// - Returns: Array of document chunks ready for embedding
    public static func indexDocument(
        _ document: Document,
        config: ChunkConfig = .default
    ) async throws -> [DocumentChunk] {
        // Get the first PDF file from the document
        guard let digitalFile = document.digitalFile?.first(where: { $0.isPDF }) else {
            throw IndexerError.invalidDocument
        }

        let documentTitle = document.title.first?.text ?? document.id

        // Download or access the file
        let fileURL = digitalFile.file

        return try indexDocument(
            at: fileURL,
            documentId: document.id,
            documentTitle: documentTitle,
            config: config
        )
    }

    // MARK: - Text Extraction

    /// Extract text from PDF with page tracking
    private static func extractTextByPage(from url: URL) throws -> [PageTextInfo] {
        guard let pdf = PDFDocument(url: url) else {
            logger.error("Cannot open PDF at \(url.path)")
            throw IndexerError.cannotOpenPDF
        }

        var pageTexts: [PageTextInfo] = []
        var currentOffset = 0

        for pageIndex in 0..<pdf.pageCount {
            guard let page = pdf.page(at: pageIndex) else { continue }

            let pageText = page.string ?? ""
            let cleanedText = cleanText(pageText)

            if !cleanedText.isEmpty {
                pageTexts.append(PageTextInfo(
                    pageNumber: pageIndex + 1,  // 1-indexed
                    text: cleanedText,
                    startOffset: currentOffset
                ))
                currentOffset += cleanedText.count + 2  // +2 for paragraph separator
            }
        }

        return pageTexts
    }

    /// Extract text from PDF (simple version)
    public static func extractText(from url: URL) throws -> String {
        guard let pdf = PDFDocument(url: url) else {
            throw IndexerError.cannotOpenPDF
        }

        var fullText = ""
        for pageIndex in 0..<pdf.pageCount {
            if let page = pdf.page(at: pageIndex), let content = page.string {
                fullText += content + "\n\n"
            }
        }

        return cleanText(fullText)
    }

    // MARK: - Text Cleaning

    /// Clean extracted text
    private static func cleanText(_ text: String) -> String {
        var cleaned = text

        // Normalize whitespace
        cleaned = cleaned.replacingOccurrences(
            of: "[ \\t]+",
            with: " ",
            options: .regularExpression
        )

        // Normalize line breaks
        cleaned = cleaned.replacingOccurrences(
            of: "\\n{3,}",
            with: "\n\n",
            options: .regularExpression
        )

        // Remove page number patterns
        cleaned = cleaned.replacingOccurrences(
            of: "\\n\\s*\\d+\\s*\\n",
            with: "\n",
            options: .regularExpression
        )

        // Trim
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)

        return cleaned
    }

    // MARK: - Chunking

    /// Create chunks from text with overlap
    private static func createChunks(
        from text: String,
        pageTexts: [PageTextInfo],
        documentId: String,
        documentTitle: String,
        config: ChunkConfig
    ) -> [DocumentChunk] {
        // Split into sentences using NaturalLanguage
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text

        var sentences: [(text: String, range: Range<String.Index>)] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let sentence = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !sentence.isEmpty {
                sentences.append((sentence, range))
            }
            return true
        }

        // If no sentences detected, fall back to paragraph chunking
        if sentences.isEmpty {
            return createParagraphChunks(
                from: text,
                pageTexts: pageTexts,
                documentId: documentId,
                documentTitle: documentTitle,
                config: config
            )
        }

        var chunks: [DocumentChunk] = []
        var currentChunkSentences: [String] = []
        var currentTokenCount = 0
        var chunkIndex = 0
        var chunkStartOffset = 0

        for (index, sentenceInfo) in sentences.enumerated() {
            let sentenceTokens = estimateTokenCount(sentenceInfo.text)

            // Check if adding this sentence would exceed max size
            if currentTokenCount + sentenceTokens > config.maxChunkSize && !currentChunkSentences.isEmpty {
                // Create chunk from accumulated sentences
                let chunkText = currentChunkSentences.joined(separator: " ")
                let pageNumber = findPageNumber(for: chunkStartOffset, in: pageTexts)

                chunks.append(DocumentChunk(
                    documentId: documentId,
                    documentTitle: documentTitle,
                    text: chunkText,
                    pageNumber: pageNumber,
                    sectionTitle: detectSectionTitle(in: chunkText),
                    chunkIndex: chunkIndex,
                    startOffset: chunkStartOffset
                ))

                chunkIndex += 1

                // Calculate overlap - keep last few sentences
                let overlapSentenceCount = calculateOverlapSentenceCount(
                    sentences: currentChunkSentences,
                    targetTokens: config.overlapSize
                )

                if overlapSentenceCount > 0 {
                    currentChunkSentences = Array(currentChunkSentences.suffix(overlapSentenceCount))
                    currentTokenCount = currentChunkSentences.reduce(0) { $0 + estimateTokenCount($1) }
                } else {
                    currentChunkSentences = []
                    currentTokenCount = 0
                }

                // Update start offset for new chunk
                if let range = sentences[safe: index - overlapSentenceCount]?.range {
                    chunkStartOffset = text.distance(from: text.startIndex, to: range.lowerBound)
                }
            }

            currentChunkSentences.append(sentenceInfo.text)
            currentTokenCount += sentenceTokens

            if currentChunkSentences.count == 1 {
                chunkStartOffset = text.distance(from: text.startIndex, to: sentenceInfo.range.lowerBound)
            }
        }

        // Add final chunk if it meets minimum size
        if currentTokenCount >= config.minChunkSize {
            let chunkText = currentChunkSentences.joined(separator: " ")
            let pageNumber = findPageNumber(for: chunkStartOffset, in: pageTexts)

            chunks.append(DocumentChunk(
                documentId: documentId,
                documentTitle: documentTitle,
                text: chunkText,
                pageNumber: pageNumber,
                sectionTitle: detectSectionTitle(in: chunkText),
                chunkIndex: chunkIndex,
                startOffset: chunkStartOffset
            ))
        } else if !currentChunkSentences.isEmpty && !chunks.isEmpty {
            // Append remaining text to the last chunk
            let lastChunk = chunks.removeLast()
            let additionalText = currentChunkSentences.joined(separator: " ")
            chunks.append(DocumentChunk(
                id: lastChunk.id,
                documentId: lastChunk.documentId,
                documentTitle: lastChunk.documentTitle,
                text: lastChunk.text + " " + additionalText,
                pageNumber: lastChunk.pageNumber,
                sectionTitle: lastChunk.sectionTitle,
                chunkIndex: lastChunk.chunkIndex,
                startOffset: lastChunk.startOffset,
                embedding: lastChunk.embedding
            ))
        }

        return chunks
    }

    /// Fallback chunking by paragraphs
    private static func createParagraphChunks(
        from text: String,
        pageTexts: [PageTextInfo],
        documentId: String,
        documentTitle: String,
        config: ChunkConfig
    ) -> [DocumentChunk] {
        let paragraphs = text.components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var chunks: [DocumentChunk] = []
        var currentParagraphs: [String] = []
        var currentTokenCount = 0
        var chunkIndex = 0
        var currentOffset = 0

        for paragraph in paragraphs {
            let paragraphTokens = estimateTokenCount(paragraph)

            if currentTokenCount + paragraphTokens > config.maxChunkSize && !currentParagraphs.isEmpty {
                let chunkText = currentParagraphs.joined(separator: "\n\n")
                let pageNumber = findPageNumber(for: currentOffset, in: pageTexts)

                chunks.append(DocumentChunk(
                    documentId: documentId,
                    documentTitle: documentTitle,
                    text: chunkText,
                    pageNumber: pageNumber,
                    sectionTitle: detectSectionTitle(in: chunkText),
                    chunkIndex: chunkIndex,
                    startOffset: currentOffset
                ))

                chunkIndex += 1
                currentParagraphs = []
                currentTokenCount = 0
                currentOffset += chunkText.count + 2
            }

            currentParagraphs.append(paragraph)
            currentTokenCount += paragraphTokens
        }

        // Add remaining paragraphs
        if !currentParagraphs.isEmpty {
            let chunkText = currentParagraphs.joined(separator: "\n\n")
            let pageNumber = findPageNumber(for: currentOffset, in: pageTexts)

            chunks.append(DocumentChunk(
                documentId: documentId,
                documentTitle: documentTitle,
                text: chunkText,
                pageNumber: pageNumber,
                sectionTitle: detectSectionTitle(in: chunkText),
                chunkIndex: chunkIndex,
                startOffset: currentOffset
            ))
        }

        return chunks
    }

    // MARK: - Helper Methods

    /// Estimate token count (approximate: words * 1.3)
    private static func estimateTokenCount(_ text: String) -> Int {
        let words = text.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .count
        return Int(Double(words) * 1.3)
    }

    /// Calculate how many sentences to keep for overlap
    private static func calculateOverlapSentenceCount(sentences: [String], targetTokens: Int) -> Int {
        var tokenCount = 0
        var sentenceCount = 0

        for sentence in sentences.reversed() {
            let tokens = estimateTokenCount(sentence)
            if tokenCount + tokens > targetTokens {
                break
            }
            tokenCount += tokens
            sentenceCount += 1
        }

        return sentenceCount
    }

    /// Find the page number for a given character offset
    private static func findPageNumber(for offset: Int, in pageTexts: [PageTextInfo]) -> Int? {
        for (index, pageInfo) in pageTexts.enumerated() {
            let nextOffset = index + 1 < pageTexts.count ? pageTexts[index + 1].startOffset : Int.max
            if offset >= pageInfo.startOffset && offset < nextOffset {
                return pageInfo.pageNumber
            }
        }
        return pageTexts.first?.pageNumber
    }

    /// Detect section title from chunk text
    private static func detectSectionTitle(in text: String) -> String? {
        // Look for common heading patterns
        let lines = text.components(separatedBy: .newlines)

        for line in lines.prefix(3) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

            // Check for numbered heading (e.g., "1.2 Safety Instructions")
            if trimmed.range(of: "^\\d+(\\.\\d+)*\\s+[A-Z]", options: .regularExpression) != nil {
                return trimmed
            }

            // Check for all caps heading
            if trimmed.count < 60 && trimmed == trimmed.uppercased() && trimmed.count > 3 {
                return trimmed.capitalized
            }

            // Check for title case short line
            if trimmed.count < 50 && !trimmed.hasSuffix(".") && !trimmed.contains(":") {
                let words = trimmed.components(separatedBy: " ")
                let capitalizedWords = words.filter { $0.first?.isUppercase == true }
                if capitalizedWords.count == words.count && words.count > 1 {
                    return trimmed
                }
            }
        }

        return nil
    }
}

// MARK: - Array Safe Index Extension

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

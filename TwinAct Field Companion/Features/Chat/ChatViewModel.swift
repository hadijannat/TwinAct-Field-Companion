//
//  ChatViewModel.swift
//  TwinAct Field Companion
//
//  ViewModel for the Chat feature - manages state and coordinates RAG + inference.
//

import Foundation
import SwiftUI
import os.log
import Combine

// MARK: - Chat ViewModel

/// ViewModel for chat with AI assistant
@MainActor
public final class ChatViewModel: ObservableObject {

    // MARK: - Published State

    /// Current conversation messages
    @Published public var messages: [ChatMessage] = []

    /// User input text
    @Published public var inputText: String = ""

    /// Whether generation is in progress
    @Published public var isGenerating: Bool = false

    /// Current error (if any)
    @Published public var error: ChatError?

    /// Whether documents have been indexed
    @Published public var isIndexed: Bool = false

    /// Indexing progress (0.0 to 1.0)
    @Published public var indexingProgress: Double = 0

    /// Current routing strategy
    @Published public var routingStrategy: InferenceRoutingStrategy

    // MARK: - Private Properties

    private let contextRetriever: ContextRetriever
    private let inferenceRouter: InferenceRouter
    private let vectorStore: VectorStore
    private let embeddingModel: EmbeddingModel
    private let chunkEmbedder: ChunkEmbedder

    private let assetId: String?
    private let assetName: String?

    private var generationTask: Task<Void, Never>?
    private let logger: Logger

    // MARK: - Initialization

    /// Initialize chat view model
    /// - Parameters:
    ///   - assetId: Optional asset ID for context
    ///   - assetName: Optional asset name for display
    ///   - vectorStore: Shared vector store (optional)
    public init(
        assetId: String? = nil,
        assetName: String? = nil,
        vectorStore: VectorStore? = nil
    ) {
        self.assetId = assetId
        self.assetName = assetName

        // Initialize components
        let store = vectorStore ?? VectorStore()
        self.vectorStore = store
        self.embeddingModel = EmbeddingModel()
        self.chunkEmbedder = ChunkEmbedder(embeddingModel: embeddingModel)
        self.contextRetriever = ContextRetriever(
            vectorStore: store,
            embeddingModel: embeddingModel
        )
        self.inferenceRouter = InferenceRouter()
        self.routingStrategy = inferenceRouter.getStrategy()

        self.logger = Logger(
            subsystem: AppConfiguration.AppInfo.bundleIdentifier,
            category: "ChatViewModel"
        )

        // Add welcome message
        addWelcomeMessage()
    }

    /// Initialize with dependency injection for testing
    public init(
        contextRetriever: ContextRetriever,
        inferenceRouter: InferenceRouter,
        assetId: String? = nil,
        assetName: String? = nil
    ) {
        self.contextRetriever = contextRetriever
        self.inferenceRouter = inferenceRouter
        self.assetId = assetId
        self.assetName = assetName

        self.vectorStore = VectorStore()
        self.embeddingModel = EmbeddingModel()
        self.chunkEmbedder = ChunkEmbedder(embeddingModel: embeddingModel)
        self.routingStrategy = inferenceRouter.getStrategy()

        self.logger = Logger(
            subsystem: AppConfiguration.AppInfo.bundleIdentifier,
            category: "ChatViewModel"
        )

        addWelcomeMessage()
    }

    // MARK: - Public Methods

    /// Send a message and generate response
    public func sendMessage() async {
        let userInput = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !userInput.isEmpty else { return }

        // Clear input
        inputText = ""
        error = nil

        // Add user message
        let userMessage = ChatMessage.user(userInput)
        messages.append(userMessage)

        // Add streaming placeholder
        let placeholderId = UUID()
        var assistantMessage = ChatMessage(
            id: placeholderId,
            role: .assistant,
            content: "",
            isStreaming: true
        )
        messages.append(assistantMessage)

        isGenerating = true

        // Create cancellable task
        generationTask = Task {
            defer {
                Task { @MainActor in
                    isGenerating = false
                    generationTask = nil
                }
            }

            do {
                // 1. Retrieve relevant context
                let context = await contextRetriever.retrieveContext(for: userInput)

                // 2. Build prompt with context
                let prompt = contextRetriever.buildPromptWithContext(
                    question: userInput,
                    context: context,
                    assetName: assetName
                )

                // 3. Generate response
                let result = try await inferenceRouter.generate(
                    prompt: prompt,
                    options: .factual
                )

                // Check for cancellation
                try Task.checkCancellation()

                // 4. Create final message
                let finalMessage = assistantMessage.finalized(
                    content: result.text,
                    sources: context.isEmpty ? nil : context.sourceDocumentIds,
                    sourceTitles: context.isEmpty ? nil : context.sourceDocumentTitles,
                    metadata: .init(
                        provider: result.provider,
                        duration: result.duration,
                        promptTokens: result.promptTokens,
                        completionTokens: result.completionTokens,
                        wasTruncated: result.wasTruncated,
                        contextScore: context.averageScore
                    )
                )

                // Update message
                Task { @MainActor in
                    updateMessage(id: placeholderId, with: finalMessage)
                }

                logger.info("Generated response with \(result.completionTokens ?? 0) tokens via \(result.provider.rawValue)")

            } catch is CancellationError {
                // Remove placeholder on cancellation
                Task { @MainActor in
                    removeMessage(id: placeholderId)
                }
            } catch let inferenceError as InferenceError {
                logger.error("Inference error: \(inferenceError.localizedDescription)")
                Task { @MainActor in
                    let errorMessage = ChatMessage(
                        id: placeholderId,
                        role: .assistant,
                        content: "",
                        errorMessage: inferenceError.localizedDescription
                    )
                    updateMessage(id: placeholderId, with: errorMessage)
                    self.error = ChatError.inferenceFailed(inferenceError.localizedDescription)
                }
            } catch {
                logger.error("Unexpected error: \(error.localizedDescription)")
                Task { @MainActor in
                    let errorMessage = ChatMessage(
                        id: placeholderId,
                        role: .assistant,
                        content: "",
                        errorMessage: error.localizedDescription
                    )
                    updateMessage(id: placeholderId, with: errorMessage)
                    self.error = ChatError.unknown(error.localizedDescription)
                }
            }
        }
    }

    /// Cancel ongoing generation
    public func cancelGeneration() {
        generationTask?.cancel()
        generationTask = nil
        isGenerating = false
    }

    /// Index documents for RAG
    /// - Parameter documents: Documents to index
    public func indexDocuments(_ documents: [Document]) async {
        isIndexed = false
        indexingProgress = 0
        error = nil

        let total = Double(documents.count)

        for (index, document) in documents.enumerated() {
            do {
                // Extract and chunk document
                let chunks = try await DocumentIndexer.indexDocument(document)

                // Generate embeddings
                let embeddedChunks = try await chunkEmbedder.embedChunks(chunks) { progress in
                    // Sub-progress within document
                }

                // Add to vector store
                try await vectorStore.addChunks(embeddedChunks)

                // Update progress
                indexingProgress = Double(index + 1) / total

                logger.info("Indexed document: \(document.id) with \(embeddedChunks.count) chunks")

            } catch {
                logger.error("Failed to index document \(document.id): \(error.localizedDescription)")
                // Continue with other documents
            }
        }

        isIndexed = await vectorStore.chunkCount > 0
        indexingProgress = 1.0

        // Add system message about indexing
        let chunkCount = await vectorStore.chunkCount
        if chunkCount > 0 {
            messages.append(.system("Indexed \(documents.count) documents (\(chunkCount) chunks). Ready to answer questions."))
        }
    }

    /// Index a single document
    public func indexDocument(_ document: Document) async {
        await indexDocuments([document])
    }

    /// Clear conversation history
    public func clearConversation() {
        messages.removeAll()
        addWelcomeMessage()
        error = nil
    }

    /// Update routing strategy
    public func updateRoutingStrategy(_ strategy: InferenceRoutingStrategy) {
        inferenceRouter.setStrategy(strategy)
        routingStrategy = strategy
    }

    /// Get provider status
    public func getProviderStatus() async -> [InferenceProviderStatus] {
        await inferenceRouter.getProviderStatus()
    }

    // MARK: - Private Methods

    private func addWelcomeMessage() {
        let assetContext = assetName.map { " for \($0)" } ?? ""
        let welcomeText = """
        Hello! I'm your AI assistant\(assetContext). I can help answer questions about:

        - Operating procedures and maintenance
        - Troubleshooting and error codes
        - Technical specifications
        - Safety guidelines

        Ask me anything about the asset documentation.
        """
        messages.append(.assistant(welcomeText))
    }

    private func updateMessage(id: UUID, with newMessage: ChatMessage) {
        if let index = messages.firstIndex(where: { $0.id == id }) {
            messages[index] = newMessage
        }
    }

    private func removeMessage(id: UUID) {
        messages.removeAll { $0.id == id }
    }
}

// MARK: - Chat Error

/// Errors that can occur in the chat feature
public enum ChatError: Error, LocalizedError, Identifiable {
    case inferenceFailed(String)
    case indexingFailed(String)
    case noDocumentsIndexed
    case unknown(String)

    public var id: String {
        switch self {
        case .inferenceFailed(let msg): return "inference_\(msg)"
        case .indexingFailed(let msg): return "indexing_\(msg)"
        case .noDocumentsIndexed: return "no_documents"
        case .unknown(let msg): return "unknown_\(msg)"
        }
    }

    public var errorDescription: String? {
        switch self {
        case .inferenceFailed(let message):
            return "Generation failed: \(message)"
        case .indexingFailed(let message):
            return "Document indexing failed: \(message)"
        case .noDocumentsIndexed:
            return "No documents have been indexed. Please add documents first."
        case .unknown(let message):
            return message
        }
    }
}

// MARK: - Chat Settings

/// User-configurable chat settings
public struct ChatSettings: Codable, Sendable {
    /// Preferred routing strategy
    public var routingStrategy: String

    /// Whether to show source citations
    public var showSources: Bool

    /// Whether to show generation metadata
    public var showMetadata: Bool

    /// Maximum context chunks to retrieve
    public var maxContextChunks: Int

    public init(
        routingStrategy: String = InferenceRoutingStrategy.preferOnDevice.rawValue,
        showSources: Bool = true,
        showMetadata: Bool = false,
        maxContextChunks: Int = 5
    ) {
        self.routingStrategy = routingStrategy
        self.showSources = showSources
        self.showMetadata = showMetadata
        self.maxContextChunks = maxContextChunks
    }

    public static let `default` = ChatSettings()
}

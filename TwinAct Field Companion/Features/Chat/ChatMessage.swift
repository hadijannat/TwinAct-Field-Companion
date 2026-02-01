//
//  ChatMessage.swift
//  TwinAct Field Companion
//
//  Model for chat messages in the AI assistant conversation.
//

import Foundation

// MARK: - Chat Message

/// A single message in the chat conversation
public struct ChatMessage: Identifiable, Sendable, Hashable {

    // MARK: - Properties

    /// Unique message identifier
    public let id: UUID

    /// Message role (user, assistant, or system)
    public let role: Role

    /// Message text content
    public let content: String

    /// Timestamp when message was created
    public let timestamp: Date

    /// Source document IDs for RAG-grounded responses
    public var sources: [String]?

    /// Source document titles for display
    public var sourceTitles: [String]?

    /// Whether this message is still being generated
    public var isStreaming: Bool

    /// Error message if generation failed
    public var errorMessage: String?

    /// Metadata about the generation
    public var metadata: Metadata?

    // MARK: - Role

    /// Role of the message sender
    public enum Role: String, Sendable, CaseIterable {
        /// Message from the user
        case user

        /// Message from the AI assistant
        case assistant

        /// System message (instructions, errors, etc.)
        case system

        public var displayName: String {
            switch self {
            case .user: return "You"
            case .assistant: return "Assistant"
            case .system: return "System"
            }
        }
    }

    // MARK: - Metadata

    /// Metadata about message generation
    public struct Metadata: Sendable, Hashable {
        /// Provider used for generation
        public let provider: InferenceProviderType?

        /// Time taken for generation (seconds)
        public let duration: TimeInterval?

        /// Number of tokens in prompt
        public let promptTokens: Int?

        /// Number of tokens generated
        public let completionTokens: Int?

        /// Whether response was truncated
        public let wasTruncated: Bool

        /// Relevance score of retrieved context
        public let contextScore: Float?

        public init(
            provider: InferenceProviderType? = nil,
            duration: TimeInterval? = nil,
            promptTokens: Int? = nil,
            completionTokens: Int? = nil,
            wasTruncated: Bool = false,
            contextScore: Float? = nil
        ) {
            self.provider = provider
            self.duration = duration
            self.promptTokens = promptTokens
            self.completionTokens = completionTokens
            self.wasTruncated = wasTruncated
            self.contextScore = contextScore
        }
    }

    // MARK: - Initialization

    public init(
        id: UUID = UUID(),
        role: Role,
        content: String,
        timestamp: Date = Date(),
        sources: [String]? = nil,
        sourceTitles: [String]? = nil,
        isStreaming: Bool = false,
        errorMessage: String? = nil,
        metadata: Metadata? = nil
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.sources = sources
        self.sourceTitles = sourceTitles
        self.isStreaming = isStreaming
        self.errorMessage = errorMessage
        self.metadata = metadata
    }

    // MARK: - Factory Methods

    /// Create a user message
    public static func user(_ content: String) -> ChatMessage {
        ChatMessage(role: .user, content: content)
    }

    /// Create an assistant message
    public static func assistant(
        _ content: String,
        sources: [String]? = nil,
        sourceTitles: [String]? = nil,
        metadata: Metadata? = nil
    ) -> ChatMessage {
        ChatMessage(
            role: .assistant,
            content: content,
            sources: sources,
            sourceTitles: sourceTitles,
            metadata: metadata
        )
    }

    /// Create a system message
    public static func system(_ content: String) -> ChatMessage {
        ChatMessage(role: .system, content: content)
    }

    /// Create an error message
    public static func error(_ message: String) -> ChatMessage {
        ChatMessage(
            role: .system,
            content: "An error occurred.",
            errorMessage: message
        )
    }

    /// Create a placeholder message for streaming
    public static func streamingPlaceholder() -> ChatMessage {
        ChatMessage(
            role: .assistant,
            content: "",
            isStreaming: true
        )
    }

    // MARK: - Hashable

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(content)
        hasher.combine(isStreaming)
    }

    public static func == (lhs: ChatMessage, rhs: ChatMessage) -> Bool {
        lhs.id == rhs.id &&
        lhs.content == rhs.content &&
        lhs.isStreaming == rhs.isStreaming &&
        lhs.errorMessage == rhs.errorMessage
    }
}

// MARK: - ChatMessage Extensions

extension ChatMessage {

    /// Whether this message has source citations
    public var hasSources: Bool {
        !(sources?.isEmpty ?? true)
    }

    /// Whether this message has an error
    public var hasError: Bool {
        errorMessage != nil
    }

    /// Formatted timestamp
    public var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }

    /// Formatted duration if available
    public var formattedDuration: String? {
        guard let duration = metadata?.duration else { return nil }
        return String(format: "%.1fs", duration)
    }

    /// Create a copy with updated content (for streaming)
    public func withUpdatedContent(_ newContent: String, isStreaming: Bool = true) -> ChatMessage {
        ChatMessage(
            id: id,
            role: role,
            content: newContent,
            timestamp: timestamp,
            sources: sources,
            sourceTitles: sourceTitles,
            isStreaming: isStreaming,
            errorMessage: errorMessage,
            metadata: metadata
        )
    }

    /// Create a finalized copy (streaming complete)
    public func finalized(
        content: String? = nil,
        sources: [String]? = nil,
        sourceTitles: [String]? = nil,
        metadata: Metadata? = nil
    ) -> ChatMessage {
        ChatMessage(
            id: id,
            role: role,
            content: content ?? self.content,
            timestamp: timestamp,
            sources: sources ?? self.sources,
            sourceTitles: sourceTitles ?? self.sourceTitles,
            isStreaming: false,
            errorMessage: nil,
            metadata: metadata ?? self.metadata
        )
    }
}

// MARK: - Conversation

/// A collection of chat messages forming a conversation
public struct Conversation: Identifiable, Sendable {

    // MARK: - Properties

    /// Unique conversation identifier
    public let id: UUID

    /// Asset ID this conversation is about
    public let assetId: String?

    /// Asset name for display
    public let assetName: String?

    /// Messages in the conversation
    public var messages: [ChatMessage]

    /// When conversation was created
    public let createdAt: Date

    /// When conversation was last updated
    public var updatedAt: Date

    /// Conversation title (auto-generated from first user message)
    public var title: String?

    // MARK: - Initialization

    public init(
        id: UUID = UUID(),
        assetId: String? = nil,
        assetName: String? = nil,
        messages: [ChatMessage] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        title: String? = nil
    ) {
        self.id = id
        self.assetId = assetId
        self.assetName = assetName
        self.messages = messages
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.title = title
    }

    // MARK: - Computed Properties

    /// Auto-generated title from first user message
    public var autoTitle: String {
        if let explicitTitle = title {
            return explicitTitle
        }

        if let firstUserMessage = messages.first(where: { $0.role == .user }) {
            let preview = String(firstUserMessage.content.prefix(50))
            return preview.count < firstUserMessage.content.count ? "\(preview)..." : preview
        }

        return "New Conversation"
    }

    /// Number of messages
    public var messageCount: Int {
        messages.count
    }

    /// Last message in conversation
    public var lastMessage: ChatMessage? {
        messages.last
    }

    /// All user messages
    public var userMessages: [ChatMessage] {
        messages.filter { $0.role == .user }
    }

    /// All assistant messages
    public var assistantMessages: [ChatMessage] {
        messages.filter { $0.role == .assistant }
    }

    // MARK: - Mutating Methods

    /// Add a message to the conversation
    public mutating func addMessage(_ message: ChatMessage) {
        messages.append(message)
        updatedAt = Date()
    }

    /// Update the last message (for streaming)
    public mutating func updateLastMessage(_ updatedMessage: ChatMessage) {
        guard !messages.isEmpty else { return }
        messages[messages.count - 1] = updatedMessage
        updatedAt = Date()
    }

    /// Remove the last message
    public mutating func removeLastMessage() {
        guard !messages.isEmpty else { return }
        messages.removeLast()
        updatedAt = Date()
    }

    /// Clear all messages
    public mutating func clearMessages() {
        messages.removeAll()
        updatedAt = Date()
    }
}

// MARK: - Message History

/// Manages conversation history for context
public struct MessageHistory: Sendable {

    /// Maximum messages to include in context
    public let maxMessages: Int

    public init(maxMessages: Int = 10) {
        self.maxMessages = maxMessages
    }

    /// Get recent messages for context
    public func getRecentMessages(from conversation: Conversation) -> [(role: String, content: String)] {
        conversation.messages
            .filter { $0.role != .system }
            .suffix(maxMessages)
            .map { ($0.role.rawValue, $0.content) }
    }

    /// Estimate token count for messages
    public func estimateTokenCount(messages: [(role: String, content: String)]) -> Int {
        messages.reduce(0) { total, message in
            let words = message.content.components(separatedBy: .whitespacesAndNewlines)
                .filter { !$0.isEmpty }
                .count
            return total + Int(Double(words) * 1.3)
        }
    }
}

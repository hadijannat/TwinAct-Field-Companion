//
//  MessageBubble.swift
//  TwinAct Field Companion
//
//  Chat message bubble view component.
//

import SwiftUI

// MARK: - Message Bubble

/// Chat message bubble view
public struct MessageBubble: View {
    let message: ChatMessage
    var onSourceTapped: ((String) -> Void)?

    @Environment(\.colorScheme) private var colorScheme

    public init(
        message: ChatMessage,
        onSourceTapped: ((String) -> Void)? = nil
    ) {
        self.message = message
        self.onSourceTapped = onSourceTapped
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // Avatar for assistant/system messages
            if message.role != .user {
                avatarView
            }

            if message.role == .user {
                Spacer(minLength: 60)
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                // Message content
                contentView

                // Sources citation (for assistant messages)
                if message.role == .assistant && message.hasSources {
                    sourcesView
                }

                // Metadata (provider, timing)
                if let metadata = message.metadata, message.role == .assistant {
                    metadataView(metadata)
                }

                // Timestamp
                timestampView
            }

            if message.role != .user {
                Spacer(minLength: 60)
            }

            // Avatar for user messages
            if message.role == .user {
                avatarView
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }

    // MARK: - Avatar View

    private var avatarView: some View {
        ZStack {
            Circle()
                .fill(avatarBackgroundColor)
                .frame(width: 32, height: 32)

            Image(systemName: avatarIconName)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(avatarIconColor)
        }
    }

    private var avatarBackgroundColor: Color {
        switch message.role {
        case .user:
            return Color.accentColor.opacity(0.2)
        case .assistant:
            return Color.green.opacity(0.2)
        case .system:
            return Color.orange.opacity(0.2)
        }
    }

    private var avatarIconName: String {
        switch message.role {
        case .user:
            return "person.fill"
        case .assistant:
            return "cpu"
        case .system:
            return "info.circle.fill"
        }
    }

    private var avatarIconColor: Color {
        switch message.role {
        case .user:
            return .accentColor
        case .assistant:
            return .green
        case .system:
            return .orange
        }
    }

    // MARK: - Content View

    @ViewBuilder
    private var contentView: some View {
        if message.isStreaming && message.content.isEmpty {
            streamingIndicator
        } else if message.hasError {
            errorView
        } else {
            textBubble
        }
    }

    private var textBubble: some View {
        Text(message.content)
            .font(.body)
            .foregroundColor(textColor)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(bubbleBackgroundColor)
            .clipShape(BubbleShape(isFromUser: message.role == .user))
            .contextMenu {
                Button {
                    UIPasteboard.general.string = message.content
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
            }
    }

    private var streamingIndicator: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Color.secondary)
                    .frame(width: 8, height: 8)
                    .scaleEffect(streamingScale(for: index))
                    .animation(
                        .easeInOut(duration: 0.5)
                            .repeatForever()
                            .delay(Double(index) * 0.15),
                        value: message.isStreaming
                    )
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemBackground))
        .clipShape(BubbleShape(isFromUser: false))
    }

    private func streamingScale(for index: Int) -> CGFloat {
        message.isStreaming ? 1.2 : 1.0
    }

    private var errorView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                Text("Error")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.red)
            }

            if let errorMessage = message.errorMessage {
                Text(errorMessage)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.red.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var bubbleBackgroundColor: Color {
        switch message.role {
        case .user:
            return .accentColor
        case .assistant:
            return Color(.secondarySystemBackground)
        case .system:
            return Color.orange.opacity(0.1)
        }
    }

    private var textColor: Color {
        switch message.role {
        case .user:
            return .white
        case .assistant, .system:
            return .primary
        }
    }

    // MARK: - Sources View

    private var sourcesView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Sources:")
                .font(.caption2.weight(.semibold))
                .foregroundColor(.secondary)

            FlowLayout(spacing: 4) {
                ForEach(sourceItems, id: \.id) { source in
                    SourceChip(
                        title: source.title,
                        documentId: source.id
                    ) {
                        onSourceTapped?(source.id)
                    }
                }
            }
        }
        .padding(.top, 4)
    }

    private var sourceItems: [(id: String, title: String)] {
        guard let sources = message.sources else { return [] }
        let titles = message.sourceTitles ?? sources

        return zip(sources, titles).map { (id: $0, title: $1) }
    }

    // MARK: - Metadata View

    private func metadataView(_ metadata: ChatMessage.Metadata) -> some View {
        HStack(spacing: 8) {
            if let provider = metadata.provider {
                Label {
                    Text(provider.displayName)
                } icon: {
                    Image(systemName: provider == .onDevice ? "iphone" : "cloud")
                }
                .font(.caption2)
                .foregroundColor(.secondary)
            }

            if let duration = metadata.duration {
                Text(String(format: "%.1fs", duration))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            if metadata.wasTruncated {
                Label("Truncated", systemImage: "ellipsis.circle")
                    .font(.caption2)
                    .foregroundColor(.orange)
            }
        }
    }

    // MARK: - Timestamp View

    private var timestampView: some View {
        Text(message.formattedTime)
            .font(.caption2)
            .foregroundColor(.secondary)
    }
}

// MARK: - Bubble Shape

/// Custom shape for chat bubble with tail
struct BubbleShape: Shape {
    let isFromUser: Bool
    let cornerRadius: CGFloat = 16
    let tailSize: CGFloat = 6

    func path(in rect: CGRect) -> Path {
        var path = Path()

        if isFromUser {
            // User bubble (tail on right)
            path.addRoundedRect(
                in: CGRect(x: 0, y: 0, width: rect.width - tailSize, height: rect.height),
                cornerSize: CGSize(width: cornerRadius, height: cornerRadius)
            )
            // Tail
            path.move(to: CGPoint(x: rect.width - tailSize, y: rect.height - 20))
            path.addLine(to: CGPoint(x: rect.width, y: rect.height - 12))
            path.addLine(to: CGPoint(x: rect.width - tailSize, y: rect.height - 4))
        } else {
            // Assistant bubble (tail on left)
            path.addRoundedRect(
                in: CGRect(x: tailSize, y: 0, width: rect.width - tailSize, height: rect.height),
                cornerSize: CGSize(width: cornerRadius, height: cornerRadius)
            )
            // Tail
            path.move(to: CGPoint(x: tailSize, y: rect.height - 20))
            path.addLine(to: CGPoint(x: 0, y: rect.height - 12))
            path.addLine(to: CGPoint(x: tailSize, y: rect.height - 4))
        }

        return path
    }
}

// MARK: - Source Chip

/// Small chip showing a document source
struct SourceChip: View {
    let title: String
    let documentId: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                Image(systemName: "doc.text")
                    .font(.caption2)
                Text(title.prefix(20) + (title.count > 20 ? "..." : ""))
                    .font(.caption2)
                    .lineLimit(1)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.accentColor.opacity(0.1))
            .foregroundColor(.accentColor)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Flow Layout

/// Layout that wraps items to new lines
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )

        for (index, subview) in subviews.enumerated() {
            subview.place(
                at: CGPoint(
                    x: bounds.minX + result.positions[index].x,
                    y: bounds.minY + result.positions[index].y
                ),
                proposal: ProposedViewSize(result.sizes[index])
            )
        }
    }

    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []
        var sizes: [CGSize] = []

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                sizes.append(size)

                if currentX + size.width > maxWidth && currentX > 0 {
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }

                positions.append(CGPoint(x: currentX, y: currentY))
                lineHeight = max(lineHeight, size.height)
                currentX += size.width + spacing
                self.size.width = max(self.size.width, currentX - spacing)
            }

            self.size.height = currentY + lineHeight
        }
    }
}

// MARK: - Preview

#if DEBUG
struct MessageBubble_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            VStack(spacing: 16) {
                MessageBubble(message: .user("How do I calibrate the pressure sensor?"))

                MessageBubble(
                    message: .assistant(
                        "To calibrate the pressure sensor, follow these steps:\n\n1. Ensure the system is in standby mode\n2. Navigate to Settings > Calibration\n3. Select 'Pressure Sensor'\n4. Follow the on-screen prompts",
                        sources: ["DOC001", "DOC002"],
                        sourceTitles: ["Operating Manual", "Calibration Guide"],
                        metadata: .init(
                            provider: .onDevice,
                            duration: 1.2,
                            promptTokens: 150,
                            completionTokens: 85
                        )
                    )
                )

                MessageBubble(message: .streamingPlaceholder())

                MessageBubble(message: .error("Network connection lost"))
            }
            .padding()
        }
    }
}
#endif

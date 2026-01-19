//
//  ChatView.swift
//  TwinAct Field Companion
//
//  Main chat interface for "Chat with Asset" feature.
//

import SwiftUI

// MARK: - Chat View

/// Main chat interface for AI-assisted asset queries
public struct ChatView: View {

    // MARK: - Properties

    @StateObject private var viewModel: ChatViewModel
    @FocusState private var isInputFocused: Bool
    @State private var showSettings: Bool = false
    @State private var scrollToBottom: Bool = false

    private let assetId: String?
    private let assetName: String?

    // MARK: - Initialization

    public init(
        assetId: String? = nil,
        assetName: String? = nil
    ) {
        self.assetId = assetId
        self.assetName = assetName
        _viewModel = StateObject(wrappedValue: ChatViewModel(
            assetId: assetId,
            assetName: assetName
        ))
    }

    /// Initialize with a shared vector store
    public init(
        assetId: String? = nil,
        assetName: String? = nil,
        vectorStore: VectorStore
    ) {
        self.assetId = assetId
        self.assetName = assetName
        _viewModel = StateObject(wrappedValue: ChatViewModel(
            assetId: assetId,
            assetName: assetName,
            vectorStore: vectorStore
        ))
    }

    // MARK: - Body

    public var body: some View {
        VStack(spacing: 0) {
            // Status bar
            statusBar

            Divider()

            // Chat messages
            messagesScrollView

            Divider()

            // Input bar
            inputBar
        }
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    settingsMenu
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            ChatSettingsView(viewModel: viewModel)
        }
        .alert(item: $viewModel.error) { error in
            Alert(
                title: Text("Error"),
                message: Text(error.localizedDescription ?? "An error occurred"),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    // MARK: - Navigation Title

    private var navigationTitle: String {
        if let name = assetName {
            return "Chat: \(name)"
        }
        return "Chat with Asset"
    }

    // MARK: - Status Bar

    private var statusBar: some View {
        HStack(spacing: 12) {
            // Indexing status
            if viewModel.isIndexed {
                Label("Documents indexed", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.green)
            } else if viewModel.indexingProgress > 0 && viewModel.indexingProgress < 1 {
                HStack(spacing: 6) {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Indexing... \(Int(viewModel.indexingProgress * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                Label("No documents indexed", systemImage: "doc.questionmark")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Provider indicator
            providerIndicator
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }

    private var providerIndicator: some View {
        HStack(spacing: 4) {
            Image(systemName: providerIcon)
                .font(.caption)
            Text(viewModel.routingStrategy.displayName)
                .font(.caption)
        }
        .foregroundColor(.secondary)
    }

    private var providerIcon: String {
        switch viewModel.routingStrategy {
        case .preferOnDevice, .onDeviceOnly:
            return "iphone"
        case .preferCloud, .cloudOnly:
            return "cloud"
        case .adaptive:
            return "arrow.triangle.branch"
        }
    }

    // MARK: - Messages Scroll View

    private var messagesScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.messages) { message in
                        MessageBubble(message: message) { documentId in
                            // Handle source tap - could open document viewer
                            print("Tapped source: \(documentId)")
                        }
                        .id(message.id)
                    }
                }
                .padding(.vertical, 12)
            }
            .onChange(of: viewModel.messages.count) { _, _ in
                withAnimation(.easeOut(duration: 0.2)) {
                    if let lastMessage = viewModel.messages.last {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
            .onChange(of: scrollToBottom) { _, newValue in
                if newValue, let lastMessage = viewModel.messages.last {
                    proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    scrollToBottom = false
                }
            }
        }
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        VStack(spacing: 0) {
            HStack(alignment: .bottom, spacing: 12) {
                // Text input
                TextField("Ask about this asset...", text: $viewModel.inputText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .focused($isInputFocused)
                    .lineLimit(1...5)
                    .submitLabel(.send)
                    .onSubmit {
                        if !viewModel.inputText.isEmpty && !viewModel.isGenerating {
                            Task {
                                await viewModel.sendMessage()
                            }
                        }
                    }

                // Send/Stop button
                Button {
                    if viewModel.isGenerating {
                        viewModel.cancelGeneration()
                    } else {
                        Task {
                            await viewModel.sendMessage()
                        }
                    }
                } label: {
                    Image(systemName: viewModel.isGenerating ? "stop.fill" : "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(sendButtonColor)
                }
                .disabled(sendButtonDisabled)
                .animation(.easeInOut(duration: 0.2), value: viewModel.isGenerating)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(.systemBackground))
    }

    private var sendButtonColor: Color {
        if viewModel.isGenerating {
            return .red
        } else if viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .secondary
        } else {
            return .accentColor
        }
    }

    private var sendButtonDisabled: Bool {
        !viewModel.isGenerating &&
        viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Settings Menu

    @ViewBuilder
    private var settingsMenu: some View {
        // Routing strategy
        Menu {
            ForEach(InferenceRoutingStrategy.allCases, id: \.self) { strategy in
                Button {
                    viewModel.updateRoutingStrategy(strategy)
                } label: {
                    if strategy == viewModel.routingStrategy {
                        Label(strategy.displayName, systemImage: "checkmark")
                    } else {
                        Text(strategy.displayName)
                    }
                }
            }
        } label: {
            Label("Inference Mode", systemImage: "cpu")
        }

        Divider()

        // Clear conversation
        Button(role: .destructive) {
            viewModel.clearConversation()
        } label: {
            Label("Clear Conversation", systemImage: "trash")
        }

        // Settings
        Button {
            showSettings = true
        } label: {
            Label("Settings", systemImage: "gear")
        }
    }
}

// MARK: - Chat Settings View

/// Settings sheet for chat configuration
struct ChatSettingsView: View {
    @ObservedObject var viewModel: ChatViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var providerStatus: [InferenceProviderStatus] = []

    var body: some View {
        NavigationView {
            Form {
                // Provider Status
                Section("Provider Status") {
                    if providerStatus.isEmpty {
                        ProgressView("Loading...")
                    } else {
                        ForEach(providerStatus, id: \.providerType) { status in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(status.providerType.displayName)
                                        .font(.headline)
                                    if let model = status.modelName {
                                        Text(model)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }

                                Spacer()

                                Image(systemName: status.isAvailable ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundColor(status.isAvailable ? .green : .red)
                            }
                        }
                    }
                }

                // Routing Strategy
                Section("Inference Mode") {
                    Picker("Strategy", selection: $viewModel.routingStrategy) {
                        ForEach(InferenceRoutingStrategy.allCases, id: \.self) { strategy in
                            Text(strategy.displayName).tag(strategy)
                        }
                    }
                    .onChange(of: viewModel.routingStrategy) { _, newValue in
                        viewModel.updateRoutingStrategy(newValue)
                    }
                }

                // Information
                Section("About") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Privacy-First AI")
                            .font(.headline)
                        Text("On-device inference keeps your data private. Cloud inference provides higher quality responses when needed.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Chat Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .task {
                providerStatus = await viewModel.getProviderStatus()
            }
        }
    }
}

// MARK: - Quick Action Chips

/// Suggested action chips for common queries
struct QuickActionChips: View {
    let onSelect: (String) -> Void

    private let suggestions = [
        "How do I calibrate this?",
        "What are the safety procedures?",
        "Show maintenance schedule",
        "Troubleshoot error codes"
    ]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(suggestions, id: \.self) { suggestion in
                    Button {
                        onSelect(suggestion)
                    } label: {
                        Text(suggestion)
                            .font(.subheadline)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.accentColor.opacity(0.1))
                            .foregroundColor(.accentColor)
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }
}

// MARK: - Preview

#if DEBUG
struct ChatView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            ChatView(
                assetId: "demo-asset",
                assetName: "Hydraulic Press HP-4500"
            )
        }
    }
}
#endif

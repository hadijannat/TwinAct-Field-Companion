//
//  AIProviderSettingsView.swift
//  TwinAct Field Companion
//
//  Settings view for managing AI cloud providers.
//

import SwiftUI

// MARK: - AI Provider Settings View

/// Main settings view for AI cloud providers
struct AIProviderSettingsView: View {

    // MARK: - State

    /// Use ObservedObject since the manager is owned by DependencyContainer, not this view
    @ObservedObject private var providerManager: AIProviderManager
    /// Selected provider for sheet presentation - use with .sheet(item:) to avoid race conditions
    @State private var selectedProvider: AIProviderType?

    // MARK: - Initialization

    init() {
        self._providerManager = ObservedObject(wrappedValue: DependencyContainer.shared.aiProviderManager)
    }

    init(providerManager: AIProviderManager) {
        self._providerManager = ObservedObject(wrappedValue: providerManager)
    }

    // MARK: - Body

    var body: some View {
        List {
            // MARK: - Active Provider Section
            Section {
                Picker("Active Provider", selection: $providerManager.activeProviderType) {
                    ForEach(AIProviderType.allCases) { provider in
                        HStack {
                            Image(systemName: provider.iconName)
                                .foregroundColor(providerColor(for: provider))
                            Text(provider.displayName)
                        }
                        .tag(provider)
                    }
                }
            } header: {
                Text("Active Cloud Provider")
            } footer: {
                Text("Select which AI provider to use for cloud inference. On-device inference will be used as fallback when cloud is unavailable.")
            }

            // MARK: - Provider List Section
            Section {
                ForEach(AIProviderType.allCases) { provider in
                    ProviderRowView(
                        provider: provider,
                        configuration: providerManager.configuration(for: provider),
                        hasAPIKey: providerManager.hasAPIKey(for: provider),
                        connectionStatus: providerManager.connectionStatus[provider] ?? .unknown,
                        isActive: provider == providerManager.activeProviderType
                    ) {
                        selectedProvider = provider
                    }
                }
            } header: {
                Text("Configured Providers")
            } footer: {
                Text("Tap a provider to configure its API key, model, and other settings.")
            }

            // MARK: - Info Section
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Label {
                        Text("About Cloud Providers")
                            .font(.headline)
                    } icon: {
                        Image(systemName: "info.circle")
                    }

                    Text("Cloud providers offer higher quality responses and access to the latest AI models. API keys are stored securely in your device's Keychain.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Divider()

                    VStack(alignment: .leading, spacing: 4) {
                        providerInfo(icon: "brain.head.profile", name: "Anthropic", desc: "Claude models with strong reasoning")
                        providerInfo(icon: "sparkles", name: "OpenAI", desc: "GPT-4 and O1 models")
                        providerInfo(icon: "arrow.triangle.branch", name: "OpenRouter", desc: "Access to 100+ models")
                        providerInfo(icon: "desktopcomputer", name: "Ollama", desc: "Local models, no API key needed")
                        providerInfo(icon: "server.rack", name: "Custom", desc: "Your own API endpoint")
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("Cloud Providers")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedProvider) { provider in
            NavigationStack {
                ProviderConfigurationView(
                    provider: provider,
                    providerManager: providerManager
                )
            }
        }
    }

    // MARK: - Helper Views

    private func providerInfo(icon: String, name: String, desc: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .frame(width: 20)
                .foregroundColor(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.caption)
                    .fontWeight(.medium)
                Text(desc)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func providerColor(for provider: AIProviderType) -> Color {
        switch provider {
        case .anthropic:
            return .orange
        case .openai:
            return .green
        case .openRouter:
            return .purple
        case .ollama:
            return .blue
        case .custom:
            return .gray
        }
    }
}

// MARK: - Provider Row View

struct ProviderRowView: View {
    let provider: AIProviderType
    let configuration: AIProviderConfiguration
    let hasAPIKey: Bool
    let connectionStatus: AIProviderConnectionStatus
    let isActive: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Provider icon
                Image(systemName: provider.iconName)
                    .font(.title2)
                    .foregroundColor(isActive ? .blue : .secondary)
                    .frame(width: 32)

                // Provider info
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(provider.displayName)
                            .font(.body)
                            .foregroundColor(.primary)

                        if isActive {
                            Text("Active")
                                .font(.caption2)
                                .fontWeight(.medium)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.15))
                                .foregroundColor(.blue)
                                .cornerRadius(4)
                        }
                    }

                    HStack(spacing: 4) {
                        // Configuration status
                        if provider.requiresAPIKey {
                            Image(systemName: hasAPIKey ? "key.fill" : "key")
                                .font(.caption2)
                            Text(hasAPIKey ? "API Key Set" : "No API Key")
                                .font(.caption)
                        } else {
                            Image(systemName: "checkmark.circle")
                                .font(.caption2)
                            Text("No key required")
                                .font(.caption)
                        }
                    }
                    .foregroundColor(.secondary)
                }

                Spacer()

                // Connection status indicator
                connectionStatusView

                // Chevron
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var connectionStatusView: some View {
        switch connectionStatus {
        case .unknown:
            EmptyView()
        case .checking:
            ProgressView()
                .scaleEffect(0.8)
        case .connected:
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
        case .disconnected:
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundColor(.red)
        }
    }
}

// MARK: - Preview

#if DEBUG
struct AIProviderSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            AIProviderSettingsView()
        }
    }
}
#endif

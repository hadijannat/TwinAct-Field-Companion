//
//  ProviderConfigurationView.swift
//  TwinAct Field Companion
//
//  Configuration view for individual AI providers.
//

import SwiftUI

// MARK: - Provider Configuration View

/// View for configuring an individual AI provider
struct ProviderConfigurationView: View {

    // MARK: - Properties

    let provider: AIProviderType
    @ObservedObject var providerManager: AIProviderManager

    // MARK: - State

    @Environment(\.dismiss) private var dismiss

    @State private var apiKey: String = ""
    @State private var baseURL: String = ""
    @State private var modelId: String = ""
    @State private var timeout: Double = 60.0
    @State private var maxRetries: Int = 2
    @State private var isEnabled: Bool = true
    @State private var apiFormat: APIFormat = .openAICompatible

    @State private var isTesting: Bool = false
    @State private var testResult: TestResult?
    @State private var showDeleteConfirmation: Bool = false
    @State private var availableModels: [AIProviderModel] = []
    @State private var isLoadingModels: Bool = false

    private enum TestResult {
        case success
        case failure(String)
    }

    // MARK: - Body

    var body: some View {
        Form {
            // MARK: - API Key Section
            if provider.requiresAPIKey {
                Section {
                    SecureField("API Key", text: $apiKey)
                        .textContentType(.password)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)

                    if providerManager.hasAPIKey(for: provider) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("API key is saved")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Authentication")
                } footer: {
                    Text(apiKeyFooter)
                }
            }

            // MARK: - Endpoint Section
            Section {
                if allowsCustomEndpoint {
                    TextField("Base URL", text: $baseURL)
                        .textContentType(.URL)
                        .autocapitalization(.none)
                        .keyboardType(.URL)
                } else {
                    HStack {
                        Text("Endpoint")
                        Spacer()
                        Text(provider.defaultBaseURL?.host ?? "")
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Text("Endpoint")
            } footer: {
                if provider == .ollama {
                    Text("Default: http://localhost:11434. Change if running Ollama on a different machine.")
                } else if provider == .custom {
                    Text("Enter the base URL of your API endpoint (e.g., https://your-server.com/api)")
                } else if provider == .openRouter {
                    Text("Default: https://openrouter.ai/api. Do not include /v1 in the base URL.")
                }
            }

            // MARK: - Model Section
            Section {
                if availableModels.isEmpty {
                    // Manual model ID entry
                    TextField("Model ID", text: $modelId)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)

                    if isLoadingModels {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Loading models...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else if provider.supportsModelListing {
                        Button("Refresh Models") {
                            Task {
                                await loadModels()
                            }
                        }
                    }
                } else {
                    // Model picker
                    Picker("Model", selection: $modelId) {
                        ForEach(availableModels) { model in
                            VStack(alignment: .leading) {
                                Text(model.displayName)
                                Text("\(model.contextWindow / 1000)K context")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .tag(model.modelId)
                        }
                    }
                }
            } header: {
                Text("Model")
            } footer: {
                Text("Select or enter the model to use. \(defaultModelHint)")
            }

            // MARK: - Advanced Section
            Section {
                Toggle("Enabled", isOn: $isEnabled)

                Stepper("Timeout: \(Int(timeout))s", value: $timeout, in: 10...300, step: 10)

                Stepper("Max Retries: \(maxRetries)", value: $maxRetries, in: 0...5)

                if provider == .custom {
                    Picker("API Format", selection: $apiFormat) {
                        ForEach(APIFormat.allCases, id: \.self) { format in
                            Text(format.displayName).tag(format)
                        }
                    }
                }
            } header: {
                Text("Advanced")
            }

            // MARK: - Test Connection Section
            Section {
                Button {
                    Task {
                        await testConnection()
                    }
                } label: {
                    HStack {
                        if isTesting {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Testing...")
                        } else {
                            Image(systemName: "network")
                            Text("Test Connection")
                        }
                    }
                }
                .disabled(isTesting || !canTest)

                if let result = testResult {
                    switch result {
                    case .success:
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Connection successful")
                                .foregroundColor(.green)
                        }
                    case .failure(let error):
                        HStack {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red)
                            Text(error)
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                    }
                }
            }

            // MARK: - Delete Section
            if providerManager.hasAPIKey(for: provider) {
                Section {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("Delete API Key")
                        }
                    }
                }
            }
        }
        .navigationTitle(provider.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    saveConfiguration()
                    dismiss()
                }
            }
        }
        .alert("Delete API Key", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                providerManager.deleteAPIKey(for: provider)
                apiKey = ""
            }
        } message: {
            Text("Are you sure you want to delete the API key for \(provider.displayName)?")
        }
        .onAppear {
            loadCurrentConfiguration()
        }
        .task {
            if provider.supportsModelListing || !AIProviderModel.models(for: provider).isEmpty {
                await loadModels()
            }
        }
    }

    // MARK: - Computed Properties

    private var apiKeyFooter: String {
        switch provider {
        case .anthropic:
            return "Get your API key from console.anthropic.com"
        case .openai:
            return "Get your API key from platform.openai.com"
        case .openRouter:
            return "Get your API key from openrouter.ai/keys"
        default:
            return "Enter your API key for this provider"
        }
    }

    private var defaultModelHint: String {
        let defaultModel = AIProviderConfiguration.defaultModel(for: provider)
        return "Default: \(defaultModel)"
    }

    private var canTest: Bool {
        if provider.requiresAPIKey {
            return !apiKey.isEmpty || providerManager.hasAPIKey(for: provider)
        }
        return true
    }

    // MARK: - Methods

    private func loadCurrentConfiguration() {
        let config = providerManager.configuration(for: provider)

        baseURL = config.baseURL.absoluteString
        modelId = config.modelId
        timeout = config.timeout
        maxRetries = config.maxRetries
        isEnabled = config.isEnabled
        apiFormat = config.apiFormat

        // Load existing API key (masked display)
        if providerManager.hasAPIKey(for: provider) {
            // Don't load the actual key for security
            apiKey = ""
        }
    }

    private func saveConfiguration() {
        // Save API key if changed
        if !apiKey.isEmpty {
            providerManager.storeAPIKey(apiKey, for: provider)
        }

        // Build configuration
        let resolvedBaseURL = normalizedBaseURL(baseURL, provider: provider) ?? provider.defaultBaseURL
        let config = AIProviderConfiguration(
            providerType: provider,
            baseURL: resolvedBaseURL,
            modelId: modelId.isEmpty ? AIProviderConfiguration.defaultModel(for: provider) : modelId,
            timeout: timeout,
            maxRetries: maxRetries,
            isEnabled: isEnabled,
            apiFormat: apiFormat
        )

        providerManager.saveConfiguration(config)
    }

    private func testConnection() async {
        isTesting = true
        testResult = nil

        // Save current configuration temporarily
        saveConfiguration()

        let success = await providerManager.testConnection(for: provider)

        await MainActor.run {
            isTesting = false
            if success {
                testResult = .success
            } else {
                let status = providerManager.connectionStatus[provider]
                if case .disconnected(let error) = status {
                    testResult = .failure(error)
                } else {
                    testResult = .failure("Connection failed")
                }
            }
        }
    }

    private func loadModels() async {
        isLoadingModels = true

        // Prefer live model listing when supported
        if provider.supportsModelListing, let activeProvider = providerManager.provider(for: provider) {
            do {
                let models = try await activeProvider.listModels()
                if !models.isEmpty {
                    await MainActor.run {
                        availableModels = models
                        if modelId.isEmpty {
                            modelId = models.first?.modelId ?? ""
                        }
                        isLoadingModels = false
                    }
                    return
                }
            } catch {
                // Silently fail - fall back to predefined list
            }
        }

        // Fall back to predefined models
        let predefined = AIProviderModel.models(for: provider)
        if !predefined.isEmpty {
            await MainActor.run {
                availableModels = predefined
                if modelId.isEmpty {
                    modelId = predefined.first?.modelId ?? ""
                }
                isLoadingModels = false
            }
            return
        }

        await MainActor.run {
            isLoadingModels = false
        }
    }

    private var allowsCustomEndpoint: Bool {
        switch provider {
        case .ollama, .custom, .openRouter:
            return true
        case .anthropic, .openai:
            return false
        }
    }

    private func normalizedBaseURL(_ input: String, provider: AIProviderType) -> URL? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return provider.defaultBaseURL
        }

        var urlString = trimmed
        if !urlString.contains("://") {
            urlString = "https://" + urlString
        }

        guard var url = URL(string: urlString) else {
            return nil
        }

        guard provider == .openRouter else {
            return url
        }

        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url
        }

        var path = components.path
        if path.isEmpty || path == "/" {
            path = "/api"
        }

        if path.hasSuffix("/v1/") {
            path = String(path.dropLast(4))
        } else if path.hasSuffix("/v1") {
            path = String(path.dropLast(3))
        }

        if path.hasSuffix("/") && path != "/" {
            path.removeLast()
        }

        components.path = path
        if let normalized = components.url {
            url = normalized
        }

        return url
    }
}

// MARK: - Preview

#if DEBUG
struct ProviderConfigurationView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            ProviderConfigurationView(
                provider: .anthropic,
                providerManager: DependencyContainer.shared.aiProviderManager
            )
        }
    }
}
#endif

//
//  SettingsView.swift
//  TwinAct Field Companion
//
//  Settings screen for app configuration including demo mode.
//

import SwiftUI

// MARK: - Settings View

/// Main settings screen for the app.
public struct SettingsView: View {

    // MARK: - State

    @State private var isDemoMode = AppConfiguration.isDemoMode
    @AppStorage("useOnDeviceInference") private var useOnDeviceInference = AppConfiguration.GenAI.useOnDeviceInference
    @AppStorage("syncOnlyOnWiFi") private var syncOnlyOnWiFi = AppConfiguration.OfflineSync.syncOnlyOnWiFi
    @State private var showClearCacheAlert = false
    @State private var showSignOutAlert = false
    @State private var showResetOnboardingAlert = false
    @State private var cacheSize: String = "Calculating..."
    @State private var isAuthenticated = false
    @Environment(\.dismiss) private var dismiss

    // MARK: - Body

    public var body: some View {
        NavigationStack {
            Form {
                // MARK: - Demo Mode Section
                Section {
                    DemoModeToggleRow()
                } header: {
                    Text("Demo Mode")
                } footer: {
                    Text("When enabled, the app uses bundled sample data instead of connecting to a real AAS server. This is useful for App Store review, demos, and offline exploration.")
                }

                // MARK: - Authentication Section
                Section {
                    if isAuthenticated {
                        HStack {
                            Image(systemName: "person.crop.circle.fill")
                                .font(.title2)
                                .foregroundColor(.blue)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Signed In")
                                    .font(.body)
                                Text("user@example.com")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }

                        Button(role: .destructive) {
                            showSignOutAlert = true
                        } label: {
                            Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                    } else {
                        Button {
                            // Navigate to sign in
                        } label: {
                            Label("Sign In", systemImage: "person.crop.circle.badge.plus")
                        }

                        Text("Sign in to sync your data across devices and access your organization's assets.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Account")
                }
                .alert("Sign Out", isPresented: $showSignOutAlert) {
                    Button("Cancel", role: .cancel) {}
                    Button("Sign Out", role: .destructive) {
                        isAuthenticated = false
                    }
                } message: {
                    Text("Are you sure you want to sign out? Your local data will be preserved.")
                }

                // MARK: - AI Assistant Section
                Section {
                    Toggle(isOn: $useOnDeviceInference) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("On-Device Inference")
                                .font(.body)
                            Text(useOnDeviceInference ? "Using local AI model" : "Using cloud API")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("AI Assistant")
                } footer: {
                    Text("On-device inference provides faster responses and works offline, but cloud inference may provide better quality answers for complex questions.")
                }

                // MARK: - Sync Settings Section
                Section {
                    Toggle(isOn: $syncOnlyOnWiFi) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Sync Only on Wi-Fi")
                                .font(.body)
                            Text("Preserves cellular data")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    HStack {
                        Text("Sync Interval")
                        Spacer()
                        Text("\(Int(AppConfiguration.OfflineSync.syncIntervalSeconds / 60)) min")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Conflict Resolution")
                        Spacer()
                        Text(AppConfiguration.OfflineSync.conflictResolutionStrategy.rawValue.replacingOccurrences(of: "Wins", with: " Wins"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Sync")
                }

                // MARK: - Connection Section
                Section("Server Connection") {
                    if isDemoMode {
                        HStack {
                            Image(systemName: "cloud.slash")
                                .foregroundColor(.secondary)
                            Text("Not connected (Demo Mode)")
                                .foregroundColor(.secondary)
                        }
                    } else {
                        connectionInfo(label: "Registry", url: AppConfiguration.AASServer.registryURL)
                        connectionInfo(label: "Repository", url: AppConfiguration.AASServer.repositoryURL)
                        connectionInfo(label: "Discovery", url: AppConfiguration.AASServer.discoveryURL)
                    }
                }

                // MARK: - Features Section
                Section("Features") {
                    featureRow(name: "AR Mode", enabled: AppConfiguration.isAREnabled, icon: "arkit")
                    featureRow(name: "Voice Commands", enabled: AppConfiguration.isVoiceEnabled, icon: "mic")
                }

                // MARK: - Storage Section
                Section {
                    HStack {
                        Text("Cached Data")
                        Spacer()
                        Text(cacheSize)
                            .foregroundColor(.secondary)
                    }

                    Button(role: .destructive) {
                        showClearCacheAlert = true
                    } label: {
                        Label("Clear Cache", systemImage: "trash")
                    }
                } header: {
                    Text("Storage")
                } footer: {
                    Text("Clearing the cache will remove downloaded documents and images. They will be re-downloaded when needed.")
                }
                .alert("Clear Cache", isPresented: $showClearCacheAlert) {
                    Button("Cancel", role: .cancel) {}
                    Button("Clear", role: .destructive) {
                        clearCache()
                    }
                } message: {
                    Text("Are you sure you want to clear the cache? Downloaded documents and images will need to be re-downloaded.")
                }

                // MARK: - About Section
                Section("About") {
                    HStack {
                        Text("App Version")
                        Spacer()
                        Text("\(AppConfiguration.AppInfo.version) (\(AppConfiguration.AppInfo.build))")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Environment")
                        Spacer()
                        Text(AppConfiguration.current.rawValue.capitalized)
                            .foregroundColor(.secondary)
                    }

                    NavigationLink {
                        LicensesView()
                    } label: {
                        Label("Licenses", systemImage: "doc.text")
                    }

                    NavigationLink {
                        PrivacyPolicyView()
                    } label: {
                        Label("Privacy Policy", systemImage: "hand.raised")
                    }
                }

                // MARK: - Demo Data Section
                if isDemoMode {
                    Section("Demo Data") {
                        NavigationLink {
                            DemoDataInfoView()
                        } label: {
                            Label("View Demo Asset Info", systemImage: "info.circle")
                        }
                    }
                }

                // MARK: - Advanced Section
                Section {
                    Button {
                        showResetOnboardingAlert = true
                    } label: {
                        Label("Show Onboarding Again", systemImage: "hand.wave")
                    }

                    #if DEBUG
                    NavigationLink {
                        DiagnosticsView()
                    } label: {
                        Label("Diagnostics", systemImage: "ladybug")
                    }
                    #endif
                } header: {
                    Text("Advanced")
                }
                .alert("Reset Onboarding", isPresented: $showResetOnboardingAlert) {
                    Button("Cancel", role: .cancel) {}
                    Button("Reset") {
                        UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
                    }
                } message: {
                    Text("The onboarding flow will be shown again when you restart the app.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .demoModeDidChange)) { _ in
                isDemoMode = AppConfiguration.isDemoMode
            }
            .task {
                await calculateCacheSize()
            }
        }
    }

    // MARK: - Helper Views

    private func connectionInfo(label: String, url: URL) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(url.host ?? url.absoluteString)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
    }

    private func featureRow(name: String, enabled: Bool, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(enabled ? .blue : .secondary)
                .frame(width: 24)
            Text(name)
            Spacer()
            Text(enabled ? "Enabled" : "Disabled")
                .font(.caption)
                .foregroundColor(enabled ? .green : .secondary)
        }
    }

    // MARK: - Actions

    private func calculateCacheSize() async {
        // Simulate cache size calculation
        let fileManager = FileManager.default

        guard let cacheDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            cacheSize = "Unknown"
            return
        }

        var totalSize: Int64 = 0

        if let enumerator = fileManager.enumerator(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey]) {
            while let fileURL = enumerator.nextObject() as? URL {
                if let fileSize = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                    totalSize += Int64(fileSize)
                }
            }
        }

        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        cacheSize = formatter.string(fromByteCount: totalSize)
    }

    private func clearCache() {
        let fileManager = FileManager.default

        guard let cacheDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return
        }

        do {
            let contents = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)
            for fileURL in contents {
                try? fileManager.removeItem(at: fileURL)
            }
            cacheSize = "0 bytes"
        } catch {
            // Handle error silently
        }

        // Clear demo data cache
        DemoDataProvider.shared.clearCache()
    }

    // MARK: - Initialization

    public init() {}
}

// MARK: - Licenses View

/// Displays open source licenses.
struct LicensesView: View {
    var body: some View {
        List {
            Section {
                Text("TwinAct Field Companion uses the following open source libraries:")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Swift Packages") {
                LicenseRow(name: "SwiftUI", license: "Apple Inc. - Proprietary")
                LicenseRow(name: "ARKit", license: "Apple Inc. - Proprietary")
                LicenseRow(name: "Core ML", license: "Apple Inc. - Proprietary")
            }

            Section {
                Text("All third-party libraries are used in accordance with their respective licenses.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("Licenses")
    }
}

struct LicenseRow: View {
    let name: String
    let license: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(name)
                .font(.body)
            Text(license)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Privacy Policy View

/// Displays the privacy policy.
struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Privacy Policy")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Last updated: January 2025")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Group {
                    Text("Data Collection")
                        .font(.headline)

                    Text("TwinAct Field Companion collects minimal data necessary to provide its core functionality. This includes:")
                        .font(.body)

                    BulletPoint("Asset identification data scanned via QR codes")
                    BulletPoint("Service request data you create")
                    BulletPoint("Usage analytics to improve app performance")
                }

                Group {
                    Text("Data Storage")
                        .font(.headline)

                    Text("Your data is stored securely on your device and optionally synced to your organization's AAS server. We do not share your data with third parties.")
                        .font(.body)
                }

                Group {
                    Text("Contact")
                        .font(.headline)

                    Text("For privacy questions, contact privacy@twinact.example.com")
                        .font(.body)
                }
            }
            .padding()
        }
        .navigationTitle("Privacy Policy")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct BulletPoint: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\u{2022}")
            Text(text)
        }
        .font(.body)
        .padding(.leading)
    }
}

// MARK: - Diagnostics View (Debug Only)

#if DEBUG
struct DiagnosticsView: View {
    @State private var testResults: [(name: String, passed: Bool)] = []

    var body: some View {
        List {
            Section("System Info") {
                LabeledContent("iOS Version", value: UIDevice.current.systemVersion)
                LabeledContent("Device Model", value: UIDevice.current.model)
                LabeledContent("Bundle ID", value: AppConfiguration.AppInfo.bundleIdentifier)
            }

            Section("Tests") {
                Button("Run AAS Encoding Tests") {
                    let results = AASIdentifierEncodingTests.runAllTests()
                    testResults = [
                        ("Encoding Tests", results.failed == 0)
                    ]
                }

                ForEach(testResults, id: \.name) { result in
                    HStack {
                        Text(result.name)
                        Spacer()
                        Image(systemName: result.passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(result.passed ? .green : .red)
                    }
                }
            }

            Section("Demo Data") {
                Button("Validate Demo Data") {
                    let isValid = DemoData.isAvailable
                    testResults = [
                        ("Demo Data Available", isValid)
                    ]
                }
            }
        }
        .navigationTitle("Diagnostics")
    }
}
#endif

// MARK: - Demo Data Info View

/// Shows information about the bundled demo data.
struct DemoDataInfoView: View {

    let demoProvider = DemoDataProvider.shared

    @State private var assetName: String = "Loading..."
    @State private var serialNumber: String = ""
    @State private var manufacturer: String = ""
    @State private var serviceRequestCount: Int = 0
    @State private var documentCount: Int = 0

    var body: some View {
        List {
            Section("Demo Asset") {
                LabeledContent("Name", value: assetName)
                LabeledContent("Serial Number", value: serialNumber)
                LabeledContent("Manufacturer", value: manufacturer)
            }

            Section("Available Data") {
                LabeledContent("Service Requests", value: "\(serviceRequestCount)")
                LabeledContent("Documents", value: "\(documentCount)")
            }

            Section {
                Text("This demo asset represents a Smart Industrial Pump SP-500 with realistic sample data including digital nameplate, service history, maintenance instructions, carbon footprint data, and time series sensor readings.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("Demo Asset Info")
        .task {
            loadDemoData()
        }
    }

    private func loadDemoData() {
        do {
            let nameplate = try demoProvider.loadDigitalNameplate()
            assetName = nameplate.manufacturerProductDesignation ?? "Unknown"
            serialNumber = nameplate.serialNumber ?? "Unknown"
            manufacturer = nameplate.manufacturerName ?? "Unknown"

            let requests = try demoProvider.loadServiceRequests()
            serviceRequestCount = requests.count

            let docs = try demoProvider.loadDocumentation()
            documentCount = docs.documents.count
        } catch {
            assetName = "Error loading demo data"
        }
    }
}

// MARK: - Preview

#if DEBUG
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .previewDisplayName("Settings View")

        DemoDataInfoView()
            .previewDisplayName("Demo Data Info")
    }
}
#endif

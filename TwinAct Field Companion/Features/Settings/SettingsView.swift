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

    // MARK: - Initialization

    public init() {}
}

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

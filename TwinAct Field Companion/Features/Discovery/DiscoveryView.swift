//
//  DiscoveryView.swift
//  TwinAct Field Companion
//
//  Main Discovery feature view - entry point for asset discovery.
//  Provides QR scanning, manual entry, and recent asset history.
//

import SwiftUI

// MARK: - Discovery View

/// Main view for asset discovery feature.
public struct DiscoveryView: View {

    // MARK: - Properties

    @StateObject private var viewModel = DiscoveryViewModel()
    @State private var showScanner = false
    @State private var showManualSearch = false
    @State private var searchText = ""
    @State private var navigateToPassport = false
    @EnvironmentObject private var appState: AppState
#if DEBUG
    @State private var didTriggerDemoScan = false
#endif

    // MARK: - Body

    public var body: some View {
        NavigationStack {
            ZStack {
                // Main content
                mainContent

                // Loading overlay
                if viewModel.state.isLoading {
                    loadingOverlay
                }
            }
            .navigationTitle("Discover")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    scanButton
                }
            }
            .fullScreenCover(isPresented: $showScanner) {
                QRScannerView { link in
                    Task {
                        await viewModel.processIdentificationLink(link)
                    }
                }
                .autoDismiss(true, delay: autoDismissDelay)
            }
            .sheet(isPresented: $showManualSearch) {
                ManualSearchSheet(
                    searchText: $searchText,
                    onSearch: handleManualSearch
                )
            }
            .navigationDestination(isPresented: $navigateToPassport) {
                if let asset = viewModel.discoveredAsset ?? appState.selectedAsset {
                    PassportView(assetId: asset.id)
                }
            }
            .onChange(of: viewModel.state) { _, newState in
                switch newState {
                case .found(let asset):
                    appState.setSelectedAsset(asset)
                    navigateToPassport = true
                case .offline(let cachedAsset):
                    if let asset = cachedAsset {
                        appState.setSelectedAsset(asset)
                        navigateToPassport = true
                    }
                default:
                    break
                }
            }
#if DEBUG
            .onAppear {
                guard !didTriggerDemoScan,
                      ProcessInfo.processInfo.environment["DEMO_GIF"] == "1" else {
                    return
                }
                didTriggerDemoScan = true
                showScanner = true
            }
#endif
        }
    }

private var autoDismissDelay: TimeInterval {
#if DEBUG
        if AppConfiguration.isUITest {
            return 0.2
        }
        if ProcessInfo.processInfo.environment["DEMO_GIF"] == "1" {
            return 2.0
        }
#endif
        return 0.5
    }

    // MARK: - Main Content

    private var mainContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Hero scan section
                scanHeroSection

                // Quick actions
                quickActionsSection

                // Recent discoveries
                if !viewModel.recentDiscoveries.isEmpty {
                    recentDiscoveriesSection
                }

                // Error display
                if case .error(let message) = viewModel.state {
                    errorSection(message: message)
                }

                if case .notFound(let reason) = viewModel.state {
                    notFoundSection(reason: reason)
                }

                Spacer(minLength: 100)
            }
            .padding()
        }
    }

    // MARK: - Scan Hero Section

    private var scanHeroSection: some View {
        VStack(spacing: 16) {
            // QR code icon
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 120, height: 120)

                Image(systemName: "qrcode.viewfinder")
                    .font(.system(size: 50))
                    .foregroundColor(.blue)
            }

            // Title
            Text("Scan Asset QR Code")
                .font(.title2)
                .fontWeight(.semibold)

            // Description
            Text("Point your camera at a QR code on the asset to view its Digital Product Passport")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            // Scan button
            Button {
                handleScanTap()
            } label: {
                HStack {
                    Image(systemName: "camera.fill")
                    Text("Start Scanning")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .cornerRadius(12)
            }
            .accessibilityIdentifier("scan.button")
            .padding(.horizontal)
        }
        .padding(.vertical, 20)
    }

    // MARK: - Quick Actions Section

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Other Options")
                .font(.headline)
                .foregroundColor(.secondary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                // Manual search
                QuickActionCard(
                    icon: "magnifyingglass",
                    title: "Search",
                    subtitle: "Enter serial number",
                    color: .orange
                ) {
                    showManualSearch = true
                }

                // Browse assets (placeholder)
                QuickActionCard(
                    icon: "list.bullet.rectangle",
                    title: "Browse",
                    subtitle: "View all assets",
                    color: .purple
                ) {
                    // TODO: Implement browse functionality
                }

                if AppConfiguration.isDemoMode {
                    QuickActionCard(
                        icon: "sparkles",
                        title: "Demo Asset",
                        subtitle: "App Review mode",
                        color: .green
                    ) {
                        appState.setSelectedAsset(DemoData.asset)
                        navigateToPassport = true
                    }
                }
            }
        }
    }

    // MARK: - Recent Discoveries Section

    private var recentDiscoveriesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent")
                    .font(.headline)
                    .foregroundColor(.secondary)

                Spacer()

                Button("Clear") {
                    viewModel.recentDiscoveries.removeAll()
                }
                .font(.caption)
                .foregroundColor(.blue)
            }

            ForEach(viewModel.recentDiscoveries) { asset in
                RecentAssetRow(asset: asset) {
                    Task {
                        await viewModel.lookupByGlobalAssetId(asset.id)
                    }
                }
            }
        }
    }

    // MARK: - Error Section

    private func errorSection(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundColor(.orange)

            Text("Something went wrong")
                .font(.headline)

            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button("Try Again") {
                viewModel.reset()
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    // MARK: - Not Found Section

    private func notFoundSection(reason: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.largeTitle)
                .foregroundColor(.gray)

            Text("Asset Not Found")
                .font(.headline)

            Text(reason)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                Button("Scan Again") {
                    viewModel.reset()
                    showScanner = true
                }
                .buttonStyle(.bordered)

                Button("Search Manually") {
                    showManualSearch = true
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    // MARK: - Loading Overlay

    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)

                Text(viewModel.state.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(30)
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(radius: 10)
        }
    }

    // MARK: - Toolbar Button

    private var scanButton: some View {
        Button {
            handleScanTap()
        } label: {
            Image(systemName: "qrcode.viewfinder")
                .font(.title2)
        }
    }

    private func handleScanTap() {
#if DEBUG
        let env = ProcessInfo.processInfo.environment
        if AppConfiguration.isUITest
            || env["UITEST_MODE"] == "1"
            || env["SIMULATED_QR"] != nil {
            appState.setSelectedAsset(DemoData.asset)
            navigateToPassport = true
            return
        }
#endif
        showScanner = true
    }

    // MARK: - Actions

    private func handleManualSearch() {
        showManualSearch = false
        guard !searchText.isEmpty else { return }

        if AppConfiguration.isDemoMode {
            let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if trimmed == "demo" || trimmed == "demo-asset" || trimmed == DemoData.asset.id.lowercased() {
                appState.setSelectedAsset(DemoData.asset)
                navigateToPassport = true
                return
            }
        }

        Task {
            await viewModel.lookupBySerialNumber(searchText)
        }
    }
}

// MARK: - Quick Action Card

struct QuickActionCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)

                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)

                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Recent Asset Row

struct RecentAssetRow: View {
    let asset: AssetSummary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Thumbnail or placeholder
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.tertiarySystemBackground))
                        .frame(width: 50, height: 50)

                    if let url = asset.thumbnailURL {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Image(systemName: "cube.fill")
                                .foregroundColor(.gray)
                        }
                        .frame(width: 50, height: 50)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        Image(systemName: "cube.fill")
                            .foregroundColor(.gray)
                    }
                }

                // Info
                VStack(alignment: .leading, spacing: 2) {
                    Text(asset.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)

                    if let manufacturer = asset.manufacturer {
                        Text(manufacturer)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Manual Search Sheet

struct ManualSearchSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var searchText: String
    @FocusState private var isFocused: Bool
    var onSearch: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Enter the serial number, part number, or asset ID")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                TextField("Serial number or asset ID", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                    .focused($isFocused)
                    .padding(.horizontal)

                Spacer()
            }
            .padding(.top)
            .navigationTitle("Manual Search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Search") {
                        onSearch()
                    }
                    .disabled(searchText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                isFocused = true
            }
        }
    }
}

// MARK: - Passport Placeholder View

/// Placeholder for navigation to Passport view.
struct PassportPlaceholderView: View {
    let asset: Asset

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)

            Text("Asset Discovered!")
                .font(.title)
                .fontWeight(.bold)

            VStack(alignment: .leading, spacing: 8) {
                InfoRow(label: "Name", value: asset.name)
                if let manufacturer = asset.manufacturer {
                    InfoRow(label: "Manufacturer", value: manufacturer)
                }
                if let serial = asset.serialNumber {
                    InfoRow(label: "Serial Number", value: serial)
                }
                if let model = asset.model {
                    InfoRow(label: "Model", value: model)
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)

            Text("Full Passport view coming soon...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .navigationTitle("Asset Passport")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 100, alignment: .leading)
            Text(value)
                .font(.subheadline)
        }
    }
}

// MARK: - Preview Provider

#if DEBUG
struct DiscoveryView_Previews: PreviewProvider {
    static var previews: some View {
        DiscoveryView()
            .environmentObject(AppState())
    }
}
#endif

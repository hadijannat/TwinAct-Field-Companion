//
//  PassportView.swift
//  TwinAct Field Companion
//
//  Digital Product Passport view for displaying asset information.
//  Provides read-only access to Digital Nameplate, Carbon Footprint,
//  Documentation, and Technical Data.
//

import SwiftUI

// MARK: - Passport View

/// Digital Product Passport view for an asset.
/// Displays DPP-compliant information including nameplate, sustainability data,
/// and documentation.
public struct PassportView: View {

    // MARK: - Properties

    @StateObject private var viewModel: PassportViewModel
    @State private var selectedSection: PassportSection?
    @Environment(\.dismiss) private var dismiss

    let assetId: String

    // MARK: - Initialization

    /// Initialize with asset ID.
    /// - Parameter assetId: The asset/AAS identifier
    public init(assetId: String) {
        self.assetId = assetId
        self._viewModel = StateObject(wrappedValue: PassportViewModel(assetId: assetId))
    }

    /// Initialize with asset ID and custom services.
    /// - Parameters:
    ///   - assetId: The asset/AAS identifier
    ///   - viewModel: Custom view model with injected dependencies
    public init(assetId: String, viewModel: PassportViewModel) {
        self.assetId = assetId
        self._viewModel = StateObject(wrappedValue: viewModel)
    }

    // MARK: - Body

    public var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Asset header with image/icon
                    AssetHeaderView(asset: viewModel.asset)

                    // Cache indicator
                    if viewModel.isFromCache {
                        cacheIndicator
                    }

                    // Digital Nameplate section
                    if let nameplate = viewModel.digitalNameplate {
                        NameplateCardView(nameplate: nameplate)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    // Carbon Footprint section (DPP sustainability)
                    if let carbon = viewModel.carbonFootprint {
                        CarbonFootprintView(footprint: carbon)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    // Documentation section
                    if !viewModel.documents.isEmpty {
                        DocumentListView(documents: viewModel.documents)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    // Technical Data summary (if available)
                    if let techData = viewModel.technicalData {
                        TechnicalDataSummaryView(data: techData)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    // Empty state if no data
                    if !viewModel.isLoading && viewModel.asset == nil && viewModel.error == nil {
                        emptyState
                    }

                    // Error state
                    if let error = viewModel.error {
                        errorState(error: error)
                    }

                    // Bottom spacing
                    Spacer(minLength: 40)
                }
                .padding()
                .animation(.easeInOut(duration: 0.3), value: viewModel.isLoading)
            }
            .refreshable {
                await viewModel.refresh()
            }

            // Loading overlay
            if viewModel.isLoading && viewModel.asset == nil {
                loadingOverlay
            }
        }
        .accessibilityIdentifier("passport.view")
        .navigationTitle("Asset Passport")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if let asset = viewModel.asset {
                    ShareButton(asset: asset)
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                }
            }
        }
        .task {
            await viewModel.loadAsset()
        }
    }

    // MARK: - Cache Indicator

    private var cacheIndicator: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.caption)

            Text("Showing cached data")
                .font(.caption)

            if let lastRefreshed = viewModel.lastRefreshed {
                Text("Updated \(lastRefreshed, style: .relative) ago")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .foregroundColor(.orange)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(8)
    }

    // MARK: - Loading Overlay

    private var loadingOverlay: some View {
        ZStack {
            Color(.systemBackground)
                .opacity(0.9)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)

                Text("Loading Passport...")
                    .font(.headline)

                Text("Fetching asset information")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(30)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(16)
            .shadow(radius: 10)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 50))
                .foregroundColor(.secondary)

            Text("No Passport Data")
                .font(.headline)

            Text("This asset does not have any Digital Product Passport information available.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button {
                Task {
                    await viewModel.refresh()
                }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }

    // MARK: - Error State

    private func errorState(error: PassportError) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundColor(.orange)

            Text("Unable to Load Passport")
                .font(.headline)

            Text(error.localizedDescription)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                Button {
                    Task {
                        await viewModel.refresh()
                    }
                } label: {
                    Label("Try Again", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.borderedProminent)

                Button("Go Back") {
                    dismiss()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Passport Section

/// Sections in the passport view.
public enum PassportSection: String, CaseIterable, Identifiable {
    case nameplate
    case carbonFootprint
    case documentation
    case technicalData

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .nameplate: return "Digital Nameplate"
        case .carbonFootprint: return "Carbon Footprint"
        case .documentation: return "Documentation"
        case .technicalData: return "Technical Data"
        }
    }

    public var icon: String {
        switch self {
        case .nameplate: return "tag.fill"
        case .carbonFootprint: return "leaf.fill"
        case .documentation: return "doc.fill"
        case .technicalData: return "cpu.fill"
        }
    }
}

// MARK: - Share Button

/// Share button for asset passport.
struct ShareButton: View {
    let asset: Asset

    var body: some View {
        ShareLink(
            item: shareText,
            subject: Text("Digital Product Passport"),
            message: Text("Asset information from TwinAct Field Companion")
        ) {
            Image(systemName: "square.and.arrow.up")
        }
    }

    private var shareText: String {
        var text = "Digital Product Passport\n\n"
        text += "Asset: \(asset.name)\n"

        if let manufacturer = asset.manufacturer {
            text += "Manufacturer: \(manufacturer)\n"
        }

        if let serial = asset.serialNumber {
            text += "Serial Number: \(serial)\n"
        }

        if let model = asset.model {
            text += "Model: \(model)\n"
        }

        text += "\nAsset ID: \(asset.id)\n"
        text += "\nGenerated by TwinAct Field Companion"

        return text
    }
}

// MARK: - Preview Provider

#if DEBUG
struct PassportView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            PassportView(assetId: "preview-asset-id")
        }
    }
}
#endif

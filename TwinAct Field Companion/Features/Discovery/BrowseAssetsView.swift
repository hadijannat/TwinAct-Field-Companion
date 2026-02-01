//
//  BrowseAssetsView.swift
//  TwinAct Field Companion
//
//  Browse and select assets from the registry.
//

import SwiftUI
import Combine

// MARK: - Browse Assets View

struct BrowseAssetsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = BrowseAssetsViewModel()

    let onSelect: (AssetSummary) -> Void

    var body: some View {
        NavigationStack {
            List {
                if !viewModel.assets.isEmpty {
                    ForEach(viewModel.assets) { asset in
                        Button {
                            onSelect(asset)
                            dismiss()
                        } label: {
                            AssetSummaryRow(asset: asset)
                        }
                        .buttonStyle(.plain)
                    }
                }

                if viewModel.isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                } else if viewModel.hasMore {
                    Button("Load More") {
                        viewModel.loadMore()
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Browse Assets")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .searchable(text: $viewModel.searchText, placement: .navigationBarDrawer(displayMode: .automatic))
            .onChange(of: viewModel.searchText) { _, _ in
                viewModel.search()
            }
            .overlay {
                if let message = viewModel.errorMessage {
                    ContentUnavailableView(
                        "Unable to load assets",
                        systemImage: "exclamationmark.triangle",
                        description: Text(message)
                    )
                }
            }
            .task {
                viewModel.loadInitial()
            }
        }
    }
}

// MARK: - Row

private struct AssetSummaryRow: View {
    let asset: AssetSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(asset.name)
                .font(.headline)

            Text(asset.displayId)
                .font(.caption)
                .foregroundColor(.secondary)

            if asset.submodelCount > 0 {
                Text("\(asset.submodelCount) submodels")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - View Model

@MainActor
final class BrowseAssetsViewModel: ObservableObject {
    @Published var assets: [AssetSummary] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var hasMore: Bool = false
    @Published var searchText: String = ""

    private let assetService: AssetServiceProtocol
    private var nextCursor: String?
    private var loadTask: Task<Void, Never>?

    init(assetService: AssetServiceProtocol? = nil) {
        self.assetService = assetService ?? DependencyContainer.shared.assetService
    }

    func loadInitial() {
        load(reset: true)
    }

    func loadMore() {
        guard !isLoading, nextCursor != nil else { return }
        load(reset: false)
    }

    func search() {
        load(reset: true)
    }

    private func load(reset: Bool) {
        loadTask?.cancel()
        loadTask = Task { @MainActor in
            isLoading = true
            errorMessage = nil

            if reset {
                assets = []
                nextCursor = nil
                hasMore = false
            }

            do {
                let page: AssetPage
                if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    page = try await assetService.browseAssets(
                        cursor: reset ? nil : nextCursor,
                        filter: nil
                    )
                } else {
                    page = try await assetService.searchAssets(
                        text: searchText,
                        cursor: reset ? nil : nextCursor
                    )
                }

                if reset {
                    assets = page.items
                } else {
                    assets.append(contentsOf: page.items)
                }

                nextCursor = page.nextCursor
                hasMore = page.nextCursor != nil
            } catch {
                errorMessage = error.localizedDescription
            }

            isLoading = false
        }
    }
}

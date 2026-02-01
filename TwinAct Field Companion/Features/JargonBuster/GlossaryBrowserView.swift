//
//  GlossaryBrowserView.swift
//  TwinAct Field Companion
//
//  Full-screen glossary browser with search and category filtering.
//

import SwiftUI

// MARK: - Glossary Browser View

/// A full-screen view for browsing and searching the glossary.
///
/// Features:
/// - Search bar for finding terms
/// - Category filter chips
/// - Alphabetical list with section headers
/// - Recent lookups section
public struct GlossaryBrowserView: View {

    // MARK: - Properties

    @StateObject private var viewModel: GlossaryBrowserViewModel
    @StateObject private var jargonBusterVM: JargonBusterViewModel

    /// Callback when a term is selected
    var onTermSelected: ((GlossaryEntry) -> Void)?

    @State private var selectedEntry: GlossaryEntry?
    @State private var showingSheet = false

    // MARK: - Initialization

    public init(
        glossaryService: GlossaryService,
        onTermSelected: ((GlossaryEntry) -> Void)? = nil
    ) {
        _viewModel = StateObject(wrappedValue: GlossaryBrowserViewModel(glossaryService: glossaryService))
        _jargonBusterVM = StateObject(wrappedValue: JargonBusterViewModel(glossaryService: glossaryService))
        self.onTermSelected = onTermSelected
    }

    // MARK: - Body

    public var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    loadingView
                } else if let error = viewModel.errorMessage {
                    errorView(error)
                } else {
                    glossaryList
                }
            }
            .navigationTitle("Glossary")
            .searchable(text: $viewModel.searchText, prompt: "Search terms...")
            .task {
                await viewModel.loadGlossary()
            }
            .sheet(item: $selectedEntry) { entry in
                JargonBusterSheet(
                    entry: entry,
                    viewModel: jargonBusterVM,
                    onDismiss: { selectedEntry = nil }
                )
            }
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)

            Text("Loading glossary...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Error View

    private func errorView(_ error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.orange)

            Text("Failed to load glossary")
                .font(.headline)

            Text(error)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button {
                Task {
                    await viewModel.loadGlossary()
                }
            } label: {
                Label("Retry", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Glossary List

    private var glossaryList: some View {
        List {
            // Category filters
            Section {
                categoryFilterChips
            }

            // Statistics
            if let stats = viewModel.statistics {
                Section {
                    statisticsRow(stats)
                }
            }

            // Terms by letter
            ForEach(viewModel.groupedEntries, id: \.letter) { group in
                Section(header: Text(group.letter)) {
                    ForEach(group.entries) { entry in
                        glossaryRow(entry)
                    }
                }
            }

            // Empty state
            if viewModel.filteredEntries.isEmpty {
                emptySearchState
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Category Filter Chips

    private var categoryFilterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                // All categories chip
                CategoryFilterChip(
                    title: "All",
                    icon: "square.grid.2x2.fill",
                    isSelected: viewModel.selectedCategory == nil,
                    color: .accentColor
                ) {
                    viewModel.filterByCategory(nil)
                }

                // Category-specific chips
                ForEach(TermCategory.allCases, id: \.self) { category in
                    CategoryFilterChip(
                        title: category.displayName,
                        icon: category.icon,
                        isSelected: viewModel.selectedCategory == category,
                        color: categoryColor(category)
                    ) {
                        viewModel.filterByCategory(category)
                    }
                }
            }
            .padding(.horizontal, 4)
        }
    }

    // MARK: - Statistics Row

    private func statisticsRow(_ stats: GlossaryStatistics) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(stats.totalTerms) Terms")
                    .font(.headline)
                Text("\(stats.totalLocalTerms) official, \(stats.totalCachedTerms) AI-generated")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: "book.closed.fill")
                .font(.title2)
                .foregroundColor(.accentColor)
        }
    }

    // MARK: - Glossary Row

    private func glossaryRow(_ entry: GlossaryEntry) -> some View {
        Button {
            Task {
                await jargonBusterVM.displayEntry(entry)
                selectedEntry = entry
            }
        } label: {
            HStack(spacing: 12) {
                // Icon
                ZStack {
                    Circle()
                        .fill(categoryColor(entry.category).opacity(0.15))
                        .frame(width: 40, height: 40)

                    Image(systemName: entry.icon)
                        .font(.body)
                        .foregroundColor(categoryColor(entry.category))
                }

                // Content
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.title)
                        .font(.body)
                        .foregroundColor(.primary)

                    Text(entry.simpleText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                // Source indicator
                if entry.source.isAIGenerated {
                    Image(systemName: "sparkles")
                        .font(.caption)
                        .foregroundColor(.purple)
                }

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Empty Search State

    private var emptySearchState: some View {
        Section {
            VStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 32))
                    .foregroundColor(.secondary)

                Text("No terms found")
                    .font(.headline)

                Text("Try a different search term or category")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                if viewModel.selectedCategory != nil || !viewModel.searchText.isEmpty {
                    Button("Clear Filters") {
                        viewModel.clearFilters()
                    }
                    .font(.subheadline)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
        }
    }

    // MARK: - Helpers

    private func categoryColor(_ category: TermCategory) -> Color {
        switch category {
        case .sustainability:
            return .green
        case .battery:
            return .yellow
        case .compliance:
            return .blue
        case .technical:
            return .purple
        case .manufacturing:
            return .orange
        }
    }
}

// MARK: - Category Filter Chip

/// A selectable filter chip for category filtering with icon support.
struct CategoryFilterChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.subheadline)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? color.opacity(0.2) : Color(.secondarySystemBackground))
            .foregroundColor(isSelected ? color : .primary)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(isSelected ? color : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Compact Glossary Browser

/// A compact version of the glossary browser for embedding in other views.
public struct CompactGlossaryBrowser: View {

    let glossaryService: GlossaryService
    let onTermSelected: (GlossaryEntry) -> Void

    @State private var searchText = ""
    @State private var searchResults: [GlossaryEntry] = []

    public init(
        glossaryService: GlossaryService,
        onTermSelected: @escaping (GlossaryEntry) -> Void
    ) {
        self.glossaryService = glossaryService
        self.onTermSelected = onTermSelected
    }

    public var body: some View {
        VStack(spacing: 12) {
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)

                TextField("Search glossary...", text: $searchText)
                    .textFieldStyle(.plain)

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                        searchResults = []
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(10)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            // Results
            if !searchResults.isEmpty {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(searchResults) { entry in
                            compactResultRow(entry)
                        }
                    }
                }
                .frame(maxHeight: 200)
            }
        }
        .onChange(of: searchText) { _, newValue in
            Task {
                if newValue.isEmpty {
                    searchResults = []
                } else {
                    searchResults = await glossaryService.search(query: newValue)
                }
            }
        }
    }

    private func compactResultRow(_ entry: GlossaryEntry) -> some View {
        Button {
            onTermSelected(entry)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: entry.icon)
                    .font(.body)
                    .foregroundColor(.accentColor)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.title)
                        .font(.subheadline)
                        .foregroundColor(.primary)

                    Text(entry.category.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color(.tertiarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#if DEBUG
struct GlossaryBrowserView_Previews: PreviewProvider {
    static var previews: some View {
        // Would need actual GlossaryService
        Text("GlossaryBrowserView Preview")
            .previewDisplayName("Browser")
    }
}
#endif

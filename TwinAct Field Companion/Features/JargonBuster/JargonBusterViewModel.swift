//
//  JargonBusterViewModel.swift
//  TwinAct Field Companion
//
//  ViewModel for the Jargon Buster sheet and glossary browser.
//

import Foundation
import Combine
import os.log

// MARK: - Jargon Buster State

/// State for the jargon buster sheet
public enum JargonBusterState: Equatable {
    case idle
    case loading
    case loaded(GlossaryEntry)
    case error(String)

    public static func == (lhs: JargonBusterState, rhs: JargonBusterState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.loading, .loading):
            return true
        case (.loaded(let a), .loaded(let b)):
            return a.id == b.id
        case (.error(let a), .error(let b)):
            return a == b
        default:
            return false
        }
    }
}

// MARK: - Jargon Buster View Model

/// ViewModel for managing glossary term lookups and explanations.
@MainActor
public final class JargonBusterViewModel: ObservableObject {

    // MARK: - Published Properties

    /// Current state of the view model
    @Published public private(set) var state: JargonBusterState = .idle

    /// Currently displayed entry
    @Published public private(set) var currentEntry: GlossaryEntry?

    /// Related terms for the current entry
    @Published public private(set) var relatedTerms: [GlossaryEntry] = []

    /// Recent lookups for quick access
    @Published public private(set) var recentLookups: [GlossaryEntry] = []

    /// Error message if any
    @Published public private(set) var errorMessage: String?

    // MARK: - Private Properties

    private let glossaryService: GlossaryService
    private let maxRecentLookups = 10
    private let logger = Logger(
        subsystem: AppConfiguration.AppInfo.bundleIdentifier,
        category: "JargonBusterViewModel"
    )

    // MARK: - Initialization

    /// Initialize with glossary service
    public init(glossaryService: GlossaryService) {
        self.glossaryService = glossaryService
    }

    // MARK: - Public Methods

    /// Look up a term by ID
    /// - Parameter termId: The term ID to look up
    public func lookupTerm(id termId: String) async {
        state = .loading
        errorMessage = nil

        do {
            let entry = try await glossaryService.explain(term: termId, context: nil)
            await displayEntry(entry)
        } catch {
            logger.error("Failed to lookup term '\(termId)': \(error.localizedDescription)")
            state = .error(error.localizedDescription)
            errorMessage = error.localizedDescription
        }
    }

    /// Look up a term by display text (title)
    /// - Parameters:
    ///   - term: The term text to look up
    ///   - context: Optional context for LLM generation
    public func lookupTerm(_ term: String, context: String? = nil) async {
        state = .loading
        errorMessage = nil

        do {
            let entry = try await glossaryService.explain(term: term, context: context)
            await displayEntry(entry)
        } catch {
            logger.error("Failed to lookup term '\(term)': \(error.localizedDescription)")
            state = .error(error.localizedDescription)
            errorMessage = error.localizedDescription
        }
    }

    /// Display a pre-loaded entry
    /// - Parameter entry: The glossary entry to display
    public func displayEntry(_ entry: GlossaryEntry) async {
        currentEntry = entry
        state = .loaded(entry)

        // Load related terms
        relatedTerms = await glossaryService.relatedTerms(for: entry)

        // Add to recent lookups
        addToRecentLookups(entry)

        logger.debug("Displaying entry: \(entry.title) (source: \(entry.source.displayName))")
    }

    /// Navigate to a related term
    /// - Parameter entry: The related entry to navigate to
    public func navigateToRelated(_ entry: GlossaryEntry) async {
        await displayEntry(entry)
    }

    /// Clear the current display state
    public func clear() {
        state = .idle
        currentEntry = nil
        relatedTerms = []
        errorMessage = nil
    }

    /// Retry the last failed lookup
    public func retry() async {
        guard let entry = currentEntry else { return }
        await lookupTerm(id: entry.id)
    }

    // MARK: - Private Methods

    private func addToRecentLookups(_ entry: GlossaryEntry) {
        // Remove if already in recents
        recentLookups.removeAll { $0.id == entry.id }

        // Add to front
        recentLookups.insert(entry, at: 0)

        // Trim to max size
        if recentLookups.count > maxRecentLookups {
            recentLookups = Array(recentLookups.prefix(maxRecentLookups))
        }
    }
}

// MARK: - Glossary Browser View Model

/// ViewModel for the full glossary browser view.
@MainActor
public final class GlossaryBrowserViewModel: ObservableObject {

    // MARK: - Published Properties

    /// All glossary entries
    @Published public private(set) var allEntries: [GlossaryEntry] = []

    /// Filtered entries based on search and category
    @Published public private(set) var filteredEntries: [GlossaryEntry] = []

    /// Current search text
    @Published public var searchText: String = "" {
        didSet {
            filterEntries()
        }
    }

    /// Selected category filter
    @Published public var selectedCategory: TermCategory? = nil {
        didSet {
            filterEntries()
        }
    }

    /// Whether the glossary is loading
    @Published public private(set) var isLoading = true

    /// Error message if loading failed
    @Published public private(set) var errorMessage: String?

    /// Statistics about the glossary
    @Published public private(set) var statistics: GlossaryStatistics?

    // MARK: - Private Properties

    private let glossaryService: GlossaryService
    private let logger = Logger(
        subsystem: AppConfiguration.AppInfo.bundleIdentifier,
        category: "GlossaryBrowserViewModel"
    )

    // MARK: - Initialization

    /// Initialize with glossary service
    public init(glossaryService: GlossaryService) {
        self.glossaryService = glossaryService
    }

    // MARK: - Public Methods

    /// Load the glossary
    public func loadGlossary() async {
        isLoading = true
        errorMessage = nil

        do {
            try await glossaryService.loadGlossary()
            allEntries = await glossaryService.allTerms()
            statistics = await glossaryService.statistics()
            filterEntries()

            logger.info("Loaded \(self.allEntries.count) glossary entries")
        } catch {
            logger.error("Failed to load glossary: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    /// Search for terms
    /// - Parameter query: The search query
    public func search(query: String) async {
        searchText = query
        // Filtering happens via didSet
    }

    /// Filter by category
    /// - Parameter category: The category to filter by (nil for all)
    public func filterByCategory(_ category: TermCategory?) {
        selectedCategory = category
        // Filtering happens via didSet
    }

    /// Clear all filters
    public func clearFilters() {
        searchText = ""
        selectedCategory = nil
    }

    /// Get entries grouped by first letter
    public var groupedEntries: [(letter: String, entries: [GlossaryEntry])] {
        let grouped = Dictionary(grouping: filteredEntries) { entry -> String in
            let firstChar = entry.title.first.map(String.init)?.uppercased() ?? "#"
            return firstChar.first?.isLetter == true ? firstChar : "#"
        }

        return grouped
            .map { (letter: $0.key, entries: $0.value) }
            .sorted { $0.letter < $1.letter }
    }

    /// Get entry count by category
    public var categoryStats: [(category: TermCategory, count: Int)] {
        TermCategory.allCases.compactMap { category in
            let count = allEntries.filter { $0.category == category }.count
            return count > 0 ? (category: category, count: count) : nil
        }
    }

    // MARK: - Private Methods

    private func filterEntries() {
        var result = allEntries

        // Apply category filter
        if let category = selectedCategory {
            result = result.filter { $0.category == category }
        }

        // Apply search filter
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter { entry in
                entry.title.lowercased().contains(query) ||
                entry.simpleText.lowercased().contains(query) ||
                entry.analogy?.lowercased().contains(query) == true
            }
        }

        // Sort alphabetically
        filteredEntries = result.sorted {
            $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
        }
    }
}

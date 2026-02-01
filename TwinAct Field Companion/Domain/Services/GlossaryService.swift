//
//  GlossaryService.swift
//  TwinAct Field Companion
//
//  Service for looking up glossary terms with local-first approach and LLM fallback.
//

import Foundation
import os.log

// MARK: - Glossary Service

/// Actor-based service for glossary term lookups.
/// Uses local glossary first, then cached LLM responses, then generates new explanations on demand.
public actor GlossaryService {

    // MARK: - Properties

    /// Local glossary entries loaded from bundled JSON
    private var localGlossary: [String: GlossaryEntry] = [:]

    /// Dynamically generated and cached entries from LLM
    private var dynamicCache: [String: GlossaryEntry] = [:]

    /// Ordered cache keys for eviction (oldest first)
    private var dynamicCacheOrder: [String] = []

    /// Term aliases for flexible matching (e.g., "CO2" -> "co2_equivalent")
    private var termAliases: [String: String] = [:]

    /// LLM orchestrator for fallback generation
    private let inferenceRouter: InferenceRouter

    /// Logger for debugging
    private let logger = Logger(
        subsystem: AppConfiguration.AppInfo.bundleIdentifier,
        category: "GlossaryService"
    )

    /// Whether LLM fallback is enabled
    private let enableLLMFallback: Bool

    /// Maximum cached dynamic entries
    private let maxCachedTerms: Int

    // MARK: - Initialization

    /// Initialize glossary service
    /// - Parameters:
    ///   - inferenceRouter: Router for LLM generation fallback
    ///   - enableLLMFallback: Whether to generate explanations for unknown terms
    ///   - maxCachedTerms: Maximum number of dynamically cached entries
    public init(
        inferenceRouter: InferenceRouter,
        enableLLMFallback: Bool = true,
        maxCachedTerms: Int = 200
    ) {
        self.inferenceRouter = inferenceRouter
        self.enableLLMFallback = enableLLMFallback
        self.maxCachedTerms = maxCachedTerms
    }

    /// Load glossary from bundled JSON file
    public func loadGlossary() async throws {
        guard let url = Bundle.main.url(forResource: "glossary", withExtension: "json") else {
            logger.error("glossary.json not found in bundle")
            throw GlossaryError.fileNotFound
        }

        do {
            let data = try Data(contentsOf: url)
            let glossaryFile = try JSONDecoder().decode(GlossaryFile.self, from: data)

            // Index entries by ID
            localGlossary = Dictionary(
                uniqueKeysWithValues: glossaryFile.entries.map { ($0.id, $0) }
            )

            // Build alias map for flexible matching
            buildAliasMap()

            logger.info("Loaded \(glossaryFile.entries.count) glossary entries (v\(glossaryFile.version))")
        } catch {
            logger.error("Failed to load glossary: \(error.localizedDescription)")
            throw GlossaryError.parseError(error)
        }
    }

    // MARK: - Lookup

    /// Look up a term explanation
    /// - Parameters:
    ///   - term: The term to explain
    ///   - context: Optional context to improve LLM explanation
    /// - Returns: Glossary entry with explanation
    public func explain(term: String, context: String? = nil) async throws -> GlossaryEntry {
        let normalizedTerm = normalizeTerm(term)

        // 1. Try local glossary first
        if let entry = localGlossary[normalizedTerm] {
            logger.debug("Found local entry for: \(term)")
            return entry
        }

        // 2. Try alias lookup
        if let aliasTarget = termAliases[normalizedTerm],
           let entry = localGlossary[aliasTarget] {
            logger.debug("Found alias entry for: \(term) -> \(aliasTarget)")
            return entry
        }

        // 3. Try dynamic cache
        if let cached = dynamicCache[normalizedTerm] {
            logger.debug("Found cached entry for: \(term)")
            return cached
        }

        // 4. Generate using LLM if enabled
        guard enableLLMFallback else {
            throw GlossaryError.termNotFound(term)
        }

        return try await generateExplanation(term: term, context: context)
    }

    /// Quick lookup without LLM fallback
    public func quickLookup(term: String) -> GlossaryEntry? {
        let normalizedTerm = normalizeTerm(term)

        if let entry = localGlossary[normalizedTerm] {
            return entry
        }

        if let aliasTarget = termAliases[normalizedTerm],
           let entry = localGlossary[aliasTarget] {
            return entry
        }

        return dynamicCache[normalizedTerm]
    }

    // MARK: - Term Identification

    /// Identify glossary terms in a text block
    /// - Parameter text: Text to scan for glossary terms
    /// - Returns: Array of identified terms with positions
    public func identifyTerms(in text: String) -> [IdentifiedTerm] {
        var identified: [IdentifiedTerm] = []
        // Check each glossary entry title
        for entry in localGlossary.values {
            // Try the title first
            if let range = findTermRange(entry.title, in: text) {
                identified.append(IdentifiedTerm(
                    termId: entry.id,
                    matchedText: String(text[range]),
                    range: range
                ))
            }
        }

        // Also check aliases
        for (alias, targetId) in termAliases {
            // Skip if we already found the main term
            if identified.contains(where: { $0.termId == targetId }) {
                continue
            }

            // Convert alias back to display form
            let displayAlias = alias.replacingOccurrences(of: "_", with: " ")
            if let range = findTermRange(displayAlias, in: text) {
                identified.append(IdentifiedTerm(
                    termId: targetId,
                    matchedText: String(text[range]),
                    range: range
                ))
            }
        }

        // Sort by position (earliest first) and remove overlaps
        return removeOverlappingTerms(identified.sorted {
            $0.range.lowerBound < $1.range.lowerBound
        })
    }

    /// Find a term range using word boundaries
    private func findTermRange(_ term: String, in text: String) -> Range<String.Index>? {
        // Use word boundary matching with case-insensitive search on the original string.
        var searchStart = text.startIndex

        while let range = text.range(
            of: term,
            options: [.caseInsensitive, .diacriticInsensitive],
            range: searchStart..<text.endIndex
        ) {
            // Check for word boundaries
            let isStartBoundary = range.lowerBound == text.startIndex ||
                !text[text.index(before: range.lowerBound)].isLetter

            let isEndBoundary = range.upperBound == text.endIndex ||
                !text[range.upperBound].isLetter

            if isStartBoundary && isEndBoundary {
                return range
            }

            searchStart = range.upperBound
        }

        return nil
    }

    /// Remove overlapping identified terms, keeping longer matches
    private func removeOverlappingTerms(_ terms: [IdentifiedTerm]) -> [IdentifiedTerm] {
        var result: [IdentifiedTerm] = []

        for term in terms {
            // Check if this term overlaps with any already added
            let overlaps = result.contains { existing in
                existing.range.overlaps(term.range)
            }

            if !overlaps {
                result.append(term)
            }
        }

        return result
    }

    // MARK: - Browse

    /// Get all available terms, optionally filtered by category
    /// - Parameter category: Optional category filter
    /// - Returns: Array of glossary entries
    public func allTerms(category: TermCategory? = nil) -> [GlossaryEntry] {
        var entries = Array(localGlossary.values)

        // Add cached dynamic entries
        entries.append(contentsOf: dynamicCache.values)

        // Filter by category if specified
        if let category = category {
            entries = entries.filter { $0.category == category }
        }

        // Sort alphabetically by title
        return entries.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    /// Search for terms matching a query
    /// - Parameter query: Search query
    /// - Returns: Matching glossary entries
    public func search(query: String) -> [GlossaryEntry] {
        let lowercasedQuery = query.lowercased()

        return allTerms().filter { entry in
            entry.title.lowercased().contains(lowercasedQuery) ||
            entry.simpleText.lowercased().contains(lowercasedQuery) ||
            entry.analogy?.lowercased().contains(lowercasedQuery) == true
        }
    }

    /// Get related terms for a given entry
    /// - Parameter entry: The glossary entry
    /// - Returns: Array of related entries
    public func relatedTerms(for entry: GlossaryEntry) -> [GlossaryEntry] {
        guard let relatedIds = entry.relatedTerms else { return [] }

        return relatedIds.compactMap { id in
            localGlossary[id] ?? dynamicCache[id]
        }
    }

    // MARK: - LLM Generation

    private func generateExplanation(term: String, context: String?) async throws -> GlossaryEntry {
        logger.info("Generating LLM explanation for: \(term)")

        let prompt = GlossaryPrompts.buildExplanationPrompt(term: term, context: context)

        let options = GenerationOptions(
            maxTokens: 150,
            temperature: 0.5,
            systemPrompt: GlossaryPrompts.systemPrompt
        )

        let result = try await inferenceRouter.generate(prompt: prompt, options: options)

        // Parse JSON response
        guard let entry = parseGlossaryResponse(result.text, term: term, provider: result.provider.rawValue) else {
            throw GlossaryError.invalidLLMResponse
        }

        // Cache the entry
        await cacheEntry(entry)

        return entry
    }

    private func parseGlossaryResponse(_ response: String, term: String, provider: String) -> GlossaryEntry? {
        // Try to extract JSON from response
        let jsonPattern = #"\{[\s\S]*\}"#
        guard let jsonRange = response.range(of: jsonPattern, options: .regularExpression),
              let data = String(response[jsonRange]).data(using: .utf8) else {
            // Fallback: create entry from plain text response
            return GlossaryEntry(
                id: normalizeTerm(term),
                title: term,
                simpleText: response.trimmingCharacters(in: .whitespacesAndNewlines),
                icon: "questionmark.circle.fill",
                category: inferCategory(for: term),
                source: .llm(provider: provider)
            )
        }

        do {
            let llmResponse = try JSONDecoder().decode(GlossaryLLMResponse.self, from: data)
            return llmResponse.toEntry(
                id: normalizeTerm(term),
                category: inferCategory(for: term),
                provider: provider
            )
        } catch {
            logger.warning("Failed to parse LLM JSON response: \(error.localizedDescription)")
            return nil
        }
    }

    private func cacheEntry(_ entry: GlossaryEntry) async {
        // Enforce cache size limit
        while dynamicCache.count >= maxCachedTerms, let oldestKey = dynamicCacheOrder.first {
            dynamicCacheOrder.removeFirst()
            dynamicCache.removeValue(forKey: oldestKey)
        }

        // Add to cache with cached source
        let cachedEntry = GlossaryEntry(
            id: entry.id,
            title: entry.title,
            simpleText: entry.simpleText,
            analogy: entry.analogy,
            icon: entry.icon,
            category: entry.category,
            relatedTerms: entry.relatedTerms,
            semanticId: entry.semanticId,
            source: .cached
        )

        if let existingIndex = dynamicCacheOrder.firstIndex(of: entry.id) {
            dynamicCacheOrder.remove(at: existingIndex)
        }
        dynamicCacheOrder.append(entry.id)
        dynamicCache[entry.id] = cachedEntry
        logger.debug("Cached glossary entry: \(entry.id)")
    }

    // MARK: - Helpers

    private func normalizeTerm(_ term: String) -> String {
        term.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "-", with: "_")
    }

    private func buildAliasMap() {
        // Common aliases and abbreviations
        let aliases: [(alias: String, target: String)] = [
            // Carbon footprint abbreviations
            ("co2", "co2_equivalent"),
            ("co2eq", "co2_equivalent"),
            ("ghg", "greenhouse_gas"),
            ("lca", "life_cycle_assessment"),

            // Battery terms
            ("soh", "state_of_health"),
            ("kwh", "kilowatt_hour"),

            // Compliance abbreviations
            ("dpp", "digital_product_passport"),

            // Technical terms
            ("api", "api"),

            // Alternative phrasings
            ("product_passport", "digital_product_passport"),
            ("battery_health", "state_of_health"),
            ("carbon_emissions", "carbon_footprint"),
            ("recycling", "recyclability"),
            ("recycle", "recyclability"),
        ]

        for (alias, target) in aliases {
            termAliases[alias] = target
        }

        // Also add normalized versions of all entry titles as aliases
        for entry in localGlossary.values {
            let normalizedTitle = normalizeTerm(entry.title)
            if normalizedTitle != entry.id {
                termAliases[normalizedTitle] = entry.id
            }
        }
    }

    private func inferCategory(for term: String) -> TermCategory {
        let lowercased = term.lowercased()

        // Simple keyword-based categorization for LLM-generated entries
        if lowercased.contains("carbon") || lowercased.contains("co2") ||
           lowercased.contains("recycl") || lowercased.contains("sustain") ||
           lowercased.contains("footprint") || lowercased.contains("emission") {
            return .sustainability
        }

        if lowercased.contains("battery") || lowercased.contains("charge") ||
           lowercased.contains("cell") || lowercased.contains("voltage") {
            return .battery
        }

        if lowercased.contains("eu") || lowercased.contains("regulation") ||
           lowercased.contains("compliance") || lowercased.contains("law") ||
           lowercased.contains("directive") {
            return .compliance
        }

        if lowercased.contains("serial") || lowercased.contains("batch") ||
           lowercased.contains("manufactur") || lowercased.contains("production") {
            return .manufacturing
        }

        return .technical
    }

    // MARK: - Statistics

    /// Get glossary statistics
    public func statistics() -> GlossaryStatistics {
        var categoryCounts: [TermCategory: Int] = [:]

        for entry in localGlossary.values {
            categoryCounts[entry.category, default: 0] += 1
        }

        return GlossaryStatistics(
            totalLocalTerms: localGlossary.count,
            totalCachedTerms: dynamicCache.count,
            categoryCounts: categoryCounts,
            aliasCount: termAliases.count
        )
    }
}

// MARK: - Glossary Statistics

/// Statistics about the glossary
public struct GlossaryStatistics: Sendable {
    public let totalLocalTerms: Int
    public let totalCachedTerms: Int
    public let categoryCounts: [TermCategory: Int]
    public let aliasCount: Int

    public var totalTerms: Int {
        totalLocalTerms + totalCachedTerms
    }
}

// MARK: - Glossary Errors

/// Errors that can occur during glossary operations
public enum GlossaryError: Error, LocalizedError {
    case fileNotFound
    case parseError(Error)
    case termNotFound(String)
    case invalidLLMResponse
    case llmGenerationFailed(Error)

    public var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "Glossary file not found in bundle"
        case .parseError(let error):
            return "Failed to parse glossary: \(error.localizedDescription)"
        case .termNotFound(let term):
            return "Term not found: \(term)"
        case .invalidLLMResponse:
            return "Could not parse LLM response"
        case .llmGenerationFailed(let error):
            return "LLM generation failed: \(error.localizedDescription)"
        }
    }
}

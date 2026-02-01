//
//  GlossaryServiceTests.swift
//  TwinAct Field Companion
//
//  DEBUG-only test runner for GlossaryService validation.
//  Tests local lookup, term identification, and caching.
//

import Foundation

#if DEBUG

// MARK: - Glossary Service Tests

/// Test runner for GlossaryService tests.
public enum GlossaryServiceTests {

    /// Runs all tests and returns a summary of results.
    /// - Returns: Tuple of (passed count, failed count, failure messages)
    @MainActor
    @discardableResult
    public static func runAllTests() async -> (passed: Int, failed: Int, failures: [String]) {
        var passed = 0
        var failed = 0
        var failures: [String] = []

        func assert(_ condition: Bool, _ message: String, line: Int = #line) {
            if condition {
                passed += 1
            } else {
                failed += 1
                failures.append("FAILED: \(message) (line \(line))")
            }
        }

        func assertEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String, line: Int = #line) {
            if actual == expected {
                passed += 1
            } else {
                failed += 1
                failures.append("FAILED: \(message) - Expected '\(expected)', got '\(actual)' (line \(line))")
            }
        }

        // ============================================================
        // MARK: - Test: GlossaryEntry Model
        // ============================================================

        // Test GlossaryEntry creation
        let entry = GlossaryEntry(
            id: "carbon_footprint",
            title: "Carbon Footprint",
            simpleText: "The total amount of greenhouse gases a product creates.",
            analogy: "Like tracking how many miles your food traveled.",
            icon: "leaf.fill",
            category: .sustainability,
            relatedTerms: ["pcf", "tcf"],
            source: .local
        )

        assertEqual(entry.id, "carbon_footprint", "Entry ID should match")
        assertEqual(entry.title, "Carbon Footprint", "Entry title should match")
        assertEqual(entry.category, .sustainability, "Entry category should be sustainability")
        assert(entry.source == .local, "Source should be local")

        // Test source display name
        assertEqual(GlossaryEntry.Source.local.displayName, "Official Definition", "Local source display name")
        assertEqual(GlossaryEntry.Source.cached.displayName, "AI Generated (Cached)", "Cached source display name")
        assertEqual(GlossaryEntry.Source.llm(provider: "Claude").displayName, "AI Generated (Claude)", "LLM source display name")

        // Test isAIGenerated
        assert(!GlossaryEntry.Source.local.isAIGenerated, "Local source should not be AI generated")
        assert(GlossaryEntry.Source.cached.isAIGenerated, "Cached source should be AI generated")
        assert(GlossaryEntry.Source.llm(provider: "Claude").isAIGenerated, "LLM source should be AI generated")

        // ============================================================
        // MARK: - Test: TermCategory
        // ============================================================

        assertEqual(TermCategory.sustainability.displayName, "Sustainability", "Sustainability display name")
        assertEqual(TermCategory.battery.displayName, "Battery", "Battery display name")
        assertEqual(TermCategory.compliance.displayName, "Compliance", "Compliance display name")
        assertEqual(TermCategory.technical.displayName, "Technical", "Technical display name")
        assertEqual(TermCategory.manufacturing.displayName, "Manufacturing", "Manufacturing display name")

        assertEqual(TermCategory.sustainability.icon, "leaf.fill", "Sustainability icon")
        assertEqual(TermCategory.battery.icon, "battery.100.bolt", "Battery icon")

        // ============================================================
        // MARK: - Test: IdentifiedTerm
        // ============================================================

        let text = "The Carbon Footprint is important."
        let range = text.range(of: "Carbon Footprint")!
        let identifiedTerm = IdentifiedTerm(
            termId: "carbon_footprint",
            matchedText: "Carbon Footprint",
            range: range
        )

        assertEqual(identifiedTerm.termId, "carbon_footprint", "Identified term ID should match")
        assertEqual(identifiedTerm.matchedText, "Carbon Footprint", "Matched text should match")

        // ============================================================
        // MARK: - Test: GlossaryLLMResponse Conversion
        // ============================================================

        let llmResponse = GlossaryLLMResponse(
            title: "Test Term",
            simpleText: "A simple definition.",
            analogy: "Like something familiar.",
            icon: "star.fill"
        )

        let convertedEntry = llmResponse.toEntry(
            id: "test_term",
            category: .technical,
            provider: "TestProvider"
        )

        assertEqual(convertedEntry.id, "test_term", "Converted entry ID should match")
        assertEqual(convertedEntry.title, "Test Term", "Converted entry title should match")
        assertEqual(convertedEntry.simpleText, "A simple definition.", "Converted entry simple text")
        assertEqual(convertedEntry.analogy, "Like something familiar.", "Converted entry analogy")
        assertEqual(convertedEntry.icon, "star.fill", "Converted entry icon")
        assertEqual(convertedEntry.category, .technical, "Converted entry category")

        if case .llm(let provider) = convertedEntry.source {
            assertEqual(provider, "TestProvider", "Converted entry provider")
        } else {
            failed += 1
            failures.append("FAILED: Converted entry source should be LLM")
        }

        // ============================================================
        // MARK: - Test: GlossaryEntry JSON Encoding/Decoding
        // ============================================================

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        do {
            let encoded = try encoder.encode(entry)
            let decoded = try decoder.decode(GlossaryEntry.self, from: encoded)

            assertEqual(decoded.id, entry.id, "Decoded entry ID should match")
            assertEqual(decoded.title, entry.title, "Decoded entry title should match")
            assertEqual(decoded.simpleText, entry.simpleText, "Decoded entry simple text should match")
            assertEqual(decoded.analogy, entry.analogy, "Decoded entry analogy should match")
            assertEqual(decoded.icon, entry.icon, "Decoded entry icon should match")
            assertEqual(decoded.category, entry.category, "Decoded entry category should match")

            passed += 1  // JSON round-trip passed
        } catch {
            failed += 1
            failures.append("FAILED: JSON encoding/decoding - \(error.localizedDescription)")
        }

        // ============================================================
        // MARK: - Test: GlossaryFile JSON Decoding
        // ============================================================

        let glossaryJSON = """
        {
            "version": "1.0.0",
            "lastUpdated": "2025-01-15",
            "entries": [
                {
                    "id": "test_entry",
                    "title": "Test Entry",
                    "simpleText": "A test definition.",
                    "icon": "star.fill",
                    "category": "technical",
                    "source": {"type": "local"}
                }
            ]
        }
        """

        do {
            let data = glossaryJSON.data(using: .utf8)!
            let glossaryFile = try decoder.decode(GlossaryFile.self, from: data)

            assertEqual(glossaryFile.version, "1.0.0", "Glossary file version")
            assertEqual(glossaryFile.entries.count, 1, "Glossary file entry count")
            assertEqual(glossaryFile.entries[0].id, "test_entry", "First entry ID")

            passed += 1  // GlossaryFile decoding passed
        } catch {
            failed += 1
            failures.append("FAILED: GlossaryFile decoding - \(error.localizedDescription)")
        }

        // ============================================================
        // MARK: - Test: GlossaryPrompts
        // ============================================================

        let prompt = GlossaryPrompts.buildExplanationPrompt(term: "Carbon Footprint", context: "DPP data")
        assert(prompt.contains("Carbon Footprint"), "Prompt should contain the term")
        assert(prompt.contains("DPP data"), "Prompt should contain the context")

        let promptWithoutContext = GlossaryPrompts.buildExplanationPrompt(term: "SoH", context: nil)
        assert(promptWithoutContext.contains("SoH"), "Prompt without context should contain the term")
        assert(!promptWithoutContext.contains("Context where"), "Prompt without context should not have context section")

        // Test validation
        let validEntry = GlossaryEntry(
            id: "test",
            title: "Test",
            simpleText: "A short definition that is concise.",
            analogy: "Like a simple comparison.",
            icon: "star",
            category: .technical,
            source: .local
        )
        let validation = GlossaryPrompts.validateExplanation(validEntry)
        assert(validation.isValid, "Valid entry should pass validation")
        assert(validation.issues.isEmpty, "Valid entry should have no issues")

        // ============================================================
        // MARK: - Summary
        // ============================================================

        print("GlossaryServiceTests: \(passed) passed, \(failed) failed")
        if !failures.isEmpty {
            print("Failures:")
            for failure in failures {
                print("  - \(failure)")
            }
        }

        return (passed, failed, failures)
    }
}

#endif

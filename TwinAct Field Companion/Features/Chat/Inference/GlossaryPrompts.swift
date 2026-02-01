//
//  GlossaryPrompts.swift
//  TwinAct Field Companion
//
//  LLM prompt templates for generating consumer-friendly term explanations.
//

import Foundation

// MARK: - Glossary Prompts

/// Prompt templates for glossary term explanation generation
public enum GlossaryPrompts {

    // MARK: - System Prompt

    /// System prompt for glossary explanation generation
    public static let systemPrompt = """
    You are a friendly science translator for a Digital Product Passport app.
    Your job is to explain complex sustainability and technical terms to a 12-year-old using simple language and real-world analogies.

    RULES:
    1. Use ONE sentence for the definition (maximum 20 words)
    2. Use ONE sentence for the analogy (maximum 25 words)
    3. Never use jargon or technical terms in your explanation
    4. Relate analogies to everyday objects: cars, food, sports, school, games
    5. Be accurate but prioritize clarity over precision
    6. Use active voice and present tense
    7. Avoid words like "basically", "essentially", "simply"

    Always respond with valid JSON in exactly this format:
    {
      "title": "Simple 2-3 word title",
      "simpleText": "Your one-sentence definition here",
      "analogy": "Your real-world comparison here",
      "icon": "suggested_sf_symbol_name"
    }

    Common SF Symbol suggestions:
    - Sustainability: leaf.fill, drop.fill, arrow.3.trianglepath
    - Battery: battery.100, bolt.fill
    - Technical: cpu.fill, gear, wrench.fill
    - Compliance: checkmark.shield.fill, building.columns.fill
    - Manufacturing: hammer.fill, shippingbox.fill
    """

    // MARK: - Build Prompt

    /// Build the explanation prompt for a specific term
    /// - Parameters:
    ///   - term: The term to explain
    ///   - context: Optional context about where the term appears
    /// - Returns: Formatted prompt string
    public static func buildExplanationPrompt(term: String, context: String?) -> String {
        var prompt = """
        Explain this Digital Product Passport term in simple language:

        Term: "\(term)"
        """

        if let context = context, !context.isEmpty {
            prompt += """

            Context where this term appears:
            "\(context)"
            """
        }

        prompt += """

        Remember to respond with valid JSON only.
        """

        return prompt
    }

    // MARK: - Preset Options

    /// Generation options optimized for glossary explanations
    public static var generationOptions: GenerationOptions {
        GenerationOptions(
            maxTokens: 150,
            temperature: 0.5,
            stopSequences: ["\n\n", "```"],
            systemPrompt: systemPrompt
        )
    }
}

// MARK: - Sample Prompts for Testing

extension GlossaryPrompts {

    /// Sample prompts for testing the glossary generation
    public static let samplePrompts: [(term: String, context: String?)] = [
        ("Scope 3 Emissions", "Total carbon footprint including Scope 3 emissions"),
        ("Battery Impedance", "Impedance measured at 1kHz: 2.5 mΩ"),
        ("EPD", "Environmental Product Declaration (EPD) available"),
        ("Circular Economy Score", nil),
        ("GWP100", "GWP100 value for carbon calculation"),
    ]

    /// Validate a term explanation against quality criteria
    public static func validateExplanation(_ entry: GlossaryEntry) -> (isValid: Bool, issues: [String]) {
        var issues: [String] = []

        // Check simple text length
        let wordCount = entry.simpleText
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .count

        if wordCount > 25 {
            issues.append("Definition is too long (\(wordCount) words, max 25)")
        }

        // Check for jargon
        let jargonTerms = ["utilize", "leverage", "synergy", "paradigm", "methodology"]
        let lowercased = entry.simpleText.lowercased()
        for jargon in jargonTerms {
            if lowercased.contains(jargon) {
                issues.append("Contains jargon: '\(jargon)'")
            }
        }

        // Check analogy if present
        if let analogy = entry.analogy {
            let analogyWordCount = analogy
                .components(separatedBy: .whitespacesAndNewlines)
                .filter { !$0.isEmpty }
                .count

            if analogyWordCount > 30 {
                issues.append("Analogy is too long (\(analogyWordCount) words, max 30)")
            }
        }

        return (issues.isEmpty, issues)
    }
}

//
//  HighlightedTermText.swift
//  TwinAct Field Companion
//
//  SwiftUI component that renders text with tappable highlighted glossary terms.
//

import SwiftUI

// MARK: - Highlighted Term Text

/// A text view that highlights and makes glossary terms tappable.
///
/// This component scans text for known glossary terms and renders them
/// as tappable links that can trigger the Jargon Buster sheet.
///
/// Example:
/// ```swift
/// HighlightedTermText(
///     text: "The Carbon Footprint includes PCF and TCF measurements.",
///     glossaryService: glossaryService,
///     onTermTapped: { entry in
///         selectedTerm = entry
///     }
/// )
/// ```
public struct HighlightedTermText: View {

    // MARK: - Properties

    /// The text to display with highlighted terms
    let text: String

    /// The glossary service for term lookup
    let glossaryService: GlossaryService

    /// Callback when a term is tapped
    let onTermTapped: (GlossaryEntry) -> Void

    /// Font for the text
    var font: Font = .body

    /// Color for regular text
    var textColor: Color = .primary

    /// Color for highlighted terms
    var highlightColor: Color = .accentColor

    /// Whether to show underlines on highlighted terms
    var showUnderline: Bool = true

    // MARK: - State

    @State private var identifiedTerms: [IdentifiedTerm] = []
    @State private var termEntries: [String: GlossaryEntry] = [:]

    // MARK: - Initialization

    /// Initialize with text and glossary service
    /// - Parameters:
    ///   - text: Text to display and scan for terms
    ///   - glossaryService: Service for term lookup
    ///   - onTermTapped: Callback when a highlighted term is tapped
    public init(
        text: String,
        glossaryService: GlossaryService,
        onTermTapped: @escaping (GlossaryEntry) -> Void
    ) {
        self.text = text
        self.glossaryService = glossaryService
        self.onTermTapped = onTermTapped
    }

    // MARK: - Body

    public var body: some View {
        buildAttributedText()
            .font(font)
            .task {
                await identifyAndLoadTerms()
            }
    }

    // MARK: - Private Methods

    @ViewBuilder
    private func buildAttributedText() -> some View {
        if identifiedTerms.isEmpty {
            // No terms identified, render as plain text
            Text(text)
                .foregroundColor(textColor)
        } else {
            // Build text with highlighted terms
            buildHighlightedText()
        }
    }

    private func buildHighlightedText() -> Text {
        var attributed = AttributedString(text)
        attributed.foregroundColor = textColor

        for term in identifiedTerms {
            guard let range = Range(term.range, in: attributed) else { continue }
            attributed[range].foregroundColor = highlightColor
            if showUnderline {
                attributed[range].underlineStyle = .single
            }
        }

        return Text(attributed)
    }

    private func identifyAndLoadTerms() async {
        // Identify terms in the text
        let terms = await glossaryService.identifyTerms(in: text)
        identifiedTerms = terms

        // Pre-load entries for quick lookup
        for term in terms {
            if let entry = await glossaryService.quickLookup(term: term.termId) {
                termEntries[term.termId] = entry
            }
        }
    }
}

// MARK: - Tappable Highlighted Term Text

/// A version of HighlightedTermText that makes terms tappable using gesture recognizers.
/// This provides the full interactive experience with tap targets.
public struct TappableHighlightedText: View {

    // MARK: - Properties

    let text: String
    let glossaryService: GlossaryService
    let onTermTapped: (GlossaryEntry) -> Void

    var font: Font = .body
    var textColor: Color = .primary
    var highlightColor: Color = .accentColor

    // MARK: - State

    @State private var identifiedTerms: [IdentifiedTerm] = []
    @State private var termEntries: [String: GlossaryEntry] = [:]

    // MARK: - Initialization

    public init(
        text: String,
        glossaryService: GlossaryService,
        onTermTapped: @escaping (GlossaryEntry) -> Void
    ) {
        self.text = text
        self.glossaryService = glossaryService
        self.onTermTapped = onTermTapped
    }

    // MARK: - Body

    public var body: some View {
        TermFlowLayout(spacing: 4) {
            ForEach(buildSegments(), id: \.id) { segment in
                segmentView(for: segment)
            }
        }
        .task {
            await identifyAndLoadTerms()
        }
    }

    // MARK: - Segment Views

    @ViewBuilder
    private func segmentView(for segment: TextSegment) -> some View {
        switch segment.type {
        case .plain:
            Text(segment.text)
                .font(font)
                .foregroundColor(textColor)

        case .term(let termId):
            if let entry = termEntries[termId] {
                Button {
                    onTermTapped(entry)
                } label: {
                    HStack(spacing: 2) {
                        Image(systemName: entry.icon)
                            .font(.caption2)
                        Text(segment.text)
                    }
                    .font(font)
                    .foregroundColor(highlightColor)
                    .underline()
                }
                .buttonStyle(.plain)
            } else {
                Text(segment.text)
                    .font(font)
                    .foregroundColor(highlightColor)
                    .underline()
            }
        }
    }

    // MARK: - Segment Building

    private func buildSegments() -> [TextSegment] {
        var segments: [TextSegment] = []
        var currentIndex = text.startIndex
        var segmentId = 0

        for term in identifiedTerms {
            // Add text before this term
            if currentIndex < term.range.lowerBound {
                let prefix = String(text[currentIndex..<term.range.lowerBound])
                if !prefix.isEmpty {
                    segments.append(TextSegment(
                        id: segmentId,
                        text: prefix,
                        type: .plain
                    ))
                    segmentId += 1
                }
            }

            // Add the term
            let termText = String(text[term.range])
            segments.append(TextSegment(
                id: segmentId,
                text: termText,
                type: .term(termId: term.termId)
            ))
            segmentId += 1

            currentIndex = term.range.upperBound
        }

        // Add remaining text
        if currentIndex < text.endIndex {
            let suffix = String(text[currentIndex...])
            if !suffix.isEmpty {
                segments.append(TextSegment(
                    id: segmentId,
                    text: suffix,
                    type: .plain
                ))
            }
        }

        // If no terms were identified, return the whole text as plain
        if segments.isEmpty {
            segments.append(TextSegment(id: 0, text: text, type: .plain))
        }

        return segments
    }

    private func identifyAndLoadTerms() async {
        let terms = await glossaryService.identifyTerms(in: text)
        identifiedTerms = terms

        for term in terms {
            if let entry = await glossaryService.quickLookup(term: term.termId) {
                termEntries[term.termId] = entry
            }
        }
    }
}

// MARK: - Text Segment

/// A segment of text, either plain or a glossary term
private struct TextSegment: Identifiable {
    let id: Int
    let text: String
    let type: SegmentType

    enum SegmentType {
        case plain
        case term(termId: String)
    }
}

// MARK: - Term Flow Layout

/// A flow layout for wrapping term text segments
struct TermFlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)

        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentX + size.width > maxWidth && currentX > 0 {
                // Move to next line
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }

            positions.append(CGPoint(x: currentX, y: currentY))

            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
            totalWidth = max(totalWidth, currentX)
        }

        return (
            CGSize(width: totalWidth, height: currentY + lineHeight),
            positions
        )
    }
}

// MARK: - View Modifiers

extension HighlightedTermText {
    /// Set the font for the text
    public func font(_ font: Font) -> HighlightedTermText {
        var copy = self
        copy.font = font
        return copy
    }

    /// Set the color for regular text
    public func textColor(_ color: Color) -> HighlightedTermText {
        var copy = self
        copy.textColor = color
        return copy
    }

    /// Set the color for highlighted terms
    public func highlightColor(_ color: Color) -> HighlightedTermText {
        var copy = self
        copy.highlightColor = color
        return copy
    }

    /// Set whether to show underlines on highlighted terms
    public func showUnderline(_ show: Bool) -> HighlightedTermText {
        var copy = self
        copy.showUnderline = show
        return copy
    }
}

extension TappableHighlightedText {
    /// Set the font for the text
    public func font(_ font: Font) -> TappableHighlightedText {
        var copy = self
        copy.font = font
        return copy
    }

    /// Set the color for regular text
    public func textColor(_ color: Color) -> TappableHighlightedText {
        var copy = self
        copy.textColor = color
        return copy
    }

    /// Set the color for highlighted terms
    public func highlightColor(_ color: Color) -> TappableHighlightedText {
        var copy = self
        copy.highlightColor = color
        return copy
    }
}

// MARK: - Preview

#if DEBUG
struct HighlightedTermText_Previews: PreviewProvider {
    static var previews: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Highlighted Term Text")
                .font(.headline)

            // These would work with an actual GlossaryService
            Text("The Carbon Footprint includes PCF and TCF measurements.")
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(8)

            Text("Battery State of Health (SoH) indicates remaining capacity.")
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(8)
        }
        .padding()
    }
}
#endif

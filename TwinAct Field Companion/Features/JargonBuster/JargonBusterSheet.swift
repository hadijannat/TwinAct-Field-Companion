//
//  JargonBusterSheet.swift
//  TwinAct Field Companion
//
//  Half-sheet UI for displaying consumer-friendly explanations of DPP terms.
//

import SwiftUI

// MARK: - Jargon Buster Sheet

/// A half-sheet that displays a glossary term explanation.
///
/// Shows the term title, simple definition, real-world analogy,
/// and links to related terms.
///
/// Example:
/// ```swift
/// .sheet(item: $selectedTerm) { entry in
///     JargonBusterSheet(entry: entry, viewModel: jargonBusterVM)
/// }
/// ```
public struct JargonBusterSheet: View {

    // MARK: - Properties

    /// The glossary entry to display
    let entry: GlossaryEntry

    /// View model for navigation to related terms
    @ObservedObject var viewModel: JargonBusterViewModel

    /// Callback when the sheet should dismiss
    var onDismiss: (() -> Void)?

    @Environment(\.dismiss) private var dismiss

    // MARK: - Initialization

    public init(
        entry: GlossaryEntry,
        viewModel: JargonBusterViewModel,
        onDismiss: (() -> Void)? = nil
    ) {
        self.entry = entry
        self.viewModel = viewModel
        self.onDismiss = onDismiss
    }

    // MARK: - Body

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header with icon and title
                    headerView

                    // Source indicator
                    sourceIndicator

                    // Simple definition
                    definitionSection

                    // Analogy (if available)
                    if let analogy = entry.analogy {
                        analogySection(analogy)
                    }

                    // Related terms
                    if !viewModel.relatedTerms.isEmpty {
                        relatedTermsSection
                    }

                    Spacer(minLength: 20)
                }
                .padding()
            }
            .navigationTitle("What's This?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        onDismiss?()
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(spacing: 16) {
            // Category icon
            ZStack {
                Circle()
                    .fill(categoryColor.opacity(0.15))
                    .frame(width: 60, height: 60)

                Image(systemName: entry.icon)
                    .font(.title)
                    .foregroundColor(categoryColor)
            }

            // Title and category
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.title)
                    .font(.title2.bold())
                    .foregroundColor(.primary)

                HStack(spacing: 4) {
                    Image(systemName: entry.category.icon)
                        .font(.caption)
                    Text(entry.category.displayName)
                        .font(.caption)
                }
                .foregroundColor(.secondary)
            }

            Spacer()
        }
    }

    // MARK: - Source Indicator

    private var sourceIndicator: some View {
        HStack(spacing: 6) {
            if entry.source.isAIGenerated {
                Image(systemName: "sparkles")
                    .font(.caption2)
            } else {
                Image(systemName: "checkmark.seal.fill")
                    .font(.caption2)
            }

            Text(entry.source.displayName)
                .font(.caption2)
        }
        .foregroundColor(entry.source.isAIGenerated ? .purple : .green)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(
            (entry.source.isAIGenerated ? Color.purple : Color.green)
                .opacity(0.1)
        )
        .clipShape(Capsule())
    }

    // MARK: - Definition Section

    private var definitionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Simple Definition")

            Text(entry.simpleText)
                .font(.body)
                .foregroundColor(.primary)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Analogy Section

    private func analogySection(_ analogy: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Real-World Analogy")

            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "lightbulb.fill")
                    .font(.title3)
                    .foregroundColor(.yellow)
                    .frame(width: 32)

                Text(analogy)
                    .font(.body)
                    .foregroundColor(.primary)
                    .italic()
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.yellow.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Related Terms Section

    private var relatedTermsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Related Terms")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(viewModel.relatedTerms) { relatedEntry in
                        relatedTermChip(relatedEntry)
                    }
                }
            }
        }
    }

    private func relatedTermChip(_ relatedEntry: GlossaryEntry) -> some View {
        Button {
            Task {
                await viewModel.navigateToRelated(relatedEntry)
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: relatedEntry.icon)
                    .font(.caption)
                Text(relatedEntry.title)
                    .font(.subheadline)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.accentColor.opacity(0.1))
            .foregroundColor(.accentColor)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(.secondary)
            .textCase(.uppercase)
    }

    private var categoryColor: Color {
        switch entry.category {
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

// MARK: - Analogy Card View

/// A standalone card view for displaying analogies.
public struct AnalogyCardView: View {

    let analogy: String
    let icon: String

    public init(analogy: String, icon: String = "lightbulb.fill") {
        self.analogy = analogy
        self.icon = icon
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.yellow)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text("Think of it this way...")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)

                Text(analogy)
                    .font(.body)
                    .foregroundColor(.primary)
                    .italic()
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.yellow.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Loading Jargon Buster Sheet

/// Sheet for when a term is being looked up (loading state).
public struct LoadingJargonBusterSheet: View {

    let termText: String

    @Environment(\.dismiss) private var dismiss

    public init(termText: String) {
        self.termText = termText
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                ProgressView()
                    .scaleEffect(1.5)

                Text("Looking up \"\(termText)\"...")
                    .font(.headline)
                    .foregroundColor(.secondary)

                Spacer()
            }
            .navigationTitle("What's This?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Error Jargon Buster Sheet

/// Sheet for when term lookup failed.
public struct ErrorJargonBusterSheet: View {

    let termText: String
    let errorMessage: String
    let onRetry: () -> Void

    @Environment(\.dismiss) private var dismiss

    public init(termText: String, errorMessage: String, onRetry: @escaping () -> Void) {
        self.termText = termText
        self.errorMessage = errorMessage
        self.onRetry = onRetry
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.orange)

                VStack(spacing: 8) {
                    Text("Couldn't explain \"\(termText)\"")
                        .font(.headline)

                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Button {
                    onRetry()
                } label: {
                    Label("Try Again", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.borderedProminent)

                Spacer()
            }
            .navigationTitle("What's This?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Preview

#if DEBUG
struct JargonBusterSheet_Previews: PreviewProvider {
    static var previews: some View {
        let sampleEntry = GlossaryEntry(
            id: "carbon_footprint",
            title: "Carbon Footprint",
            simpleText: "The total amount of greenhouse gases a product creates from making it to throwing it away.",
            analogy: "Like tracking how many miles your food traveled to reach your plate, but for pollution.",
            icon: "leaf.fill",
            category: .sustainability,
            relatedTerms: ["pcf", "tcf"],
            source: .local
        )

        Group {
            Text("Sheet would appear here")
                .sheet(isPresented: .constant(true)) {
                    // Would need actual JargonBusterViewModel
                    VStack {
                        Text("JargonBusterSheet Preview")
                        Text(sampleEntry.title)
                            .font(.title)
                        Text(sampleEntry.simpleText)
                    }
                    .presentationDetents([.medium])
                }
                .previewDisplayName("Full Sheet")

            AnalogyCardView(analogy: "Like tracking how many miles your food traveled to reach your plate.")
                .padding()
                .previewDisplayName("Analogy Card")

            LoadingJargonBusterSheet(termText: "Carbon Footprint")
                .previewDisplayName("Loading")

            ErrorJargonBusterSheet(
                termText: "Unknown Term",
                errorMessage: "Could not find this term in the glossary.",
                onRetry: {}
            )
            .previewDisplayName("Error")
        }
    }
}
#endif

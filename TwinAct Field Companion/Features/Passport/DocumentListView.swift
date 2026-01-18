//
//  DocumentListView.swift
//  TwinAct Field Companion
//
//  Document list view displaying Handover Documentation per IDTA 02004-1-2.
//  Shows available documents with classification, version, and download options.
//

import SwiftUI

// MARK: - Document List View

/// List of available documentation for an asset.
/// Displays documents categorized by type with download/view options.
public struct DocumentListView: View {

    // MARK: - Properties

    let documents: [Document]
    @State private var selectedDocument: Document?
    @State private var isExpanded: Bool = true
    @State private var searchText: String = ""
    @State private var selectedFilter: DocumentClass?

    // MARK: - Body

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            headerView

            if isExpanded {
                Divider()
                    .padding(.horizontal)

                // Content
                contentView
                    .padding()
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .animation(.easeInOut(duration: 0.2), value: isExpanded)
        .sheet(item: $selectedDocument) { doc in
            DocumentViewerView(document: doc)
        }
    }

    // MARK: - Header View

    private var headerView: some View {
        Button {
            withAnimation {
                isExpanded.toggle()
            }
        } label: {
            HStack {
                // Icon
                Image(systemName: "doc.text.fill")
                    .font(.title3)
                    .foregroundColor(.indigo)
                    .frame(width: 32)

                // Title
                VStack(alignment: .leading, spacing: 2) {
                    Text("Documentation")
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text("\(documents.count) document\(documents.count == 1 ? "" : "s") available")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Expand/collapse indicator
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
        }
        .buttonStyle(.plain)
    }

    // MARK: - Content View

    private var contentView: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Filter chips (if many documents)
            if documents.count > 3 {
                filterChips
            }

            // Document list
            ForEach(filteredDocuments) { doc in
                DocumentRowView(document: doc)
                    .onTapGesture {
                        selectedDocument = doc
                    }

                if doc.id != filteredDocuments.last?.id {
                    Divider()
                }
            }

            // Empty state
            if filteredDocuments.isEmpty && !documents.isEmpty {
                Text("No documents match the selected filter")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            }
        }
    }

    // MARK: - Filter Chips

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(
                    title: "All",
                    isSelected: selectedFilter == nil,
                    count: documents.count
                ) {
                    selectedFilter = nil
                }

                ForEach(uniqueDocumentClasses, id: \.self) { docClass in
                    let count = documents.filter { $0.documentClass == docClass }.count
                    FilterChip(
                        title: docClass.displayName,
                        isSelected: selectedFilter == docClass,
                        count: count
                    ) {
                        selectedFilter = docClass
                    }
                }
            }
        }
    }

    // MARK: - Computed Properties

    private var filteredDocuments: [Document] {
        if let filter = selectedFilter {
            return documents.filter { $0.documentClass == filter }
        }
        return documents
    }

    private var uniqueDocumentClasses: [DocumentClass] {
        Array(Set(documents.map(\.documentClass))).sorted { $0.displayName < $1.displayName }
    }
}

// MARK: - Filter Chip

/// Chip for filtering documents by type.
struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let count: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.caption)

                Text("(\(count))")
                    .font(.caption2)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isSelected ? Color.accentColor : Color(.tertiarySystemBackground))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(16)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Document Row View

/// Single row displaying document information.
struct DocumentRowView: View {
    let document: Document
    @State private var isDownloading = false

    var body: some View {
        HStack(spacing: 12) {
            // Document type icon
            documentIcon

            // Document info
            VStack(alignment: .leading, spacing: 4) {
                Text(document.title.first?.text ?? "Document")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    // Document class badge
                    Text(document.documentClass.displayName)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(documentClassColor.opacity(0.1))
                        .foregroundColor(documentClassColor)
                        .cornerRadius(4)

                    // Version
                    if let version = document.documentVersion {
                        Text("v\(version)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    // Language
                    if let languages = document.language, !languages.isEmpty {
                        Text(languages.joined(separator: ", ").uppercased())
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                // File info
                if let files = document.digitalFile, let file = files.first {
                    HStack(spacing: 4) {
                        Image(systemName: fileTypeIcon(file.fileFormat))
                            .font(.caption2)
                            .foregroundColor(.secondary)

                        if let size = file.formattedFileSize {
                            Text(size)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }

            Spacer()

            // Download/view indicator
            if isDownloading {
                ProgressView()
                    .scaleEffect(0.8)
            } else {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }

    // MARK: - Document Icon

    private var documentIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(documentClassColor.opacity(0.15))
                .frame(width: 44, height: 44)

            Image(systemName: document.documentClass.iconName)
                .font(.title3)
                .foregroundColor(documentClassColor)
        }
    }

    // MARK: - Helpers

    private var documentClassColor: Color {
        switch document.documentClass {
        case .operatingManual:
            return .blue
        case .safetyInstructions:
            return .red
        case .maintenanceInstructions:
            return .orange
        case .certificate, .declaration:
            return .green
        case .technicalDrawing, .circuitDiagram:
            return .purple
        case .datasheet:
            return .teal
        default:
            return .gray
        }
    }

    private func fileTypeIcon(_ mimeType: String) -> String {
        if mimeType.contains("pdf") {
            return "doc.fill"
        } else if mimeType.hasPrefix("image/") {
            return "photo"
        } else if mimeType.hasPrefix("video/") {
            return "video"
        } else if mimeType.contains("word") {
            return "doc.richtext"
        } else if mimeType.contains("excel") || mimeType.contains("spreadsheet") {
            return "tablecells"
        }
        return "doc"
    }
}

// MARK: - Compact Document List

/// Compact version of document list for smaller spaces.
public struct CompactDocumentList: View {
    let documents: [Document]
    let maxVisible: Int
    var onViewAll: (() -> Void)?

    public init(documents: [Document], maxVisible: Int = 3, onViewAll: (() -> Void)? = nil) {
        self.documents = documents
        self.maxVisible = maxVisible
        self.onViewAll = onViewAll
    }

    public var body: some View {
        VStack(spacing: 8) {
            ForEach(documents.prefix(maxVisible)) { doc in
                CompactDocumentRow(document: doc)
            }

            if documents.count > maxVisible {
                Button {
                    onViewAll?()
                } label: {
                    Text("View all \(documents.count) documents")
                        .font(.caption)
                        .foregroundColor(.accentColor)
                }
            }
        }
    }
}

// MARK: - Compact Document Row

/// Compact row for document display.
struct CompactDocumentRow: View {
    let document: Document

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: document.documentClass.iconName)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 20)

            Text(document.title.first?.text ?? "Document")
                .font(.caption)
                .lineLimit(1)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Document Grid View

/// Grid layout for documents.
public struct DocumentGridView: View {
    let documents: [Document]
    let columns: [GridItem]
    @State private var selectedDocument: Document?

    public init(documents: [Document], columns: Int = 2) {
        self.documents = documents
        self.columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: columns)
    }

    public var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(documents) { doc in
                DocumentGridCell(document: doc)
                    .onTapGesture {
                        selectedDocument = doc
                    }
            }
        }
        .sheet(item: $selectedDocument) { doc in
            DocumentViewerView(document: doc)
        }
    }
}

// MARK: - Document Grid Cell

/// Grid cell for document display.
struct DocumentGridCell: View {
    let document: Document

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.tertiarySystemBackground))

                Image(systemName: document.documentClass.iconName)
                    .font(.title)
                    .foregroundColor(.accentColor)
            }
            .frame(height: 60)

            // Title
            Text(document.title.first?.text ?? "Document")
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(2)

            // Class
            Text(document.documentClass.displayName)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(10)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Preview Provider

#if DEBUG
struct DocumentListView_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            VStack(spacing: 20) {
                DocumentListView(
                    documents: [
                        Document(
                            id: "doc-1",
                            title: [LangString(language: "en", text: "Operating Manual v2.1")],
                            documentClass: .operatingManual,
                            documentVersion: "2.1",
                            language: ["en", "de"],
                            digitalFile: [
                                DigitalFile(fileFormat: "application/pdf", file: URL(string: "https://example.com/manual.pdf")!, fileSize: 2_500_000)
                            ]
                        ),
                        Document(
                            id: "doc-2",
                            title: [LangString(language: "en", text: "Safety Instructions")],
                            documentClass: .safetyInstructions,
                            documentVersion: "1.0",
                            language: ["en"]
                        ),
                        Document(
                            id: "doc-3",
                            title: [LangString(language: "en", text: "CE Declaration of Conformity")],
                            documentClass: .certificate,
                            documentVersion: "1.0"
                        ),
                        Document(
                            id: "doc-4",
                            title: [LangString(language: "en", text: "Maintenance Schedule")],
                            documentClass: .maintenanceInstructions,
                            documentVersion: "3.0"
                        )
                    ]
                )

                DocumentGridView(
                    documents: [
                        Document(id: "g1", title: [LangString(language: "en", text: "Datasheet")], documentClass: .datasheet),
                        Document(id: "g2", title: [LangString(language: "en", text: "Wiring Diagram")], documentClass: .circuitDiagram),
                        Document(id: "g3", title: [LangString(language: "en", text: "Quick Start")], documentClass: .assemblyInstructions),
                        Document(id: "g4", title: [LangString(language: "en", text: "Test Report")], documentClass: .testReport)
                    ]
                )
            }
            .padding()
        }
    }
}
#endif

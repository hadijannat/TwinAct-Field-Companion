//
//  ExtractedDocumentListView.swift
//  TwinAct Field Companion
//
//  Enhanced document list view with PDF thumbnail previews.
//  Displays extracted AASX documents with page count and file size.
//

import SwiftUI
import PDFKit
import QuickLook

// MARK: - Extracted Document List View

/// List view for documents extracted from AASX packages.
/// Shows PDF thumbnails, page count, and file size.
public struct ExtractedDocumentListView: View {

    // MARK: - Properties

    let documents: [ExtractedDocument]
    @State private var isExpanded: Bool = true
    @State private var selectedFilter: DocumentCategory?
    @State private var quickLookURL: URL?

    // MARK: - Body

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerView

            if isExpanded {
                Divider()
                    .padding(.horizontal)

                contentView
                    .padding()
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .animation(.easeInOut(duration: 0.2), value: isExpanded)
        .quickLookPreview($quickLookURL)
    }

    // MARK: - Header View

    private var headerView: some View {
        Button {
            withAnimation {
                isExpanded.toggle()
            }
        } label: {
            HStack {
                Image(systemName: "doc.text.fill")
                    .font(.title3)
                    .foregroundColor(.indigo)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Documents")
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text("\(documents.count) document\(documents.count == 1 ? "" : "s") available")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

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
            // Filter chips if many documents
            if documents.count > 3 {
                filterChips
            }

            // Document list
            ForEach(filteredDocuments) { doc in
                ExtractedDocumentRow(document: doc) {
                    quickLookURL = doc.localURL
                }

                if doc.id != filteredDocuments.last?.id {
                    Divider()
                }
            }

            // Empty state for filter
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
                DocumentFilterChip(
                    title: "All",
                    isSelected: selectedFilter == nil,
                    count: documents.count
                ) {
                    selectedFilter = nil
                }

                ForEach(uniqueCategories, id: \.self) { category in
                    let count = documents.filter { $0.category == category }.count
                    DocumentFilterChip(
                        title: category.displayName,
                        isSelected: selectedFilter == category,
                        count: count
                    ) {
                        selectedFilter = category
                    }
                }
            }
        }
    }

    // MARK: - Computed Properties

    private var filteredDocuments: [ExtractedDocument] {
        if let filter = selectedFilter {
            return documents.filter { $0.category == filter }
        }
        return documents
    }

    private var uniqueCategories: [DocumentCategory] {
        Array(Set(documents.map(\.category))).sorted { $0.displayName < $1.displayName }
    }
}

// MARK: - Document Filter Chip

private struct DocumentFilterChip: View {
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

// MARK: - Extracted Document Row

/// Row displaying a single extracted document with thumbnail.
private struct ExtractedDocumentRow: View {
    let document: ExtractedDocument
    let onTap: () -> Void

    @State private var thumbnail: UIImage?
    @State private var pageCount: Int?

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // PDF thumbnail or icon
                thumbnailView

                // Document info
                VStack(alignment: .leading, spacing: 4) {
                    Text(document.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .lineLimit(2)

                    HStack(spacing: 8) {
                        // Category badge
                        Text(document.category.displayName)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(categoryColor.opacity(0.1))
                            .foregroundColor(categoryColor)
                            .cornerRadius(4)

                        // Page count (for PDFs)
                        if let pages = pageCount {
                            Label("\(pages) pages", systemImage: "doc.text")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }

                        // File size
                        if let size = document.formattedFileSize {
                            Text(size)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Spacer()

                // Action indicator
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onAppear {
            loadPDFInfo()
        }
    }

    // MARK: - Thumbnail View

    private var thumbnailView: some View {
        ZStack {
            if let thumb = thumbnail {
                Image(uiImage: thumb)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 50, height: 65)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color(.separator), lineWidth: 0.5)
                    )
            } else {
                // Fallback icon
                RoundedRectangle(cornerRadius: 4)
                    .fill(categoryColor.opacity(0.1))
                    .frame(width: 50, height: 65)
                    .overlay(
                        Image(systemName: document.category.icon)
                            .font(.title2)
                            .foregroundColor(categoryColor)
                    )
            }
        }
    }

    // MARK: - Category Color

    private var categoryColor: Color {
        switch document.category {
        case .manual: return .blue
        case .certificate: return .green
        case .datasheet: return .teal
        case .drawing: return .purple
        case .other: return .gray
        }
    }

    // MARK: - PDF Info Loading

    private func loadPDFInfo() {
        // Only load thumbnail for PDFs
        guard document.mimeType == "application/pdf" else { return }

        DispatchQueue.global(qos: .userInitiated).async {
            guard let pdfDoc = PDFDocument(url: document.localURL) else { return }

            let count = pdfDoc.pageCount

            // Generate thumbnail from first page
            var thumb: UIImage?
            if let page = pdfDoc.page(at: 0) {
                let bounds = page.bounds(for: .cropBox)
                let aspectRatio = bounds.width / bounds.height
                let thumbSize = CGSize(width: 50, height: 50 / aspectRatio)
                thumb = page.thumbnail(of: thumbSize, for: .cropBox)
            }

            DispatchQueue.main.async {
                self.pageCount = count
                self.thumbnail = thumb
            }
        }
    }
}

// Extension for formatted file size
extension ExtractedDocument {
    var formattedFileSize: String? {
        guard let size = fileSize else { return nil }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}

// MARK: - Document Thumbnail Cache

/// Cache for PDF thumbnails to avoid regenerating.
final class DocumentThumbnailCache {
    static let shared = DocumentThumbnailCache()

    private var cache = NSCache<NSString, UIImage>()

    private init() {
        cache.countLimit = 50
    }

    func thumbnail(for url: URL) -> UIImage? {
        return cache.object(forKey: url.absoluteString as NSString)
    }

    func setThumbnail(_ image: UIImage, for url: URL) {
        cache.setObject(image, forKey: url.absoluteString as NSString)
    }
}

// MARK: - Preview Provider

#if DEBUG
struct ExtractedDocumentListView_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            VStack(spacing: 20) {
                ExtractedDocumentListView(documents: [
                    ExtractedDocument(
                        title: "Operating Manual",
                        localURL: URL(fileURLWithPath: "/tmp/manual.pdf"),
                        mimeType: "application/pdf",
                        category: .manual,
                        fileSize: 2_500_000
                    ),
                    ExtractedDocument(
                        title: "CE Certificate",
                        localURL: URL(fileURLWithPath: "/tmp/cert.pdf"),
                        mimeType: "application/pdf",
                        category: .certificate,
                        fileSize: 150_000
                    ),
                    ExtractedDocument(
                        title: "Technical Datasheet",
                        localURL: URL(fileURLWithPath: "/tmp/datasheet.pdf"),
                        mimeType: "application/pdf",
                        category: .datasheet,
                        fileSize: 500_000
                    )
                ])
            }
            .padding()
        }
    }
}
#endif

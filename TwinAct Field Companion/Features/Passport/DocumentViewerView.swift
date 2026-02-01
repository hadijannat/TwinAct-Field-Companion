//
//  DocumentViewerView.swift
//  TwinAct Field Companion
//
//  Full-screen document viewer with PDF rendering and image display support.
//  Handles document loading, caching, and offline viewing.
//

import SwiftUI
import PDFKit
import Combine

// MARK: - Document Viewer View

/// Full-screen document viewer supporting PDF and image formats.
/// Provides loading, viewing, and sharing capabilities.
public struct DocumentViewerView: View {

    // MARK: - Properties

    let document: Document
    @StateObject private var viewModel = DocumentViewerViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showShareSheet = false
    @State private var currentPage: Int = 1
    @State private var totalPages: Int = 1

    // MARK: - Body

    public var body: some View {
        NavigationStack {
            ZStack {
                // Content
                contentView

                // Loading overlay
                if viewModel.isLoading {
                    loadingOverlay
                }
            }
            .navigationTitle(documentTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }

                ToolbarItemGroup(placement: .topBarTrailing) {
                    // Download/offline button
                    if viewModel.canDownloadForOffline && !viewModel.isAvailableOffline {
                        Button {
                            Task {
                                await viewModel.downloadForOffline()
                            }
                        } label: {
                            Image(systemName: "arrow.down.circle")
                        }
                    } else if viewModel.isAvailableOffline {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }

                    // Share button
                    if let shareURL = viewModel.shareURL {
                        ShareLink(item: shareURL) {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
            }
            .task {
                await viewModel.loadDocument(document)
            }
        }
    }

    // MARK: - Content View

    @ViewBuilder
    private var contentView: some View {
        if let error = viewModel.error {
            errorView(error: error)
        } else if let pdfDocument = viewModel.pdfDocument {
            PDFKitView(
                document: pdfDocument,
                currentPage: $currentPage,
                totalPages: $totalPages
            )
            .overlay(alignment: .bottom) {
                pageIndicator
            }
        } else if let image = viewModel.image {
            imageView(image: image)
        } else if !viewModel.isLoading {
            unavailableView
        }
    }

    // MARK: - Document Title

    private var documentTitle: String {
        document.title.first?.text ?? "Document"
    }

    // MARK: - Page Indicator

    private var pageIndicator: some View {
        Group {
            if totalPages > 1 {
                Text("Page \(currentPage) of \(totalPages)")
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(16)
                    .padding(.bottom, 20)
            }
        }
    }

    // MARK: - Image View

    private func imageView(image: UIImage) -> some View {
        ScrollView([.horizontal, .vertical], showsIndicators: true) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color.black)
    }

    // MARK: - Loading Overlay

    private var loadingOverlay: some View {
        ZStack {
            Color(.systemBackground)
                .opacity(0.9)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)

                Text("Loading Document...")
                    .font(.headline)

                if let progress = viewModel.downloadProgress {
                    ProgressView(value: progress)
                        .frame(width: 200)

                    Text("\(Int(progress * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(30)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(16)
        }
    }

    // MARK: - Error View

    private func errorView(error: DocumentViewerError) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundColor(.orange)

            Text("Unable to Load Document")
                .font(.headline)

            Text(error.localizedDescription)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                Button {
                    Task {
                        await viewModel.loadDocument(document)
                    }
                } label: {
                    Label("Try Again", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.borderedProminent)

                if let url = document.digitalFile?.first?.file {
                    Link(destination: url) {
                        Label("Open in Browser", systemImage: "safari")
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding()
    }

    // MARK: - Unavailable View

    private var unavailableView: some View {
        ContentUnavailableView(
            "Document Unavailable",
            systemImage: "doc.slash",
            description: Text("This document could not be loaded. It may be offline or the file may no longer be available.")
        )
    }
}

// MARK: - Document Viewer View Model

/// View model for document viewer handling loading and caching.
@MainActor
public final class DocumentViewerViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published public var isLoading: Bool = false
    @Published public var pdfDocument: PDFDocument?
    @Published public var image: UIImage?
    @Published public var error: DocumentViewerError?
    @Published public var downloadProgress: Double?
    @Published public var isAvailableOffline: Bool = false
    @Published public var canDownloadForOffline: Bool = true
    @Published public var shareURL: URL?

    // MARK: - Private Properties

    private var currentDocument: Document?
    private let cacheDirectory: URL

    // MARK: - Initialization

    public init() {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        self.cacheDirectory = paths[0].appendingPathComponent("DocumentCache", isDirectory: true)

        // Ensure cache directory exists
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    // MARK: - Public Methods

    /// Load a document for viewing.
    /// - Parameter document: The document to load
    public func loadDocument(_ document: Document) async {
        guard !isLoading else { return }

        isLoading = true
        error = nil
        pdfDocument = nil
        image = nil
        currentDocument = document

        defer { isLoading = false }

        guard let file = document.digitalFile?.first else {
            error = .noFileAvailable
            return
        }

        // Check for cached version first
        if let cachedURL = cachedFileURL(for: document.id) {
            if FileManager.default.fileExists(atPath: cachedURL.path) {
                isAvailableOffline = true
                shareURL = cachedURL

                if file.isPDF {
                    if let pdf = PDFDocument(url: cachedURL) {
                        pdfDocument = pdf
                        return
                    }
                } else if file.isImage {
                    if let data = try? Data(contentsOf: cachedURL),
                       let loadedImage = UIImage(data: data) {
                        image = loadedImage
                        return
                    }
                }
            }
        }

        // Download from remote
        do {
            let data = try await downloadFile(from: file.file)

            if file.isPDF {
                guard let pdf = PDFDocument(data: data) else {
                    error = .invalidFormat
                    return
                }
                pdfDocument = pdf
            } else if file.isImage {
                guard let loadedImage = UIImage(data: data) else {
                    error = .invalidFormat
                    return
                }
                image = loadedImage
            } else {
                error = .unsupportedFormat
                return
            }

            // Cache the file
            await cacheFile(data: data, for: document.id, extension: file.isPDF ? "pdf" : "img")

        } catch {
            self.error = DocumentViewerError.from(error)
        }
    }

    /// Download document for offline access.
    public func downloadForOffline() async {
        guard let document = currentDocument,
              let file = document.digitalFile?.first else { return }

        isLoading = true
        downloadProgress = 0

        defer {
            isLoading = false
            downloadProgress = nil
        }

        do {
            let data = try await downloadFile(from: file.file)
            await cacheFile(data: data, for: document.id, extension: file.isPDF ? "pdf" : "img")
            isAvailableOffline = true
            shareURL = cachedFileURL(for: document.id)
        } catch {
            self.error = DocumentViewerError.from(error)
        }
    }

    // MARK: - Private Methods

    private func downloadFile(from url: URL) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw DocumentViewerError.downloadFailed
        }

        return data
    }

    private func cacheFile(data: Data, for id: String, extension ext: String) async {
        let sanitizedId = id.replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
        let fileURL = cacheDirectory.appendingPathComponent("\(sanitizedId).\(ext)")

        do {
            try data.write(to: fileURL)
            shareURL = fileURL
            isAvailableOffline = true
        } catch {
            // Silent fail for caching
        }
    }

    private func cachedFileURL(for id: String) -> URL? {
        let sanitizedId = id.replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")

        // Check for PDF first
        let pdfURL = cacheDirectory.appendingPathComponent("\(sanitizedId).pdf")
        if FileManager.default.fileExists(atPath: pdfURL.path) {
            return pdfURL
        }

        // Check for image
        let imgURL = cacheDirectory.appendingPathComponent("\(sanitizedId).img")
        if FileManager.default.fileExists(atPath: imgURL.path) {
            return imgURL
        }

        return nil
    }
}

// MARK: - Document Viewer Error

/// Errors that can occur in the document viewer.
public enum DocumentViewerError: LocalizedError {
    case noFileAvailable
    case downloadFailed
    case invalidFormat
    case unsupportedFormat
    case networkError(String)
    case unknown(Error)

    public var errorDescription: String? {
        switch self {
        case .noFileAvailable:
            return "No file is available for this document."
        case .downloadFailed:
            return "Failed to download the document. Please check your connection and try again."
        case .invalidFormat:
            return "The document format could not be recognized."
        case .unsupportedFormat:
            return "This document format is not supported for viewing."
        case .networkError(let message):
            return "Network error: \(message)"
        case .unknown(let error):
            return error.localizedDescription
        }
    }

    public static func from(_ error: Error) -> DocumentViewerError {
        if let viewerError = error as? DocumentViewerError {
            return viewerError
        }

        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost:
                return .networkError("No internet connection")
            case .timedOut:
                return .networkError("Request timed out")
            default:
                return .networkError(urlError.localizedDescription)
            }
        }

        return .unknown(error)
    }
}

// MARK: - PDFKit View

/// UIViewRepresentable wrapper for PDFView.
struct PDFKitView: UIViewRepresentable {
    let document: PDFDocument
    @Binding var currentPage: Int
    @Binding var totalPages: Int

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = document
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.usePageViewController(false)
        pdfView.backgroundColor = .systemBackground

        // Add page change observer
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.pageChanged(_:)),
            name: .PDFViewPageChanged,
            object: pdfView
        )

        return pdfView
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        if uiView.document != document {
            uiView.document = document
        }

        // Update total pages
        DispatchQueue.main.async {
            totalPages = document.pageCount
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject {
        var parent: PDFKitView

        init(_ parent: PDFKitView) {
            self.parent = parent
        }

        @objc func pageChanged(_ notification: Notification) {
            guard let pdfView = notification.object as? PDFView,
                  let currentPDFPage = pdfView.currentPage,
                  let pageIndex = pdfView.document?.index(for: currentPDFPage) else {
                return
            }

            DispatchQueue.main.async {
                self.parent.currentPage = pageIndex + 1
            }
        }
    }
}

// MARK: - Image Viewer View

/// Zoomable image viewer.
struct ZoomableImageView: UIViewRepresentable {
    let image: UIImage

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 4.0
        scrollView.bouncesZoom = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false

        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        imageView.tag = 100

        scrollView.addSubview(imageView)

        return scrollView
    }

    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        guard let imageView = scrollView.viewWithTag(100) as? UIImageView else { return }
        imageView.image = image
        imageView.frame = CGRect(origin: .zero, size: image.size)
        scrollView.contentSize = image.size
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, UIScrollViewDelegate {
        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            return scrollView.viewWithTag(100)
        }
    }
}

// MARK: - Preview Provider

#if DEBUG
struct DocumentViewerView_Previews: PreviewProvider {
    static var previews: some View {
        let fallbackURL = URL(string: "https://example.com/manual.pdf")
            ?? URL(fileURLWithPath: "/dev/null")
        DocumentViewerView(
            document: Document(
                id: "preview-doc",
                title: [LangString(language: "en", text: "Operating Manual")],
                documentClass: .operatingManual,
                digitalFile: [
                    DigitalFile(
                        fileFormat: "application/pdf",
                        file: fallbackURL
                    )
                ]
            )
        )
    }
}
#endif

//
//  AASXImportManager.swift
//  TwinAct Field Companion
//
//  Coordinates AASX import from file picker or URL download.
//

import Foundation
import Combine
import os.log

// MARK: - Import State

/// State of an AASX import operation.
public enum AASXImportState: Equatable {
    case idle
    case downloading(progress: Double)
    case extracting
    case parsing
    case storingContent
    case awaitingUserDecision(issues: [AASXImportIssue])
    case completed(AASXParseResult)
    case failed(String)

    public static func == (lhs: AASXImportState, rhs: AASXImportState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.extracting, .extracting), (.parsing, .parsing), (.storingContent, .storingContent):
            return true
        case (.downloading(let a), .downloading(let b)):
            return a == b
        case (.failed(let a), .failed(let b)):
            return a == b
        case (.completed(let a), .completed(let b)):
            return a.assetId == b.assetId
        case (.awaitingUserDecision(let a), .awaitingUserDecision(let b)):
            return a.map(\.id) == b.map(\.id)
        default:
            return false
        }
    }
}

// MARK: - Import Manager

/// Manages AASX file imports from file picker or URL download.
@MainActor
public final class AASXImportManager: ObservableObject {

    // MARK: - Published Properties

    @Published public private(set) var state: AASXImportState = .idle
    @Published public private(set) var currentResult: AASXParseResult?

    // MARK: - Properties

    private let parser: AASXParser
    private let contentStore: AASXContentStore
    private let logger = Logger(
        subsystem: AppConfiguration.AppInfo.bundleIdentifier,
        category: "AASXImportManager"
    )

    private var downloadTask: URLSessionDownloadTask?
    private var pendingIssues: [AASXImportIssue] = []
    private var pendingURL: URL?

    // MARK: - Initialization

    public init(
        parser: AASXParser = AASXParser(),
        contentStore: AASXContentStore = .shared
    ) {
        self.parser = parser
        self.contentStore = contentStore
    }

    // MARK: - Public Methods

    /// Import AASX from local file URL
    public func importFromFile(_ url: URL) async {
        logger.info("Importing AASX from file: \(url.lastPathComponent)")

        // Start accessing security-scoped resource
        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        // Scan for issues first
        state = .extracting

        do {
            let issues = try await parser.scanForIssues(url: url)

            if !issues.isEmpty {
                pendingURL = url
                pendingIssues = issues
                state = .awaitingUserDecision(issues: issues)
                return
            }

            // No issues, proceed with parsing
            await parseAndStore(url: url)

        } catch {
            logger.error("Import failed: \(error.localizedDescription)")
            state = .failed(error.localizedDescription)
        }
    }

    /// Import AASX from remote URL
    public func importFromURL(_ urlString: String) async {
        guard let url = URL(string: urlString) else {
            state = .failed("Invalid URL")
            return
        }

        logger.info("Downloading AASX from: \(urlString)")
        state = .downloading(progress: 0)

        do {
            let localURL = try await downloadFile(from: url)

            // Scan for issues
            let issues = try await parser.scanForIssues(url: localURL)

            if !issues.isEmpty {
                pendingURL = localURL
                pendingIssues = issues
                state = .awaitingUserDecision(issues: issues)
                return
            }

            await parseAndStore(url: localURL)

            // Cleanup downloaded file
            try? FileManager.default.removeItem(at: localURL)

        } catch {
            logger.error("Download failed: \(error.localizedDescription)")
            state = .failed(error.localizedDescription)
        }
    }

    /// User chose to continue despite issues
    public func continueWithIssues() async {
        guard let url = pendingURL else {
            state = .failed("No pending import")
            return
        }

        pendingIssues = []
        await parseAndStore(url: url)
    }

    /// User chose to abort due to issues
    public func abortImport() {
        pendingURL = nil
        pendingIssues = []
        state = .idle
        logger.info("Import aborted by user")
    }

    /// Cancel ongoing download
    public func cancelDownload() {
        downloadTask?.cancel()
        downloadTask = nil
        state = .idle
    }

    /// Reset to idle state
    public func reset() {
        state = .idle
        currentResult = nil
        pendingURL = nil
        pendingIssues = []
    }

    // MARK: - Private Methods

    private func downloadFile(from url: URL) async throws -> URL {
        let (tempURL, response) = try await URLSession.shared.download(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw AASXError.downloadFailed("Server returned error")
        }

        // Move to permanent temp location with .aasx extension
        let destinationURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("aasx")

        try FileManager.default.moveItem(at: tempURL, to: destinationURL)

        return destinationURL
    }

    private func parseAndStore(url: URL) async {
        state = .parsing

        do {
            let result = try await parser.parse(url: url)

            state = .storingContent
            _ = try contentStore.store(result)

            currentResult = result
            state = .completed(result)

            logger.info("Import completed: \(result.assetId)")

        } catch {
            logger.error("Parse failed: \(error.localizedDescription)")
            state = .failed(error.localizedDescription)
        }
    }
}

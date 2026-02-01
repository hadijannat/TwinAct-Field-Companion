//
//  AASXImportView.swift
//  TwinAct Field Companion
//
//  UI components for AASX file import.
//

import SwiftUI
import UniformTypeIdentifiers

// MARK: - AASX UTType

extension UTType {
    /// AASX file type
    static let aasx = UTType(filenameExtension: "aasx") ?? .data
}

// MARK: - AASX Import Sheet

/// Sheet for importing AASX files via URL.
public struct AASXURLImportSheet: View {
    @ObservedObject var importManager: AASXImportManager
    @Environment(\.dismiss) private var dismiss

    @State private var urlString = ""
    @FocusState private var isURLFieldFocused: Bool

    public init(importManager: AASXImportManager) {
        self.importManager = importManager
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "link.badge.plus")
                        .font(.system(size: 48))
                        .foregroundColor(.accentColor)

                    Text("Import from URL")
                        .font(.title2.bold())

                    Text("Enter the URL of an AASX file to import")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top)

                // URL input
                VStack(alignment: .leading, spacing: 8) {
                    Text("AASX URL")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    TextField("https://example.com/asset.aasx", text: $urlString)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($isURLFieldFocused)
                }
                .padding(.horizontal)

                // State indicator
                stateView

                Spacer()

                // Actions
                actionButtons
            }
            .navigationTitle("Import AASX")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        importManager.cancelDownload()
                        dismiss()
                    }
                }
            }
            .onAppear {
                isURLFieldFocused = true
            }
        }
        .presentationDetents([.medium])
    }

    @ViewBuilder
    private var stateView: some View {
        switch importManager.state {
        case .idle:
            EmptyView()

        case .downloading(let progress):
            VStack(spacing: 8) {
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                Text("Downloading... \(Int(progress * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)

        case .extracting, .parsing, .storingContent:
            VStack(spacing: 8) {
                ProgressView()
                Text(stateMessage)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

        case .awaitingUserDecision(let issues):
            AASXIssuesAlert(
                issues: issues,
                onContinue: {
                    Task { await importManager.continueWithIssues() }
                },
                onAbort: {
                    importManager.abortImport()
                }
            )

        case .completed:
            VStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.green)
                Text("Import successful!")
                    .font(.headline)
            }

        case .failed(let error):
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.orange)
                Text(error)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal)
        }
    }

    private var stateMessage: String {
        switch importManager.state {
        case .extracting: return "Extracting package..."
        case .parsing: return "Parsing content..."
        case .storingContent: return "Storing files..."
        default: return ""
        }
    }

    @ViewBuilder
    private var actionButtons: some View {
        switch importManager.state {
        case .idle, .failed:
            Button {
                Task {
                    await importManager.importFromURL(urlString)
                }
            } label: {
                Label("Download & Import", systemImage: "arrow.down.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(urlString.isEmpty || !isValidURL)
            .padding(.horizontal)
            .padding(.bottom)

        case .completed:
            Button {
                dismiss()
            } label: {
                Text("Done")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal)
            .padding(.bottom)

        default:
            EmptyView()
        }
    }

    private var isValidURL: Bool {
        guard let url = URL(string: urlString) else { return false }
        return url.scheme == "http" || url.scheme == "https"
    }
}

// MARK: - Issues Alert

/// Alert view showing import issues.
struct AASXIssuesAlert: View {
    let issues: [AASXImportIssue]
    let onContinue: () -> Void
    let onAbort: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundColor(.orange)

            Text("Issues Found")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(issues) { issue in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: issue.icon)
                            .foregroundColor(.orange)
                            .frame(width: 20)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(issue.title)
                                .font(.subheadline.bold())
                            Text(issue.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(8)

            HStack(spacing: 16) {
                Button("Abort") {
                    onAbort()
                }
                .buttonStyle(.bordered)

                Button("Continue Anyway") {
                    onContinue()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }
}

// MARK: - File Importer Modifier

/// View modifier for AASX file import.
public struct AASXFileImporterModifier: ViewModifier {
    @Binding var isPresented: Bool
    let importManager: AASXImportManager

    public func body(content: Content) -> some View {
        content
            .fileImporter(
                isPresented: $isPresented,
                allowedContentTypes: [.aasx, .zip],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        Task {
                            await importManager.importFromFile(url)
                        }
                    }
                case .failure(let error):
                    print("File selection failed: \(error)")
                }
            }
    }
}

extension View {
    /// Add AASX file importer capability
    public func aasxFileImporter(
        isPresented: Binding<Bool>,
        importManager: AASXImportManager
    ) -> some View {
        modifier(AASXFileImporterModifier(isPresented: isPresented, importManager: importManager))
    }
}

// MARK: - Import Progress View

/// Compact progress indicator for import state.
public struct AASXImportProgressView: View {
    @ObservedObject var importManager: AASXImportManager

    public init(importManager: AASXImportManager) {
        self.importManager = importManager
    }

    public var body: some View {
        switch importManager.state {
        case .idle:
            EmptyView()

        case .downloading(let progress):
            HStack(spacing: 8) {
                ProgressView()
                    .scaleEffect(0.8)
                Text("Downloading \(Int(progress * 100))%")
                    .font(.caption)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(16)

        case .extracting, .parsing, .storingContent:
            HStack(spacing: 8) {
                ProgressView()
                    .scaleEffect(0.8)
                Text("Importing...")
                    .font(.caption)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(16)

        default:
            EmptyView()
        }
    }
}

// MARK: - Preview

#if DEBUG
struct AASXImportView_Previews: PreviewProvider {
    static var previews: some View {
        AASXURLImportSheet(importManager: AASXImportManager())
            .previewDisplayName("URL Import")
    }
}
#endif

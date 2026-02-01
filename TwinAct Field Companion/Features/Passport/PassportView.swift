//
//  PassportView.swift
//  TwinAct Field Companion
//
//  Digital Product Passport view for displaying asset information.
//  Provides read-only access to Digital Nameplate, Carbon Footprint,
//  Documentation, and Technical Data.
//

import SwiftUI

// MARK: - Passport View

/// Digital Product Passport view for an asset.
/// Displays DPP-compliant information including nameplate, sustainability data,
/// and documentation.
public struct PassportView: View {

    // MARK: - Properties

    @StateObject private var viewModel: PassportViewModel
    @State private var selectedSection: PassportSection?
    @State private var selectedTab: PassportTab = .overview
    @Environment(\.dismiss) private var dismiss

    // AASX Import
    @StateObject private var aasxImportManager = AASXImportManager()
    @State private var showFileImporter = false
    @State private var showURLImporter = false

    // Jargon Buster support
    @StateObject private var jargonBusterVM: JargonBusterViewModel
    @State private var selectedGlossaryTerm: GlossaryEntry?
    @State private var showingGlossaryBrowser = false

    // AI Chat
    @State private var showChatSheet = false

    let assetId: String
    let glossaryService: GlossaryService?

    // MARK: - Initialization

    /// Initialize with asset ID.
    /// - Parameter assetId: The asset/AAS identifier
    public init(assetId: String, glossaryService: GlossaryService? = nil) {
        self.assetId = assetId
        self.glossaryService = glossaryService
        self._viewModel = StateObject(wrappedValue: PassportViewModel(assetId: assetId))

        if let service = glossaryService {
            self._jargonBusterVM = StateObject(wrappedValue: JargonBusterViewModel(glossaryService: service))
        } else {
            // Create a placeholder - will be replaced when DI is set up
            self._jargonBusterVM = StateObject(wrappedValue: JargonBusterViewModel(glossaryService: DependencyContainer.shared.glossaryService))
        }
    }

    /// Initialize with asset ID and custom services.
    /// - Parameters:
    ///   - assetId: The asset/AAS identifier
    ///   - viewModel: Custom view model with injected dependencies
    ///   - glossaryService: Optional glossary service for Jargon Buster
    public init(assetId: String, viewModel: PassportViewModel, glossaryService: GlossaryService? = nil) {
        self.assetId = assetId
        self.glossaryService = glossaryService
        self._viewModel = StateObject(wrappedValue: viewModel)

        if let service = glossaryService {
            self._jargonBusterVM = StateObject(wrappedValue: JargonBusterViewModel(glossaryService: service))
        } else {
            self._jargonBusterVM = StateObject(wrappedValue: JargonBusterViewModel(glossaryService: DependencyContainer.shared.glossaryService))
        }
    }

    // MARK: - Body

    public var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Tab picker
                tabPicker
                    .padding(.horizontal)
                    .padding(.top, 8)

                // Tab content
                ScrollView {
                    VStack(spacing: 20) {
                        // Asset header (shown on all tabs)
                        AssetHeaderView(asset: viewModel.asset)

                        // Cache indicator
                        if viewModel.isFromCache {
                            cacheIndicator
                        }

                        // Tab-specific content
                        switch selectedTab {
                        case .overview:
                            overviewTabContent

                        case .content:
                            contentTabContent

                        case .structure:
                            structureTabContent
                        }

                        // Empty state if no data (only on overview tab)
                        if selectedTab == .overview && !viewModel.isLoading && viewModel.asset == nil && viewModel.error == nil {
                            emptyState
                        }

                        // Error state
                        if let error = viewModel.error {
                            errorState(error: error)
                        }

                        // Bottom spacing
                        Spacer(minLength: 40)
                    }
                    .padding()
                    .animation(.easeInOut(duration: 0.3), value: viewModel.isLoading)
                    .animation(.easeInOut(duration: 0.2), value: selectedTab)
                }
                .refreshable {
                    await viewModel.refresh()
                }
            }

            // Loading overlay
            if viewModel.isLoading && viewModel.asset == nil {
                loadingOverlay
            }
        }
        .accessibilityIdentifier("passport.view")
        .navigationTitle("Asset Passport")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // AASX Import menu
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showFileImporter = true
                    } label: {
                        Label("Import from Files", systemImage: "folder")
                    }

                    Button {
                        showURLImporter = true
                    } label: {
                        Label("Import from URL", systemImage: "link")
                    }

                    Button {
                        Task {
                            await scanDocumentsForAASX()
                        }
                    } label: {
                        Label("Scan Documents Folder", systemImage: "doc.viewfinder")
                    }
                } label: {
                    Image(systemName: "square.and.arrow.down")
                }
                .accessibilityLabel("Import AASX")
            }

            // Glossary button
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingGlossaryBrowser = true
                } label: {
                    Image(systemName: "questionmark.circle")
                }
                .accessibilityLabel("Glossary")
                .accessibilityHint("Open the DPP term glossary")
            }

            // AI Chat button
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showChatSheet = true
                } label: {
                    Image(systemName: "bubble.left.and.bubble.right")
                }
                .accessibilityLabel("Chat with AI")
                .accessibilityHint("Ask questions about this asset")
            }

            ToolbarItem(placement: .topBarTrailing) {
                if let asset = viewModel.asset {
                    ShareButton(asset: asset)
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                }
            }
        }
        .task {
            await viewModel.loadAsset()
        }
        // AASX file importer
        .aasxFileImporter(isPresented: $showFileImporter, importManager: aasxImportManager)
        // AASX URL import sheet
        .sheet(isPresented: $showURLImporter) {
            AASXURLImportSheet(importManager: aasxImportManager)
        }
        // Import completion handler
        .onChange(of: aasxImportManager.state) { _, newState in
            if case .completed = newState {
                // Refresh the view to show new content
                Task {
                    await viewModel.refresh()
                }
            }
        }
        // Jargon Buster sheet for selected term
        .sheet(item: $selectedGlossaryTerm) { entry in
            JargonBusterSheet(
                entry: entry,
                viewModel: jargonBusterVM,
                onDismiss: { selectedGlossaryTerm = nil }
            )
        }
        // Full glossary browser
        .sheet(isPresented: $showingGlossaryBrowser) {
            if let service = glossaryService ?? DependencyContainer.shared.glossaryService as GlossaryService? {
                GlossaryBrowserView(glossaryService: service) { entry in
                    showingGlossaryBrowser = false
                    selectedGlossaryTerm = entry
                }
            }
        }
        // AI Chat sheet
        .sheet(isPresented: $showChatSheet) {
            NavigationStack {
                ChatView(
                    assetId: assetId,
                    assetName: viewModel.asset?.name
                )
                .navigationTitle("Chat with Asset")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Done") {
                            showChatSheet = false
                        }
                    }
                }
            }
        }
    }

    // MARK: - Tab Picker

    private var tabPicker: some View {
        Picker("View", selection: $selectedTab) {
            ForEach(PassportTab.allCases) { tab in
                Label(tab.title, systemImage: tab.icon)
                    .tag(tab)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityLabel("Select passport view tab")
    }

    // MARK: - Overview Tab Content

    @ViewBuilder
    private var overviewTabContent: some View {
        // Digital Nameplate section
        if let nameplate = viewModel.digitalNameplate {
            NameplateCardView(nameplate: nameplate)
                .transition(.opacity.combined(with: .move(edge: .top)))
        }

        // Carbon Footprint section (DPP sustainability)
        if let carbon = viewModel.carbonFootprint {
            CarbonFootprintView(footprint: carbon)
                .transition(.opacity.combined(with: .move(edge: .top)))
        }

        // Documentation section
        if !viewModel.documents.isEmpty {
            DocumentListView(documents: viewModel.documents)
                .transition(.opacity.combined(with: .move(edge: .top)))
        }

        // Technical Data summary (if available)
        if let techData = viewModel.technicalData {
            TechnicalDataSummaryView(data: techData)
                .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    // MARK: - Content Tab Content

    @ViewBuilder
    private var contentTabContent: some View {
        // Image gallery
        AASXImageGalleryView(assetId: assetId)

        // Documents with enhanced view (showing extracted AASX documents)
        let extractedDocs = AASXContentStore.shared.documents(for: assetId)
        if !extractedDocs.isEmpty {
            ExtractedDocumentListView(documents: extractedDocs)
        } else if !viewModel.documents.isEmpty {
            // Fall back to server documents
            DocumentListView(documents: viewModel.documents)
        }

        // CAD Models
        let cadFiles = AASXContentStore.shared.cadFiles(for: assetId)
        if !cadFiles.isEmpty {
            CADModelSection(assetId: assetId)
        }

        // Empty state if no AASX content
        if !AASXContentStore.shared.hasContent(for: assetId) && viewModel.documents.isEmpty {
            contentEmptyState
        }
    }

    // MARK: - Structure Tab Content

    @ViewBuilder
    private var structureTabContent: some View {
        // File browser
        if AASXContentStore.shared.hasContent(for: assetId) {
            AASXFileBrowserView(assetId: assetId)
        }

        // JSON explorer
        if AASXContentStore.shared.aasJSON(for: assetId) != nil {
            AASJSONExplorerView(assetId: assetId)
        }

        // Empty state if no AASX package
        if !AASXContentStore.shared.hasContent(for: assetId) {
            structureEmptyState
        }
    }

    // MARK: - Content Empty State

    private var contentEmptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 40))
                .foregroundColor(.secondary)

            Text("No AASX Content")
                .font(.headline)

            Text("Import an AASX package to view images, documents, and 3D models.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button {
                showFileImporter = true
            } label: {
                Label("Import AASX", systemImage: "square.and.arrow.down")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    // MARK: - Structure Empty State

    private var structureEmptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "folder.badge.questionmark")
                .font(.system(size: 40))
                .foregroundColor(.secondary)

            Text("No Package Structure")
                .font(.headline)

            Text("Import an AASX package to explore its file structure and AAS JSON content.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button {
                showFileImporter = true
            } label: {
                Label("Import AASX", systemImage: "square.and.arrow.down")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    // MARK: - Cache Indicator

    private var cacheIndicator: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.caption)

            Text("Showing cached data")
                .font(.caption)

            if let lastRefreshed = viewModel.lastRefreshed {
                Text("Updated \(lastRefreshed, style: .relative) ago")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .foregroundColor(.orange)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(8)
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

                Text("Loading Passport...")
                    .font(.headline)

                Text("Fetching asset information")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(30)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(16)
            .shadow(radius: 10)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 50))
                .foregroundColor(.secondary)

            Text("No Passport Data")
                .font(.headline)

            Text("This asset does not have any Digital Product Passport information available.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button {
                Task {
                    await viewModel.refresh()
                }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }

    // MARK: - Error State

    private func errorState(error: PassportError) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundColor(.orange)

            Text("Unable to Load Passport")
                .font(.headline)

            Text(error.localizedDescription)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                Button {
                    Task {
                        await viewModel.refresh()
                    }
                } label: {
                    Label("Try Again", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.borderedProminent)

                Button("Go Back") {
                    dismiss()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    // MARK: - Documents Folder Scanning

    /// Scan the app's Documents folder for AASX files and import them
    private func scanDocumentsForAASX() async {
        let fileManager = FileManager.default
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("Could not access Documents directory")
            return
        }

        do {
            let contents = try fileManager.contentsOfDirectory(at: documentsURL, includingPropertiesForKeys: nil)
            let aasxFiles = contents.filter { $0.pathExtension.lowercased() == "aasx" }

            if aasxFiles.isEmpty {
                print("No AASX files found in Documents folder")
                return
            }

            print("Found \(aasxFiles.count) AASX file(s) in Documents folder")

            for fileURL in aasxFiles {
                print("Importing: \(fileURL.lastPathComponent)")
                await aasxImportManager.importFromFile(fileURL)
            }
        } catch {
            print("Error scanning Documents folder: \(error.localizedDescription)")
        }
    }
}

// MARK: - Passport Section

/// Sections in the passport view.
public enum PassportSection: String, CaseIterable, Identifiable {
    case nameplate
    case carbonFootprint
    case documentation
    case technicalData

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .nameplate: return "Digital Nameplate"
        case .carbonFootprint: return "Carbon Footprint"
        case .documentation: return "Documentation"
        case .technicalData: return "Technical Data"
        }
    }

    public var icon: String {
        switch self {
        case .nameplate: return "tag.fill"
        case .carbonFootprint: return "leaf.fill"
        case .documentation: return "doc.fill"
        case .technicalData: return "cpu.fill"
        }
    }
}

// MARK: - Share Button

/// Share button for asset passport.
struct ShareButton: View {
    let asset: Asset

    var body: some View {
        ShareLink(
            item: shareText,
            subject: Text("Digital Product Passport"),
            message: Text("Asset information from TwinAct Field Companion")
        ) {
            Image(systemName: "square.and.arrow.up")
        }
    }

    private var shareText: String {
        var text = "Digital Product Passport\n\n"
        text += "Asset: \(asset.name)\n"

        if let manufacturer = asset.manufacturer {
            text += "Manufacturer: \(manufacturer)\n"
        }

        if let serial = asset.serialNumber {
            text += "Serial Number: \(serial)\n"
        }

        if let model = asset.model {
            text += "Model: \(model)\n"
        }

        text += "\nAsset ID: \(asset.displayId)\n"
        text += "\nGenerated by TwinAct Field Companion"

        return text
    }
}

// MARK: - Preview Provider

#if DEBUG
struct PassportView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            PassportView(assetId: "preview-asset-id")
        }
    }
}
#endif

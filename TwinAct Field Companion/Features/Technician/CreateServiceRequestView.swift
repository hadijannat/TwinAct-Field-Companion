//
//  CreateServiceRequestView.swift
//  TwinAct Field Companion
//
//  Form view for creating new service requests.
//  Supports offline creation with outbox queuing.
//

import SwiftUI
import PhotosUI
import Combine

// MARK: - Create Service Request View

/// Form for creating a new service request.
public struct CreateServiceRequestView: View {

    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss

    // MARK: - State

    @StateObject private var viewModel: CreateServiceRequestViewModel
    @State private var selectedPhotos: [PhotosPickerItem] = []

    /// Callback when request is saved
    private let onSave: ((ServiceRequest) -> Void)?

    // MARK: - Initialization

    /// Initialize the create view.
    /// - Parameters:
    ///   - assetId: Optional asset ID to associate with the request
    ///   - onSave: Optional callback when request is saved
    public init(assetId: String? = nil, onSave: ((ServiceRequest) -> Void)? = nil) {
        _viewModel = StateObject(wrappedValue: CreateServiceRequestViewModel(assetId: assetId))
        self.onSave = onSave
    }

    // MARK: - Body

    public var body: some View {
        NavigationStack {
            Form {
                // Request details section
                requestDetailsSection

                // Description section
                descriptionSection

                // Attachments section
                attachmentsSection

                // Contact section
                contactSection
            }
            .navigationTitle("New Request")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Create") {
                        Task {
                            if let request = await viewModel.createRequest() {
                                onSave?(request)
                                dismiss()
                            }
                        }
                    }
                    .disabled(!viewModel.isValid)
                    .fontWeight(.semibold)
                }
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage)
            }
            .onChange(of: selectedPhotos) { _, newItems in
                Task {
                    await viewModel.loadPhotos(from: newItems)
                }
            }
        }
    }

    // MARK: - Request Details Section

    private var requestDetailsSection: some View {
        Section("Request Details") {
            // Title
            TextField("Title", text: $viewModel.title)
                .textInputAutocapitalization(.sentences)

            // Category picker
            Picker("Category", selection: $viewModel.category) {
                ForEach(ServiceRequestCategory.allCases, id: \.self) { category in
                    Label(category.displayName, systemImage: category.iconName)
                        .tag(category)
                }
            }

            // Priority picker
            Picker("Priority", selection: $viewModel.priority) {
                ForEach(ServiceRequestPriority.allCases, id: \.self) { priority in
                    HStack {
                        Image(systemName: priority.iconName)
                            .foregroundStyle(priorityColor(for: priority))
                        Text(priority.displayName)
                    }
                    .tag(priority)
                }
            }

            // Location
            TextField("Location (optional)", text: $viewModel.location)
        }
    }

    // MARK: - Description Section

    private var descriptionSection: some View {
        Section("Description") {
            TextEditor(text: $viewModel.description)
                .frame(minHeight: 100)
                .overlay(alignment: .topLeading) {
                    if viewModel.description.isEmpty {
                        Text("Describe the issue or request...")
                            .foregroundStyle(.placeholder)
                            .padding(.top, 8)
                            .padding(.leading, 4)
                            .allowsHitTesting(false)
                    }
                }
        }
    }

    // MARK: - Attachments Section

    private var attachmentsSection: some View {
        Section {
            // Photo picker
            PhotosPicker(
                selection: $selectedPhotos,
                maxSelectionCount: 5,
                matching: .images
            ) {
                Label("Add Photos", systemImage: "photo.badge.plus")
            }

            // Selected photos preview
            if !viewModel.attachmentURLs.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(viewModel.attachmentURLs, id: \.absoluteString) { url in
                            AttachmentPreviewView(url: url) {
                                viewModel.removeAttachment(url)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
        } header: {
            Text("Attachments")
        } footer: {
            Text("Add up to 5 photos to document the issue.")
        }
    }

    // MARK: - Contact Section

    private var contactSection: some View {
        Section {
            TextField("Name", text: $viewModel.requesterName)
                .textContentType(.name)

            TextField("Email", text: $viewModel.requesterEmail)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)

            TextField("Phone", text: $viewModel.requesterPhone)
                .textContentType(.telephoneNumber)
                .keyboardType(.phonePad)
        } header: {
            Text("Contact (Optional)")
        } footer: {
            Text("Provide contact information for follow-up.")
        }
    }

    // MARK: - Helpers

    private func priorityColor(for priority: ServiceRequestPriority) -> Color {
        switch priority {
        case .urgent: return .red
        case .high: return .orange
        case .normal: return .blue
        case .low: return .gray
        }
    }
}

// MARK: - Attachment Preview View

/// Preview view for a selected attachment with remove button.
struct AttachmentPreviewView: View {
    let url: URL
    let onRemove: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Image preview
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure:
                    Image(systemName: "photo")
                        .foregroundStyle(.secondary)
                case .empty:
                    ProgressView()
                @unknown default:
                    EmptyView()
                }
            }
            .frame(width: 80, height: 80)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 1)
            )

            // Remove button
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.white)
                    .background(Circle().fill(Color.black.opacity(0.5)))
            }
            .offset(x: 6, y: -6)
        }
    }
}

// MARK: - Create Service Request View Model

/// View model for creating service requests.
@MainActor
public final class CreateServiceRequestViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published public var title: String = ""
    @Published public var description: String = ""
    @Published public var category: ServiceRequestCategory = .maintenance
    @Published public var priority: ServiceRequestPriority = .normal
    @Published public var location: String = ""
    @Published public var requesterName: String = ""
    @Published public var requesterEmail: String = ""
    @Published public var requesterPhone: String = ""
    @Published public var attachmentURLs: [URL] = []
    @Published public var isCreating: Bool = false
    @Published public var showError: Bool = false
    @Published public var errorMessage: String = ""

    // MARK: - Properties

    private let assetId: String?
    private let persistenceService: PersistenceRepositoryProtocol

    // MARK: - Computed Properties

    /// Whether the form is valid for submission.
    public var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Initialization

    public init(assetId: String? = nil, persistenceService: PersistenceRepositoryProtocol? = nil) {
        self.assetId = assetId
        self.persistenceService = persistenceService ?? PersistenceService()
    }

    // MARK: - Methods

    /// Create the service request.
    /// - Returns: The created service request, or nil if creation failed
    public func createRequest() async -> ServiceRequest? {
        guard isValid else {
            errorMessage = "Please fill in all required fields."
            showError = true
            return nil
        }

        isCreating = true
        defer { isCreating = false }

        // Build the request
        var request = ServiceRequest(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            description: description.trimmingCharacters(in: .whitespacesAndNewlines),
            category: category,
            priority: priority,
            assetId: assetId,
            location: location.isEmpty ? nil : location
        )

        // Add optional contact info
        if !requesterName.isEmpty {
            request.requesterName = requesterName
        }
        if !requesterEmail.isEmpty {
            request.requesterEmail = requesterEmail
        }
        if !requesterPhone.isEmpty {
            request.requesterPhone = requesterPhone
        }

        // Add attachments
        if !attachmentURLs.isEmpty {
            request.attachments = attachmentURLs
        }

        // Queue for sync
        do {
            let element = request.toSubmodelElement()

            try await persistenceService.queueForSync(
                operationType: .create,
                entityType: "ServiceRequest",
                entityId: request.id,
                submodelId: "urn:twinact:serviceRequests:\(assetId ?? "global")",
                payload: element,
                priority: request.priority.sortOrder
            )

            return request
        } catch {
            errorMessage = "Failed to save request: \(error.localizedDescription)"
            showError = true
            return nil
        }
    }

    /// Load photos from PhotosPicker items.
    /// - Parameter items: The selected photo items
    public func loadPhotos(from items: [PhotosPickerItem]) async {
        var urls: [URL] = []

        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self) {
                // Save to temporary file
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString)
                    .appendingPathExtension("jpg")

                do {
                    try data.write(to: tempURL)
                    urls.append(tempURL)
                } catch {
                    // Skip failed items
                }
            }
        }

        attachmentURLs = urls
    }

    /// Remove an attachment.
    /// - Parameter url: The attachment URL to remove
    public func removeAttachment(_ url: URL) {
        attachmentURLs.removeAll { $0 == url }

        // Clean up temp file
        try? FileManager.default.removeItem(at: url)
    }
}

// MARK: - Preview

#Preview {
    CreateServiceRequestView(assetId: "demo-asset-001")
}

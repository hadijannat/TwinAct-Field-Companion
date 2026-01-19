//
//  ServiceRequestDetailView.swift
//  TwinAct Field Companion
//
//  Detail view for a single service request with notes timeline and attachments.
//  Supports adding notes and updating status.
//

import SwiftUI

// MARK: - Service Request Detail View

/// Detail view showing all information about a service request.
public struct ServiceRequestDetailView: View {

    // MARK: - State

    @StateObject private var viewModel: ServiceRequestDetailViewModel
    @State private var showAddNote = false
    @State private var showUpdateStatus = false
    @State private var newNoteText = ""
    @Environment(\.dismiss) private var dismiss

    // MARK: - Initialization

    /// Initialize with a request ID.
    /// - Parameter requestId: The service request ID to display
    public init(requestId: String) {
        _viewModel = StateObject(wrappedValue: ServiceRequestDetailViewModel(requestId: requestId))
    }

    /// Initialize with an existing request.
    /// - Parameter request: The service request to display
    public init(request: ServiceRequest) {
        _viewModel = StateObject(wrappedValue: ServiceRequestDetailViewModel(request: request))
    }

    // MARK: - Body

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Status header
                StatusHeaderView(request: viewModel.request)

                // Request details
                DetailSection(title: "Description") {
                    Text(viewModel.request.description)
                        .font(.body)
                }

                // Contact information
                if hasContactInfo {
                    DetailSection(title: "Contact") {
                        contactInfoView
                    }
                }

                // Assignment and scheduling
                if hasAssignmentInfo {
                    DetailSection(title: "Assignment") {
                        assignmentInfoView
                    }
                }

                // Notes timeline
                if let notes = viewModel.request.notes, !notes.isEmpty {
                    DetailSection(title: "Notes") {
                        NotesTimelineView(notes: notes)
                    }
                }

                // Attachments
                if let attachments = viewModel.request.attachments, !attachments.isEmpty {
                    DetailSection(title: "Attachments") {
                        AttachmentsGridView(attachments: attachments)
                    }
                }
            }
            .padding()
        }
        .navigationTitle(viewModel.request.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showAddNote = true
                    } label: {
                        Label("Add Note", systemImage: "note.text.badge.plus")
                    }

                    Button {
                        showUpdateStatus = true
                    } label: {
                        Label("Update Status", systemImage: "arrow.triangle.2.circlepath")
                    }

                    Divider()

                    if viewModel.request.isOpen {
                        Button {
                            Task {
                                await viewModel.updateStatus(.resolved)
                            }
                        } label: {
                            Label("Mark Resolved", systemImage: "checkmark.circle")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showAddNote) {
            addNoteSheet
        }
        .sheet(isPresented: $showUpdateStatus) {
            updateStatusSheet
        }
        .task {
            await viewModel.loadRequest()
        }
        .refreshable {
            await viewModel.refresh()
        }
    }

    // MARK: - Contact Info View

    private var hasContactInfo: Bool {
        viewModel.request.requesterName != nil ||
        viewModel.request.requesterEmail != nil ||
        viewModel.request.requesterPhone != nil
    }

    private var contactInfoView: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let name = viewModel.request.requesterName {
                LabeledContent("Name", value: name)
            }
            if let email = viewModel.request.requesterEmail {
                LabeledContent("Email", value: email)
            }
            if let phone = viewModel.request.requesterPhone {
                LabeledContent("Phone", value: phone)
            }
        }
    }

    // MARK: - Assignment Info View

    private var hasAssignmentInfo: Bool {
        viewModel.request.assignedTo != nil ||
        viewModel.request.scheduledDate != nil ||
        viewModel.request.location != nil
    }

    private var assignmentInfoView: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let assignee = viewModel.request.assignedTo {
                LabeledContent("Assigned To", value: assignee)
            }
            if let location = viewModel.request.location {
                LabeledContent("Location", value: location)
            }
            if let scheduled = viewModel.request.scheduledDate {
                LabeledContent("Scheduled") {
                    Text(scheduled, style: .date)
                }
            }
            if let completed = viewModel.request.completedDate {
                LabeledContent("Completed") {
                    Text(completed, style: .date)
                }
            }
        }
    }

    // MARK: - Add Note Sheet

    private var addNoteSheet: some View {
        NavigationStack {
            Form {
                Section("Note") {
                    TextEditor(text: $newNoteText)
                        .frame(minHeight: 120)
                }
            }
            .navigationTitle("Add Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        newNoteText = ""
                        showAddNote = false
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        Task {
                            await viewModel.addNote(newNoteText)
                            newNoteText = ""
                            showAddNote = false
                        }
                    }
                    .disabled(newNoteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Update Status Sheet

    private var updateStatusSheet: some View {
        NavigationStack {
            List {
                ForEach(ServiceRequestStatus.allCases, id: \.self) { status in
                    Button {
                        Task {
                            await viewModel.updateStatus(status)
                            showUpdateStatus = false
                        }
                    } label: {
                        HStack {
                            Image(systemName: status.iconName)
                                .foregroundStyle(statusColor(for: status))
                            Text(status.displayName)
                            Spacer()
                            if viewModel.request.status == status {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                    .foregroundStyle(.primary)
                }
            }
            .navigationTitle("Update Status")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        showUpdateStatus = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func statusColor(for status: ServiceRequestStatus) -> Color {
        switch status {
        case .new: return .blue
        case .inProgress: return .orange
        case .onHold: return .yellow
        case .resolved: return .green
        case .closed: return .gray
        }
    }
}

// MARK: - Status Header View

/// Header showing status, priority, and category badges.
struct StatusHeaderView: View {
    let request: ServiceRequest

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Status and priority row
            HStack(spacing: 12) {
                // Status badge
                HStack(spacing: 6) {
                    Image(systemName: request.status.iconName)
                    Text(request.status.displayName)
                }
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(statusColor)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(statusColor.opacity(0.15), in: Capsule())

                // Priority badge
                HStack(spacing: 4) {
                    Image(systemName: request.priority.iconName)
                    Text(request.priority.displayName)
                }
                .font(.caption)
                .foregroundStyle(priorityColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(priorityColor.opacity(0.1), in: Capsule())

                Spacer()
            }

            // Category and metadata
            HStack {
                Image(systemName: request.category.iconName)
                Text(request.category.displayName)

                Text(" - ")

                Text("Created \(request.formattedAge)")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private var statusColor: Color {
        switch request.status {
        case .new: return .blue
        case .inProgress: return .orange
        case .onHold: return .yellow
        case .resolved: return .green
        case .closed: return .gray
        }
    }

    private var priorityColor: Color {
        switch request.priority {
        case .urgent: return .red
        case .high: return .orange
        case .normal: return .blue
        case .low: return .gray
        }
    }
}

// MARK: - Detail Section

/// A section with a title and content.
struct DetailSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)

            content
        }
    }
}

// MARK: - Notes Timeline View

/// Timeline view showing service notes.
struct NotesTimelineView: View {
    let notes: [ServiceNote]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(notes.enumerated()), id: \.element.timestamp) { index, note in
                NoteItemView(note: note, isLast: index == notes.count - 1)
            }
        }
    }
}

/// A single note item in the timeline.
struct NoteItemView: View {
    let note: ServiceNote
    let isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Timeline indicator
            VStack(spacing: 0) {
                Circle()
                    .fill(note.isInternal ? Color.orange : Color.blue)
                    .frame(width: 10, height: 10)

                if !isLast {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.3))
                        .frame(width: 2)
                }
            }

            // Note content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(note.author)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    if note.isInternal {
                        Text("Internal")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.1), in: Capsule())
                    }

                    Spacer()

                    Text(note.formattedTimestamp)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                Text(note.text)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, isLast ? 0 : 16)
        }
    }
}

// MARK: - Attachments Grid View

/// Grid view for attachments.
struct AttachmentsGridView: View {
    let attachments: [URL]

    private let columns = [
        GridItem(.adaptive(minimum: 80, maximum: 120))
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(attachments, id: \.absoluteString) { url in
                AttachmentThumbnailView(url: url)
            }
        }
    }
}

/// Thumbnail view for a single attachment.
struct AttachmentThumbnailView: View {
    let url: URL

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.tertiarySystemGroupedBackground))

                Image(systemName: iconName)
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            .frame(height: 60)

            Text(url.lastPathComponent)
                .font(.caption2)
                .lineLimit(1)
                .foregroundStyle(.secondary)
        }
    }

    private var iconName: String {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "pdf": return "doc.fill"
        case "jpg", "jpeg", "png", "gif", "heic": return "photo.fill"
        case "mp4", "mov": return "video.fill"
        case "doc", "docx": return "doc.text.fill"
        case "xls", "xlsx": return "tablecells.fill"
        default: return "paperclip"
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ServiceRequestDetailView(request: ServiceRequest(
            title: "Motor Overheating",
            description: "The main drive motor is showing elevated temperatures during operation. Temperature readings are 15-20 degrees above normal operating range. This needs immediate attention to prevent damage.",
            category: .repair,
            priority: .high,
            assetId: "demo-asset-001",
            location: "Building A, Floor 2"
        ))
    }
}

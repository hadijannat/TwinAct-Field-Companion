//
//  ServiceRequestListView.swift
//  TwinAct Field Companion
//
//  List view for service requests with filtering and offline indicator.
//  Supports create, view details, and pull-to-refresh.
//

import SwiftUI

// MARK: - Service Request List View

/// List of service requests with filtering and create functionality.
public struct ServiceRequestListView: View {

    // MARK: - State

    @StateObject private var viewModel: ServiceRequestListViewModel
    @State private var showCreateSheet = false
    @State private var searchText = ""

    // MARK: - Initialization

    /// Initialize with optional asset ID filter.
    /// - Parameter assetId: Optional asset ID to filter requests
    public init(assetId: String? = nil) {
        _viewModel = StateObject(wrappedValue: ServiceRequestListViewModel(assetId: assetId))
    }

    // MARK: - Body

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filter chips
                filterChipsView

                // Content
                if viewModel.isLoading && viewModel.requests.isEmpty {
                    loadingView
                } else if viewModel.requests.isEmpty {
                    emptyStateView
                } else {
                    requestListView
                }
            }
            .navigationTitle("Service Requests")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showCreateSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }

                if viewModel.pendingSyncCount > 0 {
                    ToolbarItem(placement: .topBarLeading) {
                        pendingSyncIndicator
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search requests")
            .sheet(isPresented: $showCreateSheet) {
                CreateServiceRequestView(
                    assetId: viewModel.currentAssetId,
                    onSave: { request in
                        Task {
                            await viewModel.createRequest(request)
                        }
                    }
                )
            }
            .refreshable {
                await viewModel.refresh()
            }
            .task {
                await viewModel.loadRequests()
            }
            .onChange(of: searchText) { _, newValue in
                viewModel.searchText = newValue
            }
        }
    }

    // MARK: - Filter Chips View

    private var filterChipsView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(RequestFilter.allCases, id: \.self) { filter in
                    FilterChipView(
                        title: filter.displayName,
                        count: viewModel.count(for: filter),
                        isSelected: viewModel.filter == filter
                    ) {
                        withAnimation {
                            viewModel.filter = filter
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Request List View

    private var requestListView: some View {
        List {
            ForEach(viewModel.filteredRequests) { request in
                NavigationLink(destination: ServiceRequestDetailView(requestId: request.id)) {
                    ServiceRequestRowView(request: request)
                }
            }
        }
        .listStyle(.plain)
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Loading requests...")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Empty State View

    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("No Service Requests", systemImage: "wrench.and.screwdriver")
        } description: {
            Text("Create a new service request to get started.")
        } actions: {
            Button {
                showCreateSheet = true
            } label: {
                Text("Create Request")
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Pending Sync Indicator

    private var pendingSyncIndicator: some View {
        HStack(spacing: 4) {
            Image(systemName: "cloud.fill")
                .foregroundStyle(.orange)
            Text("\(viewModel.pendingSyncCount)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Filter Chip View

/// A selectable filter chip button.
struct FilterChipView: View {
    let title: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title)
                if count > 0 {
                    Text("(\(count))")
                        .font(.caption2)
                }
            }
            .font(.subheadline)
            .fontWeight(isSelected ? .semibold : .regular)
            .foregroundStyle(isSelected ? .white : .primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(isSelected ? Color.accentColor : Color(.systemBackground))
            )
            .overlay(
                Capsule()
                    .strokeBorder(Color.secondary.opacity(0.3), lineWidth: isSelected ? 0 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Service Request Row View

/// Row view for a single service request in the list.
struct ServiceRequestRowView: View {
    let request: ServiceRequest

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Priority indicator
            priorityIndicator

            // Content
            VStack(alignment: .leading, spacing: 4) {
                // Title and status
                HStack {
                    Text(request.title)
                        .font(.headline)
                        .lineLimit(1)

                    Spacer()

                    StatusBadgeView(status: request.status)
                }

                // Category
                HStack(spacing: 4) {
                    Image(systemName: request.category.iconName)
                        .font(.caption)
                    Text(request.category.displayName)
                        .font(.caption)
                }
                .foregroundStyle(.secondary)

                // Description preview
                if !request.description.isEmpty {
                    Text(request.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                // Metadata row
                HStack {
                    Text(request.formattedAge)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)

                    if let assignee = request.assignedTo {
                        Text(" - ")
                            .foregroundStyle(.tertiary)
                        Text(assignee)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var priorityIndicator: some View {
        Circle()
            .fill(priorityColor)
            .frame(width: 8, height: 8)
            .padding(.top, 6)
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

// MARK: - Status Badge View

/// Badge showing the current status of a request.
struct StatusBadgeView: View {
    let status: ServiceRequestStatus

    var body: some View {
        Text(status.displayName)
            .font(.caption2)
            .fontWeight(.medium)
            .foregroundStyle(textColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(backgroundColor, in: Capsule())
    }

    private var textColor: Color {
        switch status {
        case .new: return .blue
        case .inProgress: return .orange
        case .onHold: return .yellow
        case .resolved: return .green
        case .closed: return .gray
        }
    }

    private var backgroundColor: Color {
        textColor.opacity(0.15)
    }
}

// MARK: - Request Filter

/// Filter options for the service request list.
public enum RequestFilter: String, CaseIterable {
    case all
    case open
    case mine
    case syncing

    public var displayName: String {
        switch self {
        case .all: return "All"
        case .open: return "Open"
        case .mine: return "Mine"
        case .syncing: return "Syncing"
        }
    }
}

// MARK: - Preview

#Preview {
    ServiceRequestListView(assetId: "demo-asset-001")
}

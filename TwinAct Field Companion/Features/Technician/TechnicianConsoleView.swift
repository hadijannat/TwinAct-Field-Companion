//
//  TechnicianConsoleView.swift
//  TwinAct Field Companion
//
//  Technician console with tabs for service requests, maintenance, and monitoring.
//  Requires technician role authentication.
//

import SwiftUI

// MARK: - Technician Tab

/// Tab enumeration for the technician console.
public enum TechnicianTab: String, CaseIterable, Identifiable {
    case serviceRequests = "Requests"
    case maintenance = "Maintenance"
    case monitoring = "Monitoring"

    public var id: String { rawValue }

    /// SF Symbol icon for the tab.
    public var icon: String {
        switch self {
        case .serviceRequests: return "wrench.and.screwdriver"
        case .maintenance: return "list.bullet.clipboard"
        case .monitoring: return "chart.line.uptrend.xyaxis"
        }
    }

    /// Description of the tab.
    public var description: String {
        switch self {
        case .serviceRequests: return "View and manage service requests"
        case .maintenance: return "Access maintenance procedures"
        case .monitoring: return "Monitor sensor data and trends"
        }
    }
}

// MARK: - Technician Console View

/// Main technician dashboard with tabs for service requests, maintenance, and monitoring.
/// Requires authentication with technician role.
public struct TechnicianConsoleView: View {

    // MARK: - State

    @State private var selectedTab: TechnicianTab = .serviceRequests
    @EnvironmentObject private var syncEngine: SyncEngine

    /// Current asset ID for context (can be nil for global view)
    public let assetId: String?

    // MARK: - Initialization

    /// Initialize the technician console.
    /// - Parameter assetId: Optional asset ID to filter content
    public init(assetId: String? = nil) {
        self.assetId = assetId
    }

    // MARK: - Body

    public var body: some View {
        TabView(selection: $selectedTab) {
            ServiceRequestListView(assetId: assetId)
                .tabItem {
                    Label(TechnicianTab.serviceRequests.rawValue, systemImage: TechnicianTab.serviceRequests.icon)
                }
                .tag(TechnicianTab.serviceRequests)

            MaintenanceInstructionsView(assetId: assetId)
                .tabItem {
                    Label(TechnicianTab.maintenance.rawValue, systemImage: TechnicianTab.maintenance.icon)
                }
                .tag(TechnicianTab.maintenance)

            TimeSeriesMonitoringView(assetId: assetId)
                .tabItem {
                    Label(TechnicianTab.monitoring.rawValue, systemImage: TechnicianTab.monitoring.icon)
                }
                .tag(TechnicianTab.monitoring)
        }
        .overlay(alignment: .top) {
            if syncEngine.pendingOperationCount > 0 {
                SyncStatusBanner(
                    pendingCount: syncEngine.pendingOperationCount,
                    isSyncing: syncEngine.isSyncing
                )
            }
        }
    }
}

// MARK: - Sync Status Banner

/// Banner showing pending sync status.
struct SyncStatusBanner: View {
    let pendingCount: Int
    let isSyncing: Bool

    var body: some View {
        HStack(spacing: 8) {
            if isSyncing {
                ProgressView()
                    .scaleEffect(0.8)
                Text("Syncing...")
            } else {
                Image(systemName: "cloud.fill")
                    .foregroundStyle(.orange)
                Text("\(pendingCount) pending")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: Capsule())
        .padding(.top, 4)
    }
}

// MARK: - Preview

#Preview {
    TechnicianConsoleView(assetId: "demo-asset-001")
        .environmentObject(SyncEngine(
            persistence: PersistenceService(),
            repositoryService: RepositoryService()
        ))
}

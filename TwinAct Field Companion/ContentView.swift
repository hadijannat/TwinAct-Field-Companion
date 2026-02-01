//
//  ContentView.swift
//  TwinAct Field Companion
//
//  Created by Hadi Jannat on 18.01.26.
//

import SwiftUI

// MARK: - Content View

struct ContentView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var syncEngine: SyncEngine
    @State private var showSettings = false

    var body: some View {
        Group {
            if hasCompletedOnboarding {
                mainTabView
            } else {
                OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
            }
        }
        .environmentObject(appState)
        .environmentObject(syncEngine)
    }

    // MARK: - Main Tab View

    private var mainTabView: some View {
        TabView {
            DiscoveryView()
                .tabItem {
                    Label("Discover", systemImage: "qrcode.viewfinder")
                }

            PassportTabView()
                .tabItem {
                    Label("Passport", systemImage: "tag.fill")
                }

            TechnicianConsoleView(assetId: appState.selectedAsset?.id)
                .tabItem {
                    Label("Technician", systemImage: "wrench.and.screwdriver")
                }

            SettingsTabView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
        .overlay(alignment: .top) {
            // Offline banner when disconnected
            if !NetworkMonitor.shared.isConnected {
                OfflineBannerView(pendingChangesCount: syncEngine.pendingOperationCount)
            }
        }
    }
}

// MARK: - Passport Tab View

private struct PassportTabView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        NavigationStack {
            if let asset = appState.selectedAsset {
                PassportView(
                    assetId: asset.id,
                    glossaryService: DependencyContainer.shared.glossaryService
                )
            } else {
                PassportEmptyStateView()
            }
        }
    }
}

// MARK: - Passport Empty State View

private struct PassportEmptyStateView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        EmptyStateView(
            type: .noAssetSelected,
            actionTitle: AppConfiguration.isDemoMode ? "Load Demo Passport" : nil,
            action: AppConfiguration.isDemoMode ? {
                appState.setSelectedAsset(DemoData.asset)
            } : nil,
            secondaryActionTitle: AppConfiguration.isDemoMode ? nil : "Go to Discover",
            secondaryAction: nil
        )
        .navigationTitle("Passport")
    }
}

// MARK: - Settings Tab View

private struct SettingsTabView: View {
    var body: some View {
        SettingsView()
    }
}

// MARK: - Preview

#Preview("Main App") {
    ContentView()
        .environmentObject(AppState())
        .environmentObject(SyncEngine(
            persistence: PersistenceService(controller: .preview),
            repositoryService: RepositoryService()
        ))
}

#Preview("With Onboarding") {
    OnboardingView(hasCompletedOnboarding: .constant(false))
}

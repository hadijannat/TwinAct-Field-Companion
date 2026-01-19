//
//  ContentView.swift
//  TwinAct Field Companion
//
//  Created by Hadi Jannat on 18.01.26.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var appState = AppState()
    @StateObject private var syncEngine: SyncEngine

    init() {
        let persistence = PersistenceService()
        let repository = RepositoryService()
        _syncEngine = StateObject(
            wrappedValue: SyncEngine(
                persistence: persistence,
                repositoryService: repository
            )
        )
    }

    var body: some View {
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
        }
        .environmentObject(appState)
        .environmentObject(syncEngine)
    }
}

private struct PassportTabView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        NavigationStack {
            if let asset = appState.selectedAsset {
                PassportView(assetId: asset.id)
            } else {
                PassportEmptyStateView()
            }
        }
    }
}

private struct PassportEmptyStateView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ContentUnavailableView {
            Label("No Asset Selected", systemImage: "tag.slash")
        } description: {
            Text("Scan an asset QR code or search manually to view its Digital Product Passport.")
        } actions: {
            if AppConfiguration.isDemoMode {
                Button {
                    appState.setSelectedAsset(DemoData.asset)
                } label: {
                    Label("Load Demo Passport", systemImage: "sparkles")
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
}

#Preview {
    ContentView()
}

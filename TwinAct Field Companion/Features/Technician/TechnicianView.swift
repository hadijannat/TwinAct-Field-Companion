//
//  TechnicianView.swift
//  TwinAct Field Companion
//
//  Technician feature entry point.
//

import SwiftUI

public struct TechnicianView: View {
    @EnvironmentObject private var appState: AppState

    public init() {}

    public var body: some View {
        TechnicianConsoleView(assetId: appState.selectedAsset?.aasId)
    }
}

#Preview {
    TechnicianView()
        .environmentObject(AppState())
        .environmentObject(SyncEngine(
            persistence: PersistenceService(),
            repositoryService: RepositoryService()
        ))
}

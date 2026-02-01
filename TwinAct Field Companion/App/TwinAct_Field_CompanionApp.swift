//
//  TwinAct_Field_CompanionApp.swift
//  TwinAct Field Companion
//
//  Created by Hadi Jannat on 18.01.26.
//

import SwiftUI
import os.log

/// Logger for app lifecycle events
private let appLogger = Logger(subsystem: "com.twinact.fieldcompanion", category: "AppLifecycle")

@main
struct TwinAct_Field_CompanionApp: App {

    // MARK: - Dependencies

    @StateObject private var dependencyContainer: DependencyContainer
    @StateObject private var appState = AppState()
    @StateObject private var syncEngine: SyncEngine

    init() {
        AppConfiguration.applyLaunchOverrides()
        let container = DependencyContainer.shared
        let repositoryService: RepositoryServiceProtocol = container.repositoryService
        let engine = SyncEngine(
            persistence: PersistenceService(),
            repositoryService: repositoryService
        )
        _dependencyContainer = StateObject(wrappedValue: container)
        _syncEngine = StateObject(wrappedValue: engine)
        container.setSyncEngine(engine)
    }

    #if os(iOS)
    /// App delegate adapter for UIKit lifecycle events and background tasks
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #endif

    /// Monitors scene phase changes for lifecycle events
    @Environment(\.scenePhase) private var scenePhase

    // MARK: - Body

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(dependencyContainer)
                .environmentObject(appState)
                .environmentObject(syncEngine)
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            handleScenePhaseChange(from: oldPhase, to: newPhase)
        }
    }

    // MARK: - Lifecycle Handling

    /// Handles app lifecycle transitions based on scene phase changes
    private func handleScenePhaseChange(from oldPhase: ScenePhase, to newPhase: ScenePhase) {
        switch newPhase {
        case .active:
            // App is now active (visible and receiving events)
            if oldPhase == .background || oldPhase == .inactive {
                handleAppWillEnterForeground()
            }

            // Index knowledge on first activation (cold start)
            if oldPhase == .background {
                Task {
                    await indexKnowledgeIfNeeded()
                }
            }

        case .inactive:
            // App is transitioning (e.g., entering/leaving foreground)
            break

        case .background:
            // App has entered the background
            handleAppDidEnterBackground()

        @unknown default:
            break
        }
    }

    /// Called when the app is about to enter the foreground
    private func handleAppWillEnterForeground() {
        // Trigger sync when app comes to foreground
        dependencyContainer.handleAppWillEnterForeground()

        // Index knowledge on first foreground entry
        Task {
            await indexKnowledgeIfNeeded()
        }

        appLogger.info("App entering foreground - triggering sync check")
    }

    /// Index bundled knowledge documents if not already indexed
    private func indexKnowledgeIfNeeded() async {
        let indexer = dependencyContainer.knowledgeIndexer
        if await !indexer.hasIndexedKnowledge() {
            appLogger.info("Indexing bundled knowledge documents...")
            await dependencyContainer.indexBundledKnowledge()
        }
    }

    /// Called when the app has entered the background
    private func handleAppDidEnterBackground() {
        // Schedule background sync tasks
        dependencyContainer.handleAppDidEnterBackground()

        appLogger.info("App entering background - scheduling background sync")
    }
}

// MARK: - App Delegate Adapter (for UIKit lifecycle events if needed)

#if os(iOS)
/// App delegate for handling UIKit-specific lifecycle events and background tasks
class AppDelegate: NSObject, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Register background tasks
        registerBackgroundTasks()

        return true
    }

    /// Registers background task identifiers with the system
    private func registerBackgroundTasks() {
        SyncEngine.registerBackgroundTask()
        appLogger.info("Background tasks registered")
    }

    func application(
        _ application: UIApplication,
        performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        // Handle legacy background fetch
        Task { @MainActor in
            await DependencyContainer.shared.performSync()
            completionHandler(.newData)
        }
    }
}
#endif

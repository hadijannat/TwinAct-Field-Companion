//
//  TwinAct_Field_CompanionApp.swift
//  TwinAct Field Companion
//
//  Created by Hadi Jannat on 18.01.26.
//

import SwiftUI

@main
struct TwinAct_Field_CompanionApp: App {

    // MARK: - Dependencies

    #if os(iOS)
    /// App delegate adapter for UIKit lifecycle events and background tasks
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #endif

    /// The shared dependency container for the app.
    /// Using @ObservedObject with the singleton since DependencyContainer.shared
    /// manages its own lifecycle and is not owned by this App struct.
    @ObservedObject private var dependencyContainer = DependencyContainer.shared

    /// Monitors scene phase changes for lifecycle events
    @Environment(\.scenePhase) private var scenePhase

    // MARK: - Body

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(dependencyContainer)
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

        // TODO: Replace print() with os_log for structured logging
        #if DEBUG
        print("[TwinAct] App entering foreground - triggering sync check")
        #endif
    }

    /// Called when the app has entered the background
    private func handleAppDidEnterBackground() {
        // Schedule background sync tasks
        dependencyContainer.handleAppDidEnterBackground()

        // TODO: Replace print() with os_log for structured logging
        #if DEBUG
        print("[TwinAct] App entering background - scheduling background sync")
        #endif
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
        // Note: Background task registration requires BGTaskScheduler
        // This will be implemented when the full sync engine is built
        // TODO: Replace print() with os_log for structured logging
        #if DEBUG
        print("[TwinAct] Background tasks registered")
        #endif
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

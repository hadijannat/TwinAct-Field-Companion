//
//  AppConfiguration.swift
//  TwinAct Field Companion
//
//  App-wide configuration settings
//

import Foundation
import os.log

// MARK: - Logging

/// Logger for configuration-related events.
private let configLogger = Logger(subsystem: "com.twinact.fieldcompanion", category: "Configuration")

// MARK: - Demo Mode Notification

extension Notification.Name {
    /// Posted when demo mode is enabled or disabled.
    static let demoModeDidChange = Notification.Name("com.twinact.fieldcompanion.demoModeDidChange")
}

// MARK: - UserDefaults Extension

extension UserDefaults {
    /// Check if a key exists in UserDefaults.
    func contains(key: String) -> Bool {
        return object(forKey: key) != nil
    }
}

/// App configuration for different environments and settings
struct AppConfiguration {

    // MARK: - Environment

    enum Environment: String, CaseIterable {
        case development
        case staging
        case production
    }

    static let current: Environment = .development

    // MARK: - API Configuration

    static var baseURL: URL {
        guard let url = makeURL(for: current) else {
            configLogger.fault("Invalid base URL for environment '\(current.rawValue)'. This is a configuration error.")
            fatalError("""
                AppConfiguration: Invalid base URL for environment '\(current.rawValue)'.

                To fix this:
                1. Check that URL strings are valid URLs (no spaces, proper scheme)
                2. For staging/production, set environment variables:
                   - TWINACT_STAGING_API_URL
                   - TWINACT_PRODUCTION_API_URL
                   or add StagingAPIURL/ProductionAPIURL to Info.plist
                """)
        }
        return url
    }

    private static func makeURL(for environment: Environment) -> URL? {
        let urlString: String
        switch environment {
        case .development:
            // Check for environment variable override (useful for local testing against different servers)
            urlString = ProcessInfo.processInfo.environment["TWINACT_API_URL"] ?? "http://localhost:8080"
        case .staging:
            // Configure via TWINACT_STAGING_API_URL environment variable or Info.plist
            // Set this in your CI/CD pipeline or Xcode scheme for staging builds
            urlString = ProcessInfo.processInfo.environment["TWINACT_STAGING_API_URL"]
                ?? Bundle.main.infoDictionary?["StagingAPIURL"] as? String
                ?? "https://staging-api.twinact.example.com"
        case .production:
            // Configure via TWINACT_PRODUCTION_API_URL environment variable or Info.plist
            // Production URL should be set in the release build configuration
            urlString = ProcessInfo.processInfo.environment["TWINACT_PRODUCTION_API_URL"]
                ?? Bundle.main.infoDictionary?["ProductionAPIURL"] as? String
                ?? "https://api.twinact.example.com"
        }
        configLogger.debug("Base URL for \(environment.rawValue): \(urlString)")
        return URL(string: urlString)
    }

    // MARK: - AAS Server Configuration

    struct AASServer {
        /// URL for the AAS Registry (discovery of Asset Administration Shells)
        static var registryURL: URL {
            guard let url = URL(string: registryURLString) else {
                configLogger.fault("Invalid AAS registry URL: '\(registryURLString)'")
                fatalError("AppConfiguration.AASServer: Invalid registry URL. Set TWINACT_AAS_URL or check StagingAASURL/ProductionAASURL in Info.plist.")
            }
            return url
        }

        /// URL for the AAS Repository (CRUD operations on shells and submodels)
        static var repositoryURL: URL {
            guard let url = URL(string: repositoryURLString) else {
                configLogger.fault("Invalid AAS repository URL: '\(repositoryURLString)'")
                fatalError("AppConfiguration.AASServer: Invalid repository URL. Set TWINACT_AAS_URL or check StagingAASURL/ProductionAASURL in Info.plist.")
            }
            return url
        }

        /// URL for the AAS Discovery Service (asset ID to AAS ID mapping)
        static var discoveryURL: URL {
            guard let url = URL(string: discoveryURLString) else {
                configLogger.fault("Invalid AAS discovery URL: '\(discoveryURLString)'")
                fatalError("AppConfiguration.AASServer: Invalid discovery URL. Set TWINACT_AAS_URL or check StagingAASURL/ProductionAASURL in Info.plist.")
            }
            return url
        }

        /// Base URL for AAS services, configurable via environment variable or Info.plist
        private static var aasBaseURL: String {
            switch current {
            case .development:
                return ProcessInfo.processInfo.environment["TWINACT_AAS_URL"] ?? "http://localhost:8081"
            case .staging:
                return ProcessInfo.processInfo.environment["TWINACT_STAGING_AAS_URL"]
                    ?? Bundle.main.infoDictionary?["StagingAASURL"] as? String
                    ?? "https://staging-aas.twinact.example.com"
            case .production:
                return ProcessInfo.processInfo.environment["TWINACT_PRODUCTION_AAS_URL"]
                    ?? Bundle.main.infoDictionary?["ProductionAASURL"] as? String
                    ?? "https://aas.twinact.example.com"
            }
        }

        private static var registryURLString: String {
            let url = "\(aasBaseURL)/registry"
            configLogger.debug("AAS Registry URL for \(current.rawValue): \(url)")
            return url
        }

        private static var repositoryURLString: String {
            let url = "\(aasBaseURL)/repository"
            configLogger.debug("AAS Repository URL for \(current.rawValue): \(url)")
            return url
        }

        private static var discoveryURLString: String {
            let url = "\(aasBaseURL)/discovery"
            configLogger.debug("AAS Discovery URL for \(current.rawValue): \(url)")
            return url
        }

        /// Request timeout in seconds for AAS server connections
        static let requestTimeoutSeconds: TimeInterval = 30.0

        /// Maximum concurrent connections to AAS servers
        static let maxConcurrentConnections: Int = 4
    }

    // MARK: - GenAI Configuration

    struct GenAI {
        /// Whether to use on-device inference (e.g., Core ML models) vs cloud API
        static let useOnDeviceInference: Bool = {
            switch current {
            case .development:
                return true  // Use on-device for faster dev iteration
            case .staging, .production:
                return false // Use cloud for better quality in staging/prod
            }
        }()

        /// Cloud API endpoint for GenAI services (used when useOnDeviceInference is false)
        static var cloudAPIEndpoint: URL {
            guard let url = URL(string: cloudAPIEndpointString) else {
                configLogger.fault("Invalid GenAI cloud API endpoint: '\(cloudAPIEndpointString)'")
                fatalError("AppConfiguration.GenAI: Invalid cloud API endpoint. Set TWINACT_GENAI_URL or check StagingGenAIURL/ProductionGenAIURL in Info.plist.")
            }
            return url
        }

        private static var cloudAPIEndpointString: String {
            let url: String
            switch current {
            case .development:
                url = ProcessInfo.processInfo.environment["TWINACT_GENAI_URL"] ?? "http://localhost:8082/genai"
            case .staging:
                url = ProcessInfo.processInfo.environment["TWINACT_STAGING_GENAI_URL"]
                    ?? Bundle.main.infoDictionary?["StagingGenAIURL"] as? String
                    ?? "https://staging-genai.twinact.example.com/v1"
            case .production:
                url = ProcessInfo.processInfo.environment["TWINACT_PRODUCTION_GENAI_URL"]
                    ?? Bundle.main.infoDictionary?["ProductionGenAIURL"] as? String
                    ?? "https://genai.twinact.example.com/v1"
            }
            configLogger.debug("GenAI API URL for \(current.rawValue): \(url)")
            return url
        }

        /// Maximum tokens for GenAI responses
        static let maxResponseTokens: Int = 2048

        /// Temperature setting for GenAI inference (0.0 = deterministic, 1.0 = creative)
        static let inferenceTemperature: Double = 0.7
    }

    // MARK: - Offline Sync Configuration

    struct OfflineSync {
        /// Strategy for resolving conflicts between local and remote data
        enum ConflictResolutionStrategy: String, CaseIterable {
            /// Server data always wins
            case serverWins
            /// Local (client) data always wins
            case clientWins
            /// Most recent modification wins based on timestamp
            case lastWriteWins
            /// Prompt user to manually resolve conflicts
            case manualResolution
        }

        /// Interval between automatic sync attempts (in seconds)
        static let syncIntervalSeconds: TimeInterval = 300.0  // 5 minutes

        /// Maximum number of retry attempts for failed sync operations
        static let maxRetryAttempts: Int = 3

        /// Strategy for resolving data conflicts during sync
        static let conflictResolutionStrategy: ConflictResolutionStrategy = .lastWriteWins

        /// Delay between retry attempts (in seconds)
        static let retryDelaySeconds: TimeInterval = 5.0

        /// Maximum number of items to sync in a single batch
        static let batchSize: Int = 50

        /// Whether to sync only when on Wi-Fi (to save cellular data)
        static let syncOnlyOnWiFi: Bool = false
    }

    // MARK: - Feature Flags

    static let isAREnabled: Bool = true
    static let isVoiceEnabled: Bool = true

    // MARK: - Demo Mode

    /// UserDefaults key for demo mode setting
    private static let demoModeKey = "com.twinact.fieldcompanion.demoModeEnabled"
    /// UserDefaults key for onboarding completion
    private static let onboardingKey = "hasCompletedOnboarding"

    // MARK: - UI Testing

    /// Returns true when running under UI tests.
    static var isUITest: Bool {
        let args = ProcessInfo.processInfo.arguments
        let env = ProcessInfo.processInfo.environment
        return args.contains("--uitesting")
            || args.contains("UITEST_MODE")
            || env["UITEST_MODE"] == "1"
            || env["SIMULATED_QR"] != nil
            || env["XCTestConfigurationFilePath"] != nil
    }

    /// Optional simulated QR code value for UI tests.
    static var simulatedQRCode: String? {
        ProcessInfo.processInfo.environment["SIMULATED_QR"]
    }

    /// Apply launch-time overrides for UI testing.
    static func applyLaunchOverrides() {
        guard isUITest else { return }

        // Force a known-good boolean value for UI tests (avoids string defaults from launch args).
        let shouldSkipOnboarding = envFlag("UITEST_SKIP_ONBOARDING", defaultValue: true)
        UserDefaults.standard.set(shouldSkipOnboarding, forKey: onboardingKey)

        let shouldEnableDemoMode = envFlag("UITEST_DEMO_MODE", defaultValue: true)
        // Use setter to ensure demo mode observers invalidate cached services.
        AppConfiguration.isDemoMode = shouldEnableDemoMode
    }

    /// Whether the app is running in demo mode (no server connection required).
    /// Demo mode provides bundled sample data for App Store review and offline demos.
    public static var isDemoMode: Bool {
        get {
            // Default to true if key not set (for first launch / App Store review)
            if !UserDefaults.standard.contains(key: demoModeKey) {
                return true
            }
            return UserDefaults.standard.bool(forKey: demoModeKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: demoModeKey)
            NotificationCenter.default.post(name: .demoModeDidChange, object: nil)
        }
    }

    /// Enable demo mode.
    public static func enableDemoMode() {
        isDemoMode = true
    }

    /// Disable demo mode (requires server connection).
    public static func disableDemoMode() {
        isDemoMode = false
    }

    /// Toggle demo mode.
    public static func toggleDemoMode() {
        isDemoMode.toggle()
    }

    // MARK: - App Metadata

    struct AppInfo {
        static let appName = "TwinAct Field Companion"
        static let bundleIdentifier = Bundle.main.bundleIdentifier ?? "com.twinact.fieldcompanion"
        static let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        static let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
}

// MARK: - Environment Helpers

private extension AppConfiguration {
    static func envFlag(_ key: String, defaultValue: Bool) -> Bool {
        guard let raw = ProcessInfo.processInfo.environment[key]?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
              !raw.isEmpty else {
            return defaultValue
        }

        switch raw {
        case "1", "true", "yes", "y":
            return true
        case "0", "false", "no", "n":
            return false
        default:
            return defaultValue
        }
    }
}

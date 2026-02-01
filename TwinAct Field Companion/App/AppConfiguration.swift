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
    /// Posted when an AASX import completes.
    static let aasxImportDidComplete = Notification.Name("com.twinact.fieldcompanion.aasxImportDidComplete")
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

    static let current: Environment = {
        if let rawOverride = ProcessInfo.processInfo.environment["TWINACT_ENV"]
            ?? Bundle.main.infoDictionary?["AppEnvironment"] as? String {
            let normalized = rawOverride.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            switch normalized {
            case "dev", "development":
                return .development
            case "staging", "stage":
                return .staging
            case "prod", "production":
                return .production
            default:
                break
            }
        }

        if isUITest {
            return .development
        }

        #if DEBUG
        return .development
        #else
        return .production
        #endif
    }()

    // MARK: - API Configuration

    static var baseURL: URL {
        guard let url = makeURL(for: current) else {
            let fallback = URL(string: defaultAPIBaseURL(for: current)) ?? URL(string: "https://api.twinact.example.com")!
            configLogger.fault("Invalid base URL for environment '\(current.rawValue)'. Falling back to \(fallback.absoluteString, privacy: .public)")
            assertionFailure("AppConfiguration: Invalid base URL for environment '\(current.rawValue)'.")
            return fallback
        }
        return url
    }

    private static func makeURL(for environment: Environment) -> URL? {
        let urlString: String
        switch environment {
        case .development:
            // Check for environment variable override (useful for local testing against different servers)
            urlString = ProcessInfo.processInfo.environment["TWINACT_API_URL"] ?? defaultAPIBaseURL(for: .development)
        case .staging:
            // Configure via TWINACT_STAGING_API_URL environment variable or Info.plist
            // Set this in your CI/CD pipeline or Xcode scheme for staging builds
            urlString = ProcessInfo.processInfo.environment["TWINACT_STAGING_API_URL"]
                ?? Bundle.main.infoDictionary?["StagingAPIURL"] as? String
                ?? defaultAPIBaseURL(for: .staging)
        case .production:
            // Configure via TWINACT_PRODUCTION_API_URL environment variable or Info.plist
            // Production URL should be set in the release build configuration
            urlString = ProcessInfo.processInfo.environment["TWINACT_PRODUCTION_API_URL"]
                ?? Bundle.main.infoDictionary?["ProductionAPIURL"] as? String
                ?? defaultAPIBaseURL(for: .production)
        }
        configLogger.debug("Base URL for \(environment.rawValue): \(urlString)")
        return URL(string: urlString)
    }

    // MARK: - AAS Server Configuration

    struct AASServer {
        /// URL for the AAS Registry (discovery of Asset Administration Shells)
        static var registryURL: URL {
            makeAASURL(from: registryURLString, component: "registry", label: "registry")
        }

        /// URL for the AAS Repository (CRUD operations on shells and submodels)
        static var repositoryURL: URL {
            makeAASURL(from: repositoryURLString, component: "repository", label: "repository")
        }

        /// URL for the AAS Discovery Service (asset ID to AAS ID mapping)
        static var discoveryURL: URL {
            makeAASURL(from: discoveryURLString, component: "discovery", label: "discovery")
        }

        /// Base URL for AAS services, configurable via environment variable or Info.plist
        private static var aasBaseURL: String {
            let raw: String
            switch current {
            case .development:
                raw = ProcessInfo.processInfo.environment["TWINACT_AAS_URL"] ?? defaultAASBaseURL(for: .development)
            case .staging:
                raw = ProcessInfo.processInfo.environment["TWINACT_STAGING_AAS_URL"]
                    ?? Bundle.main.infoDictionary?["StagingAASURL"] as? String
                    ?? defaultAASBaseURL(for: .staging)
            case .production:
                raw = ProcessInfo.processInfo.environment["TWINACT_PRODUCTION_AAS_URL"]
                    ?? Bundle.main.infoDictionary?["ProductionAASURL"] as? String
                    ?? defaultAASBaseURL(for: .production)
            }

            guard URL(string: raw) != nil else {
                let fallback = defaultAASBaseURL(for: current)
                configLogger.fault("Invalid AAS base URL '\(raw, privacy: .public)'. Falling back to \(fallback, privacy: .public)")
                assertionFailure("AppConfiguration.AASServer: Invalid AAS base URL '\(raw)'.")
                return fallback
            }

            return raw
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

        private static func makeAASURL(from raw: String, component: String, label: String) -> URL {
            if let url = URL(string: raw) {
                return url
            }

            let fallbackBase = defaultAASBaseURL(for: current)
            let fallback = URL(string: fallbackBase)?.appendingPathComponent(component)
                ?? URL(string: "https://aas.twinact.example.com/\(component)")!
            configLogger.fault("Invalid AAS \(label) URL: '\(raw, privacy: .public)'. Falling back to \(fallback.absoluteString, privacy: .public)")
            assertionFailure("AppConfiguration.AASServer: Invalid \(label) URL.")
            return fallback
        }
    }

    // MARK: - Authentication Configuration

    struct Auth {
        /// OIDC issuer URL for authentication.
        static var issuerURL: URL {
            let raw: String
            switch current {
            case .development:
                raw = ProcessInfo.processInfo.environment["TWINACT_AUTH_URL"]
                    ?? Bundle.main.infoDictionary?["AuthIssuerURL"] as? String
                    ?? "http://localhost:8080/auth/realms/twinact"
            case .staging:
                raw = ProcessInfo.processInfo.environment["TWINACT_STAGING_AUTH_URL"]
                    ?? Bundle.main.infoDictionary?["StagingAuthIssuerURL"] as? String
                    ?? "https://staging-auth.example.com/realms/twinact"
            case .production:
                raw = ProcessInfo.processInfo.environment["TWINACT_PRODUCTION_AUTH_URL"]
                    ?? Bundle.main.infoDictionary?["ProductionAuthIssuerURL"] as? String
                    ?? "https://auth.example.com/realms/twinact"
            }

            guard let url = URL(string: raw) else {
                let fallback = URL(string: "https://auth.example.com/realms/twinact")!
                configLogger.fault("Invalid auth issuer URL '\(raw, privacy: .public)'. Falling back to \(fallback.absoluteString, privacy: .public)")
                assertionFailure("AppConfiguration.Auth: Invalid issuer URL.")
                return fallback
            }

            return url
        }

        /// OAuth client ID.
        static var clientId: String {
            ProcessInfo.processInfo.environment["TWINACT_AUTH_CLIENT_ID"]
                ?? Bundle.main.infoDictionary?["AuthClientId"] as? String
                ?? "twinact-mobile"
        }

        /// OAuth redirect URI.
        static var redirectURI: URL {
            let raw = ProcessInfo.processInfo.environment["TWINACT_AUTH_REDIRECT_URI"]
                ?? Bundle.main.infoDictionary?["AuthRedirectURI"] as? String
                ?? "twinact://callback"
            return URL(string: raw) ?? URL(string: "twinact://callback")!
        }

        /// Requested OAuth scopes.
        static var scopes: [String] {
            if let raw = ProcessInfo.processInfo.environment["TWINACT_AUTH_SCOPES"]
                ?? Bundle.main.infoDictionary?["AuthScopes"] as? String {
                let parsed = raw
                    .split(separator: " ")
                    .map { String($0) }
                    .filter { !$0.isEmpty }
                if !parsed.isEmpty {
                    return parsed
                }
            }
            return ["openid", "profile", "email", "aas"]
        }
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
                let fallback = URL(string: defaultGenAIBaseURL(for: current)) ?? URL(string: "https://genai.twinact.example.com/v1")!
                configLogger.fault("Invalid GenAI cloud API endpoint: '\(cloudAPIEndpointString, privacy: .public)'. Falling back to \(fallback.absoluteString, privacy: .public)")
                assertionFailure("AppConfiguration.GenAI: Invalid cloud API endpoint.")
                return fallback
            }
            return url
        }

        private static var cloudAPIEndpointString: String {
            let url: String
            switch current {
            case .development:
                url = ProcessInfo.processInfo.environment["TWINACT_GENAI_URL"] ?? defaultGenAIBaseURL(for: .development)
            case .staging:
                url = ProcessInfo.processInfo.environment["TWINACT_STAGING_GENAI_URL"]
                    ?? Bundle.main.infoDictionary?["StagingGenAIURL"] as? String
                    ?? defaultGenAIBaseURL(for: .staging)
            case .production:
                url = ProcessInfo.processInfo.environment["TWINACT_PRODUCTION_GENAI_URL"]
                    ?? Bundle.main.infoDictionary?["ProductionGenAIURL"] as? String
                    ?? defaultGenAIBaseURL(for: .production)
            }
            configLogger.debug("GenAI API URL for \(current.rawValue): \(url)")
            return url
        }

        /// Maximum tokens for GenAI responses
        static let maxResponseTokens: Int = 2048

        /// Temperature setting for GenAI inference (0.0 = deterministic, 1.0 = creative)
        static let inferenceTemperature: Double = 0.7

        // MARK: - Glossary / Jargon Buster

        /// Whether to enable LLM fallback for unknown glossary terms
        static let enableGlossaryLLMFallback: Bool = true

        /// Maximum number of cached dynamic glossary entries
        static let glossaryMaxCachedTerms: Int = 200

        /// Cache expiration for LLM-generated glossary entries (in seconds)
        static let glossaryCacheExpiration: TimeInterval = 86400 * 7  // 7 days

        // MARK: - Multi-Provider Configuration

        /// Default cloud provider type when none is configured
        static let defaultProviderType: AIProviderType = .anthropic

        /// Timeout for provider connection tests (in seconds)
        static let connectionTestTimeout: TimeInterval = 10.0

        /// Maximum time to wait for a chat response before timing out (in seconds)
        static let chatGenerationTimeoutSeconds: TimeInterval = {
            if let raw = ProcessInfo.processInfo.environment["TWINACT_CHAT_TIMEOUT"],
               let value = Double(raw.trimmingCharacters(in: .whitespacesAndNewlines)),
               value > 0 {
                return value
            }
            return 60.0
        }()
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
                return defaultDemoMode
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

    static func envFlagOptional(_ key: String) -> Bool? {
        guard let raw = ProcessInfo.processInfo.environment[key]?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
              !raw.isEmpty else {
            return nil
        }

        switch raw {
        case "1", "true", "yes", "y":
            return true
        case "0", "false", "no", "n":
            return false
        default:
            return nil
        }
    }

    static func defaultAPIBaseURL(for environment: Environment) -> String {
        switch environment {
        case .development:
            return "http://localhost:8080"
        case .staging:
            return "https://staging-api.twinact.example.com"
        case .production:
            return "https://api.twinact.example.com"
        }
    }

    static func defaultAASBaseURL(for environment: Environment) -> String {
        switch environment {
        case .development:
            return "http://localhost:8081"
        case .staging:
            return "https://staging-aas.twinact.example.com"
        case .production:
            return "https://aas.twinact.example.com"
        }
    }

    static func defaultGenAIBaseURL(for environment: Environment) -> String {
        switch environment {
        case .development:
            return "http://localhost:8082/genai"
        case .staging:
            return "https://staging-genai.twinact.example.com/v1"
        case .production:
            return "https://genai.twinact.example.com/v1"
        }
    }

    static var defaultDemoMode: Bool {
        if let override = envFlagOptional("TWINACT_DEMO_MODE_DEFAULT") {
            return override
        }

        if let infoValue = Bundle.main.infoDictionary?["DefaultDemoMode"] as? Bool {
            return infoValue
        }

        if isUITest {
            return true
        }

        switch current {
        case .development:
            return true
        case .staging, .production:
            return false
        }
    }
}

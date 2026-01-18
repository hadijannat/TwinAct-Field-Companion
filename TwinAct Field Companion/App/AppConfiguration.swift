//
//  AppConfiguration.swift
//  TwinAct Field Companion
//
//  App-wide configuration settings
//

import Foundation

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
            fatalError("AppConfiguration: Invalid base URL for environment '\(current.rawValue)'. Check URL string format.")
        }
        return url
    }

    private static func makeURL(for environment: Environment) -> URL? {
        let urlString: String
        switch environment {
        case .development:
            urlString = "http://localhost:8080"
        case .staging:
            // TODO: Replace with actual staging API URL before deployment
            urlString = "https://staging-api.example.com"
        case .production:
            // TODO: Replace with actual production API URL before deployment
            urlString = "https://api.example.com"
        }
        return URL(string: urlString)
    }

    // MARK: - AAS Server Configuration

    struct AASServer {
        /// URL for the AAS Registry (discovery of Asset Administration Shells)
        static var registryURL: URL {
            guard let url = URL(string: registryURLString) else {
                fatalError("AppConfiguration.AASServer: Invalid registry URL '\(registryURLString)'. Check URL string format.")
            }
            return url
        }

        /// URL for the AAS Repository (CRUD operations on shells and submodels)
        static var repositoryURL: URL {
            guard let url = URL(string: repositoryURLString) else {
                fatalError("AppConfiguration.AASServer: Invalid repository URL '\(repositoryURLString)'. Check URL string format.")
            }
            return url
        }

        /// URL for the AAS Discovery Service (asset ID to AAS ID mapping)
        static var discoveryURL: URL {
            guard let url = URL(string: discoveryURLString) else {
                fatalError("AppConfiguration.AASServer: Invalid discovery URL '\(discoveryURLString)'. Check URL string format.")
            }
            return url
        }

        private static var registryURLString: String {
            switch current {
            case .development:
                return "http://localhost:8081/registry"
            case .staging:
                // TODO: Replace with actual staging AAS registry URL
                return "https://staging-aas.example.com/registry"
            case .production:
                // TODO: Replace with actual production AAS registry URL
                return "https://aas.example.com/registry"
            }
        }

        private static var repositoryURLString: String {
            switch current {
            case .development:
                return "http://localhost:8081/repository"
            case .staging:
                // TODO: Replace with actual staging AAS repository URL
                return "https://staging-aas.example.com/repository"
            case .production:
                // TODO: Replace with actual production AAS repository URL
                return "https://aas.example.com/repository"
            }
        }

        private static var discoveryURLString: String {
            switch current {
            case .development:
                return "http://localhost:8081/discovery"
            case .staging:
                // TODO: Replace with actual staging AAS discovery URL
                return "https://staging-aas.example.com/discovery"
            case .production:
                // TODO: Replace with actual production AAS discovery URL
                return "https://aas.example.com/discovery"
            }
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
                fatalError("AppConfiguration.GenAI: Invalid cloud API endpoint '\(cloudAPIEndpointString)'. Check URL string format.")
            }
            return url
        }

        private static var cloudAPIEndpointString: String {
            switch current {
            case .development:
                return "http://localhost:8082/genai"
            case .staging:
                // TODO: Replace with actual staging GenAI API URL
                return "https://staging-genai.example.com/v1"
            case .production:
                // TODO: Replace with actual production GenAI API URL
                return "https://genai.example.com/v1"
            }
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
    static let isDemoMode: Bool = true

    // MARK: - App Metadata

    struct AppInfo {
        static let appName = "TwinAct Field Companion"
        static let bundleIdentifier = Bundle.main.bundleIdentifier ?? "com.twinact.fieldcompanion"
        static let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        static let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
}

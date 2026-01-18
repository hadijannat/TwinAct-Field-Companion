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

    enum Environment {
        case development
        case staging
        case production
    }

    static let current: Environment = .development

    // MARK: - API Configuration

    static var baseURL: URL {
        switch current {
        case .development:
            return URL(string: "http://localhost:8080")!
        case .staging:
            return URL(string: "https://staging-api.example.com")!
        case .production:
            return URL(string: "https://api.example.com")!
        }
    }

    // MARK: - Feature Flags

    static let isAREnabled: Bool = true
    static let isVoiceEnabled: Bool = true
    static let isDemoMode: Bool = true

    // TODO: Add additional configuration options
}

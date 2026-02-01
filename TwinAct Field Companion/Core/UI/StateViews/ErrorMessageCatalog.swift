//
//  ErrorMessageCatalog.swift
//  TwinAct Field Companion
//
//  Maps technical errors to user-friendly messages.
//

import Foundation

// MARK: - Error Message Catalog

/// Provides user-friendly error messages for technical errors.
public struct ErrorMessageCatalog {

    // MARK: - Error Classification

    /// Classifies an error into an AppErrorType.
    public static func classify(_ error: Error) -> AppErrorType {
        // Check for URLError (network errors)
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed:
                return .offline
            case .timedOut, .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed:
                return .network
            case .userAuthenticationRequired:
                return .authentication
            case .badServerResponse, .cannotParseResponse:
                return .server
            default:
                return .network
            }
        }

        // Check for decoding errors
        if error is DecodingError {
            return .data
        }

        // Check error description for hints
        let description = error.localizedDescription.lowercased()

        if description.contains("network") || description.contains("internet") ||
           description.contains("connection") || description.contains("offline") {
            return .network
        }

        if description.contains("unauthorized") || description.contains("authentication") ||
           description.contains("login") || description.contains("credentials") {
            return .authentication
        }

        if description.contains("permission") || description.contains("access denied") ||
           description.contains("not allowed") {
            return .permission
        }

        if description.contains("server") || description.contains("500") ||
           description.contains("503") || description.contains("502") {
            return .server
        }

        if description.contains("parse") || description.contains("decode") ||
           description.contains("invalid") || description.contains("format") {
            return .data
        }

        return .generic
    }

    // MARK: - User-Friendly Messages

    /// Returns a user-friendly message for an error.
    public static func friendlyMessage(for error: Error) -> String {
        let errorType = classify(error)

        // Check for specific error types first
        if let urlError = error as? URLError {
            return friendlyMessage(for: urlError)
        }

        if let decodingError = error as? DecodingError {
            return friendlyMessage(for: decodingError)
        }

        // Fall back to error type defaults
        return errorType.defaultMessage
    }

    // MARK: - URLError Messages

    private static func friendlyMessage(for urlError: URLError) -> String {
        switch urlError.code {
        case .notConnectedToInternet:
            return "No internet connection. Please check your Wi-Fi or cellular data and try again."

        case .networkConnectionLost:
            return "Your connection was interrupted. Please check your network and try again."

        case .timedOut:
            return "The request took too long. Please check your connection and try again."

        case .cannotConnectToHost, .cannotFindHost:
            return "Unable to reach the server. The service may be temporarily unavailable."

        case .dnsLookupFailed:
            return "Unable to find the server. Please check your internet connection."

        case .badServerResponse:
            return "The server sent an unexpected response. Please try again later."

        case .userAuthenticationRequired:
            return "Please sign in to continue."

        case .cancelled:
            return "The request was cancelled."

        case .dataNotAllowed:
            return "Data access is not available. Please check your cellular data settings."

        case .secureConnectionFailed:
            return "Could not establish a secure connection. Please try again."

        default:
            return "A network error occurred. Please check your connection and try again."
        }
    }

    // MARK: - DecodingError Messages

    private static func friendlyMessage(for decodingError: DecodingError) -> String {
        switch decodingError {
        case .dataCorrupted:
            return "The data received from the server was corrupted. Please try again."

        case .keyNotFound:
            return "Some expected data was missing. The server response may have changed."

        case .typeMismatch:
            return "The data format was unexpected. Please update the app or try again later."

        case .valueNotFound:
            return "Required information was missing from the server response."

        @unknown default:
            return "There was a problem reading the data. Please try again."
        }
    }

    // MARK: - Recovery Suggestions

    /// Returns actionable recovery suggestions for an error type.
    public static func recoverySuggestions(for errorType: AppErrorType) -> [String] {
        switch errorType {
        case .network:
            return [
                "Check your Wi-Fi or cellular connection",
                "Move to an area with better signal",
                "Try again in a few moments"
            ]

        case .offline:
            return [
                "Connect to Wi-Fi or enable cellular data",
                "Use Demo Mode to explore with sample data",
                "Your changes will sync when back online"
            ]

        case .authentication:
            return [
                "Sign in with your credentials",
                "Check that your account is active",
                "Contact support if the issue persists"
            ]

        case .server:
            return [
                "Wait a few minutes and try again",
                "The server may be under maintenance",
                "Use Demo Mode to continue working offline"
            ]

        case .data:
            return [
                "Try refreshing the content",
                "Clear the app cache in Settings",
                "Contact support if the issue persists"
            ]

        case .permission:
            return [
                "Open Settings to grant the required permission",
                "The app needs this permission to function properly"
            ]

        case .generic:
            return [
                "Try again in a few moments",
                "Restart the app if the issue persists",
                "Contact support for help"
            ]
        }
    }
}

// MARK: - Error Extension

extension Error {
    /// The classified error type for this error.
    var appErrorType: AppErrorType {
        ErrorMessageCatalog.classify(self)
    }

    /// A user-friendly message for this error.
    var friendlyMessage: String {
        ErrorMessageCatalog.friendlyMessage(for: self)
    }

    /// Recovery suggestions for this error.
    var recoverySuggestions: [String] {
        ErrorMessageCatalog.recoverySuggestions(for: self.appErrorType)
    }
}

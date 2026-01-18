//
//  AASError.swift
//  TwinAct Field Companion
//
//  Comprehensive error types for AAS API operations.
//

import Foundation

// MARK: - AAS Error

/// Errors that can occur during AAS API operations.
public enum AASError: Error, LocalizedError, Sendable {

    // MARK: - Not Found Errors

    /// AAS shell not found
    case shellNotFound(identifier: String)

    /// Submodel not found
    case submodelNotFound(identifier: String)

    /// Submodel element not found at path
    case elementNotFound(path: String)

    /// Concept description not found
    case conceptDescriptionNotFound(identifier: String)

    // MARK: - Response Errors

    /// Invalid or unexpected response from server
    case invalidResponse(message: String)

    /// Failed to decode response
    case decodingError(message: String, underlying: Error?)

    /// Failed to encode request
    case encodingError(identifier: String)

    // MARK: - Network Errors

    /// Network error occurred
    case networkError(underlying: Error)

    /// Request timed out
    case timeout

    /// Server is unreachable
    case serverUnreachable

    // MARK: - Authentication/Authorization

    /// Authentication required (401)
    case unauthorized

    /// Access forbidden (403)
    case forbidden

    // MARK: - Server Errors

    /// Server returned an error
    case serverError(statusCode: Int, message: String?)

    /// Rate limited (429)
    case rateLimited(retryAfter: TimeInterval?)

    // MARK: - Validation Errors

    /// Invalid identifier format
    case invalidIdentifier(value: String, reason: String)

    /// Invalid idShort path
    case invalidPath(path: String, reason: String)

    /// Validation failed
    case validationError(message: String)

    // MARK: - Operation Errors

    /// Operation invocation failed
    case operationFailed(idShort: String, message: String?)

    /// Operation timed out
    case operationTimeout(idShort: String)

    // MARK: - Conflict Errors

    /// Resource already exists
    case conflict(identifier: String)

    /// Concurrent modification detected
    case concurrentModification(identifier: String)

    // MARK: - LocalizedError Implementation

    public var errorDescription: String? {
        switch self {
        case .shellNotFound(let identifier):
            return "Asset Administration Shell not found: \(identifier)"

        case .submodelNotFound(let identifier):
            return "Submodel not found: \(identifier)"

        case .elementNotFound(let path):
            return "Submodel element not found at path: \(path)"

        case .conceptDescriptionNotFound(let identifier):
            return "Concept description not found: \(identifier)"

        case .invalidResponse(let message):
            return "Invalid response: \(message)"

        case .decodingError(let message, _):
            return "Failed to decode response: \(message)"

        case .encodingError(let identifier):
            return "Failed to encode identifier: \(identifier)"

        case .networkError(let underlying):
            return "Network error: \(underlying.localizedDescription)"

        case .timeout:
            return "Request timed out"

        case .serverUnreachable:
            return "Server is unreachable"

        case .unauthorized:
            return "Authentication required"

        case .forbidden:
            return "Access forbidden"

        case .serverError(let statusCode, let message):
            if let message = message {
                return "Server error (\(statusCode)): \(message)"
            }
            return "Server error with status code \(statusCode)"

        case .rateLimited(let retryAfter):
            if let retryAfter = retryAfter {
                return "Rate limited. Retry after \(Int(retryAfter)) seconds"
            }
            return "Rate limited"

        case .invalidIdentifier(let value, let reason):
            return "Invalid identifier '\(value)': \(reason)"

        case .invalidPath(let path, let reason):
            return "Invalid path '\(path)': \(reason)"

        case .validationError(let message):
            return "Validation error: \(message)"

        case .operationFailed(let idShort, let message):
            if let message = message {
                return "Operation '\(idShort)' failed: \(message)"
            }
            return "Operation '\(idShort)' failed"

        case .operationTimeout(let idShort):
            return "Operation '\(idShort)' timed out"

        case .conflict(let identifier):
            return "Resource already exists: \(identifier)"

        case .concurrentModification(let identifier):
            return "Concurrent modification detected for: \(identifier)"
        }
    }

    public var failureReason: String? {
        switch self {
        case .shellNotFound:
            return "The requested AAS does not exist in the registry or repository"

        case .submodelNotFound:
            return "The requested submodel does not exist"

        case .elementNotFound:
            return "The requested submodel element does not exist at the specified path"

        case .unauthorized:
            return "Valid authentication credentials are required"

        case .forbidden:
            return "You do not have permission to access this resource"

        case .rateLimited:
            return "Too many requests have been made in a short period"

        case .serverError(let statusCode, _):
            if statusCode >= 500 && statusCode < 600 {
                return "The server encountered an internal error"
            }
            return nil

        default:
            return nil
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .shellNotFound, .submodelNotFound, .elementNotFound:
            return "Verify the identifier is correct and the resource exists"

        case .unauthorized:
            return "Please sign in and try again"

        case .forbidden:
            return "Contact your administrator for access"

        case .rateLimited(let retryAfter):
            if let retryAfter = retryAfter {
                return "Wait \(Int(retryAfter)) seconds before retrying"
            }
            return "Wait a moment before retrying"

        case .networkError, .serverUnreachable:
            return "Check your internet connection and try again"

        case .timeout:
            return "Try again with a smaller request or check your connection"

        case .serverError:
            return "Try again later. If the problem persists, contact support"

        default:
            return nil
        }
    }

    // MARK: - Error Classification

    /// Whether this error indicates a transient condition that may succeed on retry.
    public var isRetryable: Bool {
        switch self {
        case .networkError, .timeout, .serverUnreachable, .rateLimited, .serverError:
            return true
        case .operationTimeout:
            return true
        default:
            return false
        }
    }

    /// Whether this error indicates the resource was not found.
    public var isNotFound: Bool {
        switch self {
        case .shellNotFound, .submodelNotFound, .elementNotFound, .conceptDescriptionNotFound:
            return true
        default:
            return false
        }
    }

    /// Whether this error indicates an authentication/authorization problem.
    public var isAuthError: Bool {
        switch self {
        case .unauthorized, .forbidden:
            return true
        default:
            return false
        }
    }

    /// HTTP status code associated with this error, if applicable.
    public var statusCode: Int? {
        switch self {
        case .shellNotFound, .submodelNotFound, .elementNotFound, .conceptDescriptionNotFound:
            return 404
        case .unauthorized:
            return 401
        case .forbidden:
            return 403
        case .rateLimited:
            return 429
        case .serverError(let code, _):
            return code
        case .conflict, .concurrentModification:
            return 409
        default:
            return nil
        }
    }
}

// MARK: - AAS Error Mapping

extension AASError {
    /// Create an AAS error from an HTTP error.
    public static func from(_ httpError: HTTPError, context: String? = nil) -> AASError {
        switch httpError {
        case .unauthorized:
            return .unauthorized

        case .forbidden:
            return .forbidden

        case .notFound:
            if let context = context {
                return .submodelNotFound(identifier: context)
            }
            return .invalidResponse(message: "Resource not found")

        case .tooManyRequests:
            return .rateLimited(retryAfter: nil)

        case .serverError(let statusCode):
            return .serverError(statusCode: statusCode, message: nil)

        case .httpError(let statusCode, let data):
            let message = data.flatMap { String(data: $0, encoding: .utf8) }
            return .serverError(statusCode: statusCode, message: message)

        case .timeout:
            return .timeout

        case .networkError(let underlying):
            return .networkError(underlying: underlying)

        case .decodingError(let underlying):
            return .decodingError(message: underlying.localizedDescription, underlying: underlying)

        case .invalidURL:
            return .invalidResponse(message: "Invalid URL")

        case .cancelled:
            return .networkError(underlying: httpError)
        }
    }
}

// MARK: - AAS Result Type

/// Result type alias for AAS operations.
public typealias AASResult<T> = Result<T, AASError>

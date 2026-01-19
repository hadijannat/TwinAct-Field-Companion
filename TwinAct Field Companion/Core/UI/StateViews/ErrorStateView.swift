//
//  ErrorStateView.swift
//  TwinAct Field Companion
//
//  Reusable error state views for consistent error handling UX.
//

import SwiftUI

// MARK: - Error Type

/// Categorized error types for consistent UI representation.
public enum AppErrorType {
    /// Network-related errors
    case network
    /// Authentication or authorization errors
    case authentication
    /// Server-side errors
    case server
    /// Data parsing or validation errors
    case data
    /// Permission-related errors (camera, location, etc.)
    case permission
    /// Generic or unknown errors
    case generic
    /// Offline state (not necessarily an error)
    case offline

    /// System icon for this error type
    var icon: String {
        switch self {
        case .network: return "wifi.slash"
        case .authentication: return "lock.shield"
        case .server: return "exclamationmark.icloud"
        case .data: return "exclamationmark.triangle"
        case .permission: return "hand.raised.slash"
        case .generic: return "exclamationmark.circle"
        case .offline: return "icloud.slash"
        }
    }

    /// Default title for this error type
    var defaultTitle: String {
        switch self {
        case .network: return "Connection Error"
        case .authentication: return "Authentication Required"
        case .server: return "Server Error"
        case .data: return "Data Error"
        case .permission: return "Permission Required"
        case .generic: return "Something Went Wrong"
        case .offline: return "You're Offline"
        }
    }

    /// Default message for this error type
    var defaultMessage: String {
        switch self {
        case .network:
            return "Unable to connect to the server. Please check your internet connection and try again."
        case .authentication:
            return "Please sign in to access this feature."
        case .server:
            return "The server encountered an error. Please try again later."
        case .data:
            return "There was a problem processing the data. Please try again."
        case .permission:
            return "This feature requires additional permissions. Please update your settings."
        case .generic:
            return "An unexpected error occurred. Please try again."
        case .offline:
            return "Some features require an internet connection. Your changes will sync when you're back online."
        }
    }

    /// Icon color for this error type
    var iconColor: Color {
        switch self {
        case .network, .offline: return .gray
        case .authentication: return .orange
        case .server: return .red
        case .data: return .yellow
        case .permission: return .purple
        case .generic: return .orange
        }
    }
}

// MARK: - Error State View

/// A reusable error state view with consistent styling.
public struct ErrorStateView: View {

    // MARK: - Properties

    let errorType: AppErrorType
    let title: String?
    let message: String?
    let retryAction: (() -> Void)?
    let secondaryAction: (() -> Void)?
    let secondaryActionTitle: String?

    // MARK: - Initialization

    /// Initialize with error type and optional customizations.
    /// - Parameters:
    ///   - errorType: The type of error to display
    ///   - title: Custom title (defaults to error type's title)
    ///   - message: Custom message (defaults to error type's message)
    ///   - retryAction: Optional retry action
    ///   - secondaryAction: Optional secondary action
    ///   - secondaryActionTitle: Title for secondary action button
    public init(
        errorType: AppErrorType,
        title: String? = nil,
        message: String? = nil,
        retryAction: (() -> Void)? = nil,
        secondaryAction: (() -> Void)? = nil,
        secondaryActionTitle: String? = nil
    ) {
        self.errorType = errorType
        self.title = title
        self.message = message
        self.retryAction = retryAction
        self.secondaryAction = secondaryAction
        self.secondaryActionTitle = secondaryActionTitle
    }

    // MARK: - Body

    public var body: some View {
        VStack(spacing: 24) {
            // Icon
            ZStack {
                Circle()
                    .fill(errorType.iconColor.opacity(0.15))
                    .frame(width: 80, height: 80)

                Image(systemName: errorType.icon)
                    .font(.system(size: 36))
                    .foregroundColor(errorType.iconColor)
            }

            // Text content
            VStack(spacing: 8) {
                Text(title ?? errorType.defaultTitle)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)

                Text(message ?? errorType.defaultMessage)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            // Actions
            if retryAction != nil || secondaryAction != nil {
                VStack(spacing: 12) {
                    if let retryAction = retryAction {
                        Button(action: retryAction) {
                            HStack {
                                Image(systemName: "arrow.clockwise")
                                Text("Try Again")
                            }
                            .frame(minWidth: 120)
                        }
                        .buttonStyle(.borderedProminent)
                    }

                    if let secondaryAction = secondaryAction {
                        Button(action: secondaryAction) {
                            Text(secondaryActionTitle ?? "Cancel")
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Compact Error Banner

/// A compact error banner for inline error display.
public struct ErrorBannerView: View {

    // MARK: - Properties

    let errorType: AppErrorType
    let message: String?
    let dismissAction: (() -> Void)?
    let retryAction: (() -> Void)?

    // MARK: - Initialization

    public init(
        errorType: AppErrorType,
        message: String? = nil,
        dismissAction: (() -> Void)? = nil,
        retryAction: (() -> Void)? = nil
    ) {
        self.errorType = errorType
        self.message = message
        self.dismissAction = dismissAction
        self.retryAction = retryAction
    }

    // MARK: - Body

    public var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: errorType.icon)
                .font(.system(size: 20))
                .foregroundColor(errorType.iconColor)
                .frame(width: 28)

            // Message
            Text(message ?? errorType.defaultTitle)
                .font(.subheadline)
                .foregroundColor(.primary)
                .lineLimit(2)

            Spacer()

            // Actions
            HStack(spacing: 8) {
                if let retryAction = retryAction {
                    Button(action: retryAction) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                if let dismissAction = dismissAction {
                    Button(action: dismissAction) {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(errorType.iconColor.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Offline Banner

/// A specialized banner for offline state indication.
public struct OfflineBannerView: View {

    let pendingChangesCount: Int

    public init(pendingChangesCount: Int = 0) {
        self.pendingChangesCount = pendingChangesCount
    }

    public var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "icloud.slash")
                .font(.system(size: 16))
                .foregroundColor(.gray)

            VStack(alignment: .leading, spacing: 2) {
                Text("Offline Mode")
                    .font(.subheadline)
                    .fontWeight(.medium)

                if pendingChangesCount > 0 {
                    Text("\(pendingChangesCount) change\(pendingChangesCount == 1 ? "" : "s") pending sync")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Image(systemName: "wifi.slash")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(.tertiarySystemBackground))
    }
}

// MARK: - Error State Modifier

/// View modifier for easily adding error state overlays.
public struct ErrorStateModifier: ViewModifier {

    let error: Error?
    let errorType: AppErrorType
    let retryAction: (() -> Void)?

    public func body(content: Content) -> some View {
        ZStack {
            content

            if error != nil {
                ErrorStateView(
                    errorType: errorType,
                    message: error?.localizedDescription,
                    retryAction: retryAction
                )
                .background(Color(.systemBackground))
            }
        }
    }
}

extension View {
    /// Add an error state overlay when an error is present.
    public func errorState(
        _ error: Error?,
        type: AppErrorType = .generic,
        retryAction: (() -> Void)? = nil
    ) -> some View {
        modifier(ErrorStateModifier(error: error, errorType: type, retryAction: retryAction))
    }
}

// MARK: - Preview

#if DEBUG
struct ErrorStateView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ErrorStateView(errorType: .network, retryAction: {})
                .previewDisplayName("Network Error")

            ErrorStateView(errorType: .authentication, retryAction: {}, secondaryAction: {}, secondaryActionTitle: "Cancel")
                .previewDisplayName("Auth Error")

            ErrorStateView(errorType: .offline)
                .previewDisplayName("Offline")

            VStack {
                ErrorBannerView(errorType: .network, message: "Unable to connect", dismissAction: {}, retryAction: {})
                    .padding()

                ErrorBannerView(errorType: .data, message: "Failed to load data")
                    .padding()

                OfflineBannerView(pendingChangesCount: 3)
            }
            .previewDisplayName("Banners")
        }
    }
}
#endif

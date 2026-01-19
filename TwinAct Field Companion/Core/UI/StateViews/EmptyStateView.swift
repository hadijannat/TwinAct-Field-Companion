//
//  EmptyStateView.swift
//  TwinAct Field Companion
//
//  Reusable empty state views for consistent UX across the app.
//

import SwiftUI

// MARK: - Empty State Type

/// Predefined empty state types for common scenarios.
public enum EmptyStateType {
    /// No assets discovered yet
    case noAssets
    /// No asset selected
    case noAssetSelected
    /// No service requests
    case noServiceRequests
    /// No documents
    case noDocuments
    /// No maintenance instructions
    case noMaintenance
    /// No time series data
    case noTimeSeriesData
    /// No search results
    case noSearchResults
    /// No chat history
    case noChatHistory
    /// Generic empty state
    case empty

    /// System icon for this empty state
    var icon: String {
        switch self {
        case .noAssets: return "cube.transparent"
        case .noAssetSelected: return "tag.slash"
        case .noServiceRequests: return "wrench.and.screwdriver"
        case .noDocuments: return "doc.text"
        case .noMaintenance: return "checklist"
        case .noTimeSeriesData: return "chart.line.flattrend.xyaxis"
        case .noSearchResults: return "magnifyingglass"
        case .noChatHistory: return "bubble.left.and.bubble.right"
        case .empty: return "tray"
        }
    }

    /// Default title for this empty state
    var defaultTitle: String {
        switch self {
        case .noAssets: return "No Assets Found"
        case .noAssetSelected: return "No Asset Selected"
        case .noServiceRequests: return "No Service Requests"
        case .noDocuments: return "No Documents"
        case .noMaintenance: return "No Maintenance Instructions"
        case .noTimeSeriesData: return "No Sensor Data"
        case .noSearchResults: return "No Results Found"
        case .noChatHistory: return "No Messages Yet"
        case .empty: return "Nothing Here"
        }
    }

    /// Default description for this empty state
    var defaultDescription: String {
        switch self {
        case .noAssets:
            return "Scan a QR code or search for an asset to get started."
        case .noAssetSelected:
            return "Scan an asset QR code or search manually to view its Digital Product Passport."
        case .noServiceRequests:
            return "Create a new service request to track maintenance and repairs."
        case .noDocuments:
            return "No documentation is available for this asset."
        case .noMaintenance:
            return "No maintenance instructions have been added for this asset."
        case .noTimeSeriesData:
            return "No sensor data is available for the selected time period."
        case .noSearchResults:
            return "Try adjusting your search or filters to find what you're looking for."
        case .noChatHistory:
            return "Start a conversation by asking a question about this asset."
        case .empty:
            return "There's nothing to display here yet."
        }
    }

    /// Icon color for this empty state
    var iconColor: Color {
        switch self {
        case .noAssets, .noAssetSelected: return .blue
        case .noServiceRequests: return .orange
        case .noDocuments: return .purple
        case .noMaintenance: return .green
        case .noTimeSeriesData: return .cyan
        case .noSearchResults: return .gray
        case .noChatHistory: return .indigo
        case .empty: return .secondary
        }
    }
}

// MARK: - Empty State View

/// A reusable empty state view with consistent styling.
public struct EmptyStateView: View {

    // MARK: - Properties

    let type: EmptyStateType
    let title: String?
    let description: String?
    let actionTitle: String?
    let action: (() -> Void)?
    let secondaryActionTitle: String?
    let secondaryAction: (() -> Void)?

    // MARK: - Initialization

    /// Initialize with empty state type and optional customizations.
    /// - Parameters:
    ///   - type: The type of empty state to display
    ///   - title: Custom title (defaults to type's title)
    ///   - description: Custom description (defaults to type's description)
    ///   - actionTitle: Title for the primary action button
    ///   - action: Primary action closure
    ///   - secondaryActionTitle: Title for secondary action button
    ///   - secondaryAction: Secondary action closure
    public init(
        type: EmptyStateType,
        title: String? = nil,
        description: String? = nil,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil,
        secondaryActionTitle: String? = nil,
        secondaryAction: (() -> Void)? = nil
    ) {
        self.type = type
        self.title = title
        self.description = description
        self.actionTitle = actionTitle
        self.action = action
        self.secondaryActionTitle = secondaryActionTitle
        self.secondaryAction = secondaryAction
    }

    // MARK: - Body

    public var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(type.iconColor.opacity(0.12))
                    .frame(width: 100, height: 100)

                Image(systemName: type.icon)
                    .font(.system(size: 44))
                    .foregroundColor(type.iconColor)
            }

            // Text content
            VStack(spacing: 8) {
                Text(title ?? type.defaultTitle)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)

                Text(description ?? type.defaultDescription)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            // Actions
            if action != nil || secondaryAction != nil {
                VStack(spacing: 12) {
                    if let action = action, let actionTitle = actionTitle {
                        Button(action: action) {
                            HStack {
                                if type == .noAssets || type == .noAssetSelected {
                                    Image(systemName: "qrcode.viewfinder")
                                } else if type == .noServiceRequests {
                                    Image(systemName: "plus")
                                }
                                Text(actionTitle)
                            }
                            .frame(minWidth: 140)
                        }
                        .buttonStyle(.borderedProminent)
                    }

                    if let secondaryAction = secondaryAction, let secondaryTitle = secondaryActionTitle {
                        Button(action: secondaryAction) {
                            Text(secondaryTitle)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(.top, 8)
            }

            Spacer()
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Compact Empty State

/// A compact empty state for inline display in lists or cards.
public struct CompactEmptyStateView: View {

    let type: EmptyStateType
    let message: String?

    public init(type: EmptyStateType, message: String? = nil) {
        self.type = type
        self.message = message
    }

    public var body: some View {
        VStack(spacing: 12) {
            Image(systemName: type.icon)
                .font(.system(size: 28))
                .foregroundColor(type.iconColor.opacity(0.7))

            Text(message ?? type.defaultTitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Loading State View

/// A loading state view with optional message.
public struct LoadingStateView: View {

    let message: String

    public init(message: String = "Loading...") {
        self.message = message
    }

    public var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)

            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Placeholder Shimmer View

/// A shimmer placeholder view for loading states.
public struct ShimmerView: View {

    @State private var isAnimating = false

    let width: CGFloat?
    let height: CGFloat

    public init(width: CGFloat? = nil, height: CGFloat = 20) {
        self.width = width
        self.height = height
    }

    public var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(Color(.systemGray5))
            .frame(width: width, height: height)
            .overlay(
                GeometryReader { geometry in
                    let width = geometry.size.width
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.clear,
                                    Color.white.opacity(0.5),
                                    Color.clear
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: width * 0.5)
                        .offset(x: isAnimating ? width : -width * 0.5)
                        .animation(
                            Animation.linear(duration: 1.5)
                                .repeatForever(autoreverses: false),
                            value: isAnimating
                        )
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .onAppear {
                isAnimating = true
            }
    }
}

// MARK: - Preview

#if DEBUG
struct EmptyStateView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            EmptyStateView(
                type: .noAssetSelected,
                actionTitle: "Scan QR Code",
                action: {},
                secondaryActionTitle: "Search Manually",
                secondaryAction: {}
            )
            .previewDisplayName("No Asset Selected")

            EmptyStateView(
                type: .noServiceRequests,
                actionTitle: "Create Request",
                action: {}
            )
            .previewDisplayName("No Service Requests")

            EmptyStateView(type: .noSearchResults)
                .previewDisplayName("No Search Results")

            VStack {
                CompactEmptyStateView(type: .noDocuments)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                    .padding()

                LoadingStateView(message: "Loading asset data...")
            }
            .previewDisplayName("Compact & Loading")

            VStack(alignment: .leading, spacing: 12) {
                ShimmerView(height: 16)
                ShimmerView(width: 200, height: 16)
                ShimmerView(width: 150, height: 16)
            }
            .padding()
            .previewDisplayName("Shimmer")
        }
    }
}
#endif

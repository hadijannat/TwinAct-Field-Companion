//
//  OnboardingView.swift
//  TwinAct Field Companion
//
//  First launch onboarding flow introducing app features.
//

import SwiftUI

// MARK: - Onboarding Page Model

/// Represents a single page in the onboarding flow.
struct OnboardingPage: Identifiable {
    let id = UUID()
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let description: String
}

// MARK: - Onboarding View

/// First launch onboarding flow introducing the app's key features.
public struct OnboardingView: View {

    // MARK: - Properties

    @Binding var hasCompletedOnboarding: Bool
    @State private var currentPage = 0
    @State private var showDemoModePrompt = false

    /// Onboarding pages content
    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "qrcode.viewfinder",
            iconColor: .blue,
            title: "Discover Assets",
            subtitle: "Scan QR codes to identify industrial equipment",
            description: "Point your camera at an asset's QR code to instantly access its Digital Product Passport with detailed information about the equipment."
        ),
        OnboardingPage(
            icon: "tag.fill",
            iconColor: .green,
            title: "Digital Passport",
            subtitle: "Access complete asset information",
            description: "View digital nameplates, technical specifications, documentation, carbon footprint data, and maintenance history all in one place."
        ),
        OnboardingPage(
            icon: "wrench.and.screwdriver.fill",
            iconColor: .orange,
            title: "Technician Tools",
            subtitle: "Manage service requests and maintenance",
            description: "Create and track service requests, follow maintenance procedures, and access time series sensor data to keep equipment running smoothly."
        ),
        OnboardingPage(
            icon: "arkit",
            iconColor: .purple,
            title: "AR Overlays",
            subtitle: "Visualize data in augmented reality",
            description: "Use AR mode to overlay real-time sensor data, maintenance procedures, and safety warnings directly on equipment."
        ),
        OnboardingPage(
            icon: "waveform",
            iconColor: .cyan,
            title: "Voice & AI Assistant",
            subtitle: "Hands-free operation with AI support",
            description: "Use voice commands for hands-free operation and ask the AI assistant questions about equipment and maintenance procedures."
        )
    ]

    // MARK: - Body

    public var body: some View {
        VStack(spacing: 0) {
            // Page content
            TabView(selection: $currentPage) {
                ForEach(Array(pages.enumerated()), id: \.element.id) { index, page in
                    OnboardingPageView(page: page)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut, value: currentPage)

            // Bottom section
            VStack(spacing: 20) {
                // Page indicators
                HStack(spacing: 8) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        Circle()
                            .fill(index == currentPage ? Color.accentColor : Color.secondary.opacity(0.3))
                            .frame(width: 8, height: 8)
                            .scaleEffect(index == currentPage ? 1.2 : 1.0)
                            .animation(.spring(response: 0.3), value: currentPage)
                    }
                }

                // Navigation buttons
                HStack(spacing: 16) {
                    if currentPage > 0 {
                        Button("Back") {
                            withAnimation {
                                currentPage -= 1
                            }
                        }
                        .buttonStyle(.bordered)
                    }

                    Spacer()

                    if currentPage < pages.count - 1 {
                        Button("Next") {
                            withAnimation {
                                currentPage += 1
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    } else {
                        Button("Get Started") {
                            showDemoModePrompt = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical, 24)
            .background(Color(.systemBackground))
        }
        .background(Color(.systemGroupedBackground))
        .alert("Demo Mode", isPresented: $showDemoModePrompt) {
            Button("Enable Demo Mode") {
                AppConfiguration.isDemoMode = true
                completeOnboarding()
            }
            Button("Connect to Server") {
                AppConfiguration.isDemoMode = false
                completeOnboarding()
            }
        } message: {
            Text("Would you like to explore the app with sample data, or connect to a real AAS server?\n\nYou can change this later in Settings.")
        }
    }

    // MARK: - Actions

    private func completeOnboarding() {
        withAnimation {
            hasCompletedOnboarding = true
        }
    }
}

// MARK: - Onboarding Page View

/// Individual page view for the onboarding flow.
struct OnboardingPageView: View {

    let page: OnboardingPage

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(page.iconColor.opacity(0.15))
                    .frame(width: 140, height: 140)

                Image(systemName: page.icon)
                    .font(.system(size: 60))
                    .foregroundColor(page.iconColor)
            }

            // Text content
            VStack(spacing: 12) {
                Text(page.title)
                    .font(.title)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                Text(page.subtitle)
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                Text(page.description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.top, 8)
            }

            Spacer()
            Spacer()
        }
        .padding()
    }
}

// MARK: - Onboarding Container

/// Container view that shows onboarding on first launch or main content if completed.
public struct OnboardingContainerView<Content: View>: View {

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    private let content: () -> Content

    public init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    public var body: some View {
        if hasCompletedOnboarding {
            content()
        } else {
            OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
        }
    }
}

// MARK: - Preview

#if DEBUG
struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView(hasCompletedOnboarding: .constant(false))
            .previewDisplayName("Onboarding Flow")

        OnboardingPageView(page: OnboardingPage(
            icon: "qrcode.viewfinder",
            iconColor: .blue,
            title: "Discover Assets",
            subtitle: "Scan QR codes to identify industrial equipment",
            description: "Point your camera at an asset's QR code to instantly access its Digital Product Passport."
        ))
        .previewDisplayName("Single Page")
    }
}
#endif

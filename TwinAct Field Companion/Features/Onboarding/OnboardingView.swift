//
//  OnboardingView.swift
//  TwinAct Field Companion
//
//  First launch onboarding flow introducing app features.
//

import SwiftUI

// MARK: - Onboarding Phase

/// Represents the current phase of the onboarding flow.
enum OnboardingPhase: Int, CaseIterable {
    case welcome = 0
    case features = 1
    case permissions = 2
    case completion = 3
}

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
    @State private var currentPhase: OnboardingPhase = .welcome
    @State private var featurePage = 0
    @State private var showDemoModePrompt = false

    /// Feature tour pages content
    private let featurePages: [OnboardingPage] = [
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
            icon: "book.closed.fill",
            iconColor: .indigo,
            title: "Jargon Buster",
            subtitle: "Understand DPP terminology",
            description: "Tap highlighted terms throughout the app to get instant explanations of technical Digital Product Passport terminology."
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
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            switch currentPhase {
            case .welcome:
                WelcomeView {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        currentPhase = .features
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal: .move(edge: .leading)
                ))

            case .features:
                featureTourView
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .leading)
                    ))

            case .permissions:
                PermissionsView {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        currentPhase = .completion
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal: .move(edge: .leading)
                ))

            case .completion:
                completionView
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .leading)
                    ))
            }
        }
        .alert("Choose Your Mode", isPresented: $showDemoModePrompt) {
            Button("Demo Mode") {
                AppConfiguration.isDemoMode = true
                completeOnboarding()
            }
            Button("Connect to Server") {
                AppConfiguration.isDemoMode = false
                completeOnboarding()
            }
        } message: {
            Text("Would you like to explore with sample data, or connect to a real AAS server?\n\nYou can change this later in Settings.")
        }
    }

    // MARK: - Feature Tour View

    private var featureTourView: some View {
        VStack(spacing: 0) {
            // Skip button
            HStack {
                Spacer()
                Button("Skip") {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        currentPhase = .permissions
                    }
                }
                .foregroundColor(.secondary)
                .padding()
            }

            // Page content
            TabView(selection: $featurePage) {
                ForEach(Array(featurePages.enumerated()), id: \.element.id) { index, page in
                    OnboardingPageView(page: page)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut, value: featurePage)

            // Bottom section
            VStack(spacing: 20) {
                // Page indicators
                HStack(spacing: 8) {
                    ForEach(0..<featurePages.count, id: \.self) { index in
                        Circle()
                            .fill(index == featurePage ? Color.accentColor : Color.secondary.opacity(0.3))
                            .frame(width: 8, height: 8)
                            .scaleEffect(index == featurePage ? 1.2 : 1.0)
                            .animation(.spring(response: 0.3), value: featurePage)
                    }
                }

                // Navigation buttons
                HStack(spacing: 16) {
                    if featurePage > 0 {
                        Button("Back") {
                            withAnimation {
                                featurePage -= 1
                            }
                        }
                        .buttonStyle(.bordered)
                    }

                    Spacer()

                    if featurePage < featurePages.count - 1 {
                        Button("Next") {
                            withAnimation {
                                featurePage += 1
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    } else {
                        Button("Continue") {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                currentPhase = .permissions
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical, 24)
            .background(Color(.systemBackground))
        }
    }

    // MARK: - Completion View

    private var completionView: some View {
        VStack(spacing: 0) {
            Spacer()

            // Success icon
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.15))
                    .frame(width: 120, height: 120)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.green)
            }

            Spacer()
                .frame(height: 32)

            // Text
            VStack(spacing: 12) {
                Text("You're All Set!")
                    .font(.title)
                    .fontWeight(.bold)

                Text("TwinAct Field Companion is ready to help you work with Digital Product Passports.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()

            // Get Started button
            Button {
                showDemoModePrompt = true
            } label: {
                Text("Get Started")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .background(Color(.systemGroupedBackground))
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

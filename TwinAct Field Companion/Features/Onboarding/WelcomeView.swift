//
//  WelcomeView.swift
//  TwinAct Field Companion
//
//  Welcome screen shown as first page of onboarding.
//

import SwiftUI

// MARK: - Welcome View

/// Welcome screen with app value proposition and branding.
struct WelcomeView: View {

    // MARK: - Properties

    let onContinue: () -> Void

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // App icon and branding
            VStack(spacing: 24) {
                // App icon
                Image(systemName: "cube.transparent.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .cyan],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: .blue.opacity(0.3), radius: 20, y: 10)

                VStack(spacing: 8) {
                    Text("TwinAct")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("Field Companion")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
                .frame(height: 48)

            // Value proposition
            VStack(spacing: 20) {
                Text("Your Digital Twin Assistant")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)

                Text("Access Digital Product Passports, maintenance data, and AI-powered assistance for industrial equipment — all from your mobile device.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()

            // Feature highlights
            VStack(spacing: 16) {
                FeatureHighlightRow(
                    icon: "qrcode.viewfinder",
                    color: .blue,
                    text: "Scan assets with QR codes"
                )
                FeatureHighlightRow(
                    icon: "doc.text.fill",
                    color: .green,
                    text: "View Digital Product Passports"
                )
                FeatureHighlightRow(
                    icon: "waveform",
                    color: .purple,
                    text: "Voice commands & AI chat"
                )
            }
            .padding(.horizontal, 40)

            Spacer()

            // Continue button
            Button(action: onContinue) {
                Text("Let's Get Started")
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
}

// MARK: - Feature Highlight Row

/// Compact feature highlight with icon and text.
private struct FeatureHighlightRow: View {

    let icon: String
    let color: Color
    let text: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 32)

            Text(text)
                .font(.subheadline)
                .foregroundColor(.primary)

            Spacer()
        }
    }
}

// MARK: - Preview

#if DEBUG
struct WelcomeView_Previews: PreviewProvider {
    static var previews: some View {
        WelcomeView(onContinue: {})
            .previewDisplayName("Welcome")
    }
}
#endif

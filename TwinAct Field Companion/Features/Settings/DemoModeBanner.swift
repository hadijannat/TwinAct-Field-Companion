//
//  DemoModeBanner.swift
//  TwinAct Field Companion
//
//  Banner view displayed when the app is running in demo mode.
//  Provides visual indication and quick toggle for demo mode.
//

import SwiftUI

// MARK: - Demo Mode Banner

/// Banner shown at the top of screens when demo mode is active.
/// Provides visual indication and option to disable demo mode.
public struct DemoModeBanner: View {

    // MARK: - State

    @State private var isDemoMode = AppConfiguration.isDemoMode
    @State private var showingDisableAlert = false

    // MARK: - Body

    public var body: some View {
        if isDemoMode {
            bannerContent
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.easeInOut(duration: 0.3), value: isDemoMode)
                .onReceive(NotificationCenter.default.publisher(for: .demoModeDidChange)) { _ in
                    withAnimation {
                        isDemoMode = AppConfiguration.isDemoMode
                    }
                }
                .alert("Disable Demo Mode?", isPresented: $showingDisableAlert) {
                    Button("Cancel", role: .cancel) {}
                    Button("Disable", role: .destructive) {
                        withAnimation {
                            AppConfiguration.disableDemoMode()
                        }
                    }
                } message: {
                    Text("Disabling demo mode requires a connection to a real AAS server. The app will attempt to connect to the configured server endpoints.")
                }
        }
    }

    // MARK: - Banner Content

    private var bannerContent: some View {
        HStack(spacing: 8) {
            Image(systemName: "play.rectangle.fill")
                .font(.system(size: 14, weight: .semibold))

            Text("Demo Mode")
                .font(.caption.bold())

            Spacer()

            Text("Using sample data")
                .font(.caption2)
                .foregroundColor(.orange.opacity(0.8))

            Button {
                showingDisableAlert = true
            } label: {
                Text("Disable")
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.3))
                    .cornerRadius(4)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            LinearGradient(
                colors: [Color.orange.opacity(0.15), Color.orange.opacity(0.1)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .foregroundColor(.orange)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(.orange.opacity(0.3)),
            alignment: .bottom
        )
    }

    // MARK: - Initialization

    public init() {}
}

// MARK: - Compact Demo Mode Indicator

/// A compact pill indicator for demo mode, suitable for toolbars or navigation bars.
public struct DemoModeIndicator: View {

    @State private var isDemoMode = AppConfiguration.isDemoMode

    public var body: some View {
        if isDemoMode {
            HStack(spacing: 4) {
                Image(systemName: "play.fill")
                    .font(.system(size: 8))
                Text("DEMO")
                    .font(.system(size: 9, weight: .bold))
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color.orange)
            .foregroundColor(.white)
            .cornerRadius(4)
            .onReceive(NotificationCenter.default.publisher(for: .demoModeDidChange)) { _ in
                isDemoMode = AppConfiguration.isDemoMode
            }
        }
    }

    public init() {}
}

// MARK: - Demo Mode Toggle Row

/// A toggle row for use in settings screens.
public struct DemoModeToggleRow: View {

    @State private var isDemoMode = AppConfiguration.isDemoMode
    @State private var showingAlert = false

    public var body: some View {
        Toggle(isOn: Binding(
            get: { isDemoMode },
            set: { newValue in
                if !newValue {
                    showingAlert = true
                } else {
                    isDemoMode = newValue
                    AppConfiguration.isDemoMode = newValue
                }
            }
        )) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Demo Mode")
                    .font(.body)
                Text("Use bundled sample data without server connection")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .demoModeDidChange)) { _ in
            isDemoMode = AppConfiguration.isDemoMode
        }
        .alert("Disable Demo Mode?", isPresented: $showingAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Disable", role: .destructive) {
                isDemoMode = false
                AppConfiguration.isDemoMode = false
            }
        } message: {
            Text("Disabling demo mode requires a connection to a real AAS server. Make sure your server endpoints are configured correctly.")
        }
    }

    public init() {}
}

// MARK: - Preview

#if DEBUG
struct DemoModeBanner_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 0) {
            DemoModeBanner()
            Spacer()
        }
        .previewDisplayName("Demo Mode Banner")

        HStack {
            DemoModeIndicator()
            Spacer()
        }
        .padding()
        .previewDisplayName("Demo Mode Indicator")

        Form {
            Section("Demo Settings") {
                DemoModeToggleRow()
            }
        }
        .previewDisplayName("Demo Mode Toggle")
    }
}
#endif

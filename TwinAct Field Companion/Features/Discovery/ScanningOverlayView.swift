//
//  ScanningOverlayView.swift
//  TwinAct Field Companion
//
//  Visual overlay for QR code scanning with viewfinder frame,
//  scanning animation, and status indicators.
//

import SwiftUI

// MARK: - Scanning Overlay View

/// Animated overlay displayed on top of camera preview during QR scanning.
public struct ScanningOverlayView: View {

    /// Whether the scanner is actively scanning
    let isScanning: Bool

    /// Detected QR code content (if any)
    let detectedCode: String?

    /// Parsed identification link (if code was parsed successfully)
    let parsedLink: AssetIdentificationLink?

    /// Whether a detection was successful
    var isDetected: Bool {
        detectedCode != nil
    }

    /// State for scanning line animation
    @State private var scanLineOffset: CGFloat = 0
    @State private var pulseScale: CGFloat = 1.0

    // MARK: - Configuration

    /// Size of the viewfinder cutout
    private let viewfinderSize: CGFloat = 280

    /// Corner radius of the viewfinder
    private let cornerRadius: CGFloat = 20

    /// Color for the viewfinder frame
    private let frameColor = Color.white

    /// Color for successful detection
    private let successColor = Color.green

    /// Color for the scanning line
    private let scanLineColor = Color.blue

    // MARK: - Initialization

    public init(
        isScanning: Bool,
        detectedCode: String? = nil,
        parsedLink: AssetIdentificationLink? = nil
    ) {
        self.isScanning = isScanning
        self.detectedCode = detectedCode
        self.parsedLink = parsedLink
    }

    // MARK: - Body

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Dimmed background with cutout
                dimmingLayer(in: geometry)

                // Viewfinder frame
                viewfinderFrame

                // Scanning line animation (when scanning)
                if isScanning && !isDetected {
                    scanningLine
                }

                // Success indicator (when detected)
                if isDetected {
                    successIndicator
                }

                // Instructions text
                instructionsOverlay(in: geometry)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: isDetected)
        .onAppear {
            startAnimations()
        }
        .onChange(of: isDetected) { _, detected in
            if detected {
                stopAnimations()
            } else {
                startAnimations()
            }
        }
    }

    // MARK: - Dimming Layer

    @ViewBuilder
    private func dimmingLayer(in geometry: GeometryProxy) -> some View {
        let rect = viewfinderRect(in: geometry)

        Color.black.opacity(0.6)
            .mask(
                Rectangle()
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .frame(width: rect.width, height: rect.height)
                            .position(x: rect.midX, y: rect.midY)
                            .blendMode(.destinationOut)
                    )
                    .compositingGroup()
            )
            .ignoresSafeArea()
    }

    // MARK: - Viewfinder Frame

    private var viewfinderFrame: some View {
        ZStack {
            // Main rounded rectangle outline
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(
                    isDetected ? successColor : frameColor,
                    lineWidth: isDetected ? 4 : 3
                )
                .frame(width: viewfinderSize, height: viewfinderSize)
                .scaleEffect(isDetected ? pulseScale : 1.0)

            // Corner accents
            ViewfinderCorners(
                size: viewfinderSize,
                cornerRadius: cornerRadius,
                color: isDetected ? successColor : frameColor,
                lineWidth: isDetected ? 5 : 4
            )
            .scaleEffect(isDetected ? pulseScale : 1.0)
        }
    }

    // MARK: - Scanning Line

    private var scanningLine: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        scanLineColor.opacity(0),
                        scanLineColor.opacity(0.8),
                        scanLineColor.opacity(0)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: viewfinderSize - 40, height: 3)
            .offset(y: scanLineOffset)
            .mask(
                RoundedRectangle(cornerRadius: cornerRadius - 5)
                    .frame(width: viewfinderSize - 20, height: viewfinderSize - 20)
            )
    }

    // MARK: - Success Indicator

    private var successIndicator: some View {
        VStack(spacing: 16) {
            // Checkmark icon
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(successColor)
                .scaleEffect(pulseScale)

            // Parsed info (if available)
            if let link = parsedLink {
                VStack(spacing: 4) {
                    Text(link.displaySummary)
                        .font(.headline)
                        .foregroundColor(.white)

                    Text(link.linkType.displayName)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color.black.opacity(0.6))
                .cornerRadius(10)
            }
        }
    }

    // MARK: - Instructions Overlay

    @ViewBuilder
    private func instructionsOverlay(in geometry: GeometryProxy) -> some View {
        let rect = viewfinderRect(in: geometry)

        VStack {
            Spacer()
                .frame(height: rect.maxY + 30)

            // Status text
            if isDetected {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(successColor)
                    Text("QR Code Detected")
                        .font(.headline)
                }
                .foregroundColor(.white)
            } else if isScanning {
                HStack(spacing: 8) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                    Text("Align QR code within frame")
                        .font(.subheadline)
                }
                .foregroundColor(.white.opacity(0.9))
            } else {
                Text("Scanner paused")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
            }

            // Supported formats hint
            if !isDetected {
                Text("Supports IEC 61406, GS1 Digital Link, and manufacturer QR codes")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)
                    .padding(.horizontal, 40)
            }

            Spacer()
        }
    }

    // MARK: - Helpers

    private func viewfinderRect(in geometry: GeometryProxy) -> CGRect {
        let x = (geometry.size.width - viewfinderSize) / 2
        let y = (geometry.size.height - viewfinderSize) / 2 - 40 // Slightly above center
        return CGRect(x: x, y: y, width: viewfinderSize, height: viewfinderSize)
    }

    // MARK: - Animations

    private func startAnimations() {
        // Scanning line animation
        withAnimation(
            .easeInOut(duration: 2.0)
            .repeatForever(autoreverses: true)
        ) {
            scanLineOffset = (viewfinderSize / 2) - 30
        }
    }

    private func stopAnimations() {
        // Pulse animation for success
        withAnimation(
            .easeInOut(duration: 0.3)
            .repeatCount(2, autoreverses: true)
        ) {
            pulseScale = 1.05
        }

        // Reset pulse
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.easeOut(duration: 0.2)) {
                pulseScale = 1.0
            }
        }
    }
}

// MARK: - Viewfinder Corners

/// Custom shape for drawing corner accents on the viewfinder.
struct ViewfinderCorners: View {
    let size: CGFloat
    let cornerRadius: CGFloat
    let color: Color
    let lineWidth: CGFloat

    /// Length of each corner line
    private let cornerLength: CGFloat = 30

    var body: some View {
        Canvas { context, canvasSize in
            let rect = CGRect(
                x: (canvasSize.width - size) / 2,
                y: (canvasSize.height - size) / 2,
                width: size,
                height: size
            )

            // Draw corner accents
            drawCorner(context: context, rect: rect, corner: .topLeft)
            drawCorner(context: context, rect: rect, corner: .topRight)
            drawCorner(context: context, rect: rect, corner: .bottomLeft)
            drawCorner(context: context, rect: rect, corner: .bottomRight)
        }
    }

    private enum Corner {
        case topLeft, topRight, bottomLeft, bottomRight
    }

    private func drawCorner(context: GraphicsContext, rect: CGRect, corner: Corner) {
        var path = Path()

        switch corner {
        case .topLeft:
            path.move(to: CGPoint(x: rect.minX, y: rect.minY + cornerRadius + cornerLength))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + cornerRadius))
            path.addArc(
                center: CGPoint(x: rect.minX + cornerRadius, y: rect.minY + cornerRadius),
                radius: cornerRadius,
                startAngle: .degrees(180),
                endAngle: .degrees(270),
                clockwise: false
            )
            path.addLine(to: CGPoint(x: rect.minX + cornerRadius + cornerLength, y: rect.minY))

        case .topRight:
            path.move(to: CGPoint(x: rect.maxX - cornerRadius - cornerLength, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX - cornerRadius, y: rect.minY))
            path.addArc(
                center: CGPoint(x: rect.maxX - cornerRadius, y: rect.minY + cornerRadius),
                radius: cornerRadius,
                startAngle: .degrees(270),
                endAngle: .degrees(0),
                clockwise: false
            )
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + cornerRadius + cornerLength))

        case .bottomLeft:
            path.move(to: CGPoint(x: rect.minX, y: rect.maxY - cornerRadius - cornerLength))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - cornerRadius))
            path.addArc(
                center: CGPoint(x: rect.minX + cornerRadius, y: rect.maxY - cornerRadius),
                radius: cornerRadius,
                startAngle: .degrees(180),
                endAngle: .degrees(90),
                clockwise: true
            )
            path.addLine(to: CGPoint(x: rect.minX + cornerRadius + cornerLength, y: rect.maxY))

        case .bottomRight:
            path.move(to: CGPoint(x: rect.maxX - cornerRadius - cornerLength, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.maxX - cornerRadius, y: rect.maxY))
            path.addArc(
                center: CGPoint(x: rect.maxX - cornerRadius, y: rect.maxY - cornerRadius),
                radius: cornerRadius,
                startAngle: .degrees(90),
                endAngle: .degrees(0),
                clockwise: true
            )
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - cornerRadius - cornerLength))
        }

        context.stroke(
            path,
            with: .color(color),
            style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
        )
    }
}

// MARK: - Scanning Status Badge

/// Small badge showing scanning status.
public struct ScanningStatusBadge: View {
    let isScanning: Bool
    let isDetected: Bool

    public init(isScanning: Bool, isDetected: Bool = false) {
        self.isScanning = isScanning
        self.isDetected = isDetected
    }

    public var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)

            Text(statusText)
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.6))
        .cornerRadius(16)
        .foregroundColor(.white)
    }

    private var statusColor: Color {
        if isDetected { return .green }
        if isScanning { return .blue }
        return .gray
    }

    private var statusText: String {
        if isDetected { return "Detected" }
        if isScanning { return "Scanning" }
        return "Paused"
    }
}

// MARK: - Preview Provider

#if DEBUG
struct ScanningOverlayView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Scanning state
            ZStack {
                Color.black
                ScanningOverlayView(
                    isScanning: true,
                    detectedCode: nil
                )
            }
            .ignoresSafeArea()
            .previewDisplayName("Scanning")

            // Detected state
            ZStack {
                Color.black
                ScanningOverlayView(
                    isScanning: false,
                    detectedCode: "https://id.siemens.com/product/1234567",
                    parsedLink: AssetIdentificationLink(
                        originalURL: URL(string: "https://id.siemens.com/product/1234567"),
                        originalString: "https://id.siemens.com/product/1234567",
                        linkType: .manufacturerLink,
                        manufacturer: "Siemens",
                        serialNumber: "1234567"
                    )
                )
            }
            .ignoresSafeArea()
            .previewDisplayName("Detected")

            // Paused state
            ZStack {
                Color.black
                ScanningOverlayView(
                    isScanning: false,
                    detectedCode: nil
                )
            }
            .ignoresSafeArea()
            .previewDisplayName("Paused")
        }
    }
}
#endif

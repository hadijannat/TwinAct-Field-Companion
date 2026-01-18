//
//  CameraPreviewView.swift
//  TwinAct Field Companion
//
//  UIViewRepresentable wrapper for AVCaptureSession video preview.
//  Displays live camera feed for QR code scanning.
//

import SwiftUI
import AVFoundation

// MARK: - Camera Preview View

/// SwiftUI wrapper for AVCaptureVideoPreviewLayer.
/// Displays live camera feed from the provided capture session.
public struct CameraPreviewView: UIViewRepresentable {

    /// The capture session providing video frames
    let session: AVCaptureSession

    /// Video gravity for preview layer
    var videoGravity: AVLayerVideoGravity = .resizeAspectFill

    // MARK: - UIViewRepresentable

    public func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = videoGravity
        view.backgroundColor = .black
        return view
    }

    public func updateUIView(_ uiView: PreviewView, context: Context) {
        // Update session if changed
        if uiView.videoPreviewLayer.session !== session {
            uiView.videoPreviewLayer.session = session
        }

        // Update video gravity if changed
        if uiView.videoPreviewLayer.videoGravity != videoGravity {
            uiView.videoPreviewLayer.videoGravity = videoGravity
        }
    }

    /// Convert a point from view coordinates to camera coordinates.
    public static func convertToDevicePoint(
        point: CGPoint,
        in view: PreviewView
    ) -> CGPoint {
        view.videoPreviewLayer.captureDevicePointConverted(fromLayerPoint: point)
    }

    /// Convert a rect from view coordinates to camera coordinates.
    public static func convertToDeviceRect(
        rect: CGRect,
        in view: PreviewView
    ) -> CGRect {
        view.videoPreviewLayer.metadataOutputRectConverted(fromLayerRect: rect)
    }
}

// MARK: - Preview UIView

/// UIView subclass that hosts AVCaptureVideoPreviewLayer.
public class PreviewView: UIView {

    // MARK: - Layer Class Override

    /// Override the layer class to use AVCaptureVideoPreviewLayer.
    override public class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    /// Typed accessor for the preview layer.
    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        guard let layer = layer as? AVCaptureVideoPreviewLayer else {
            fatalError("Expected AVCaptureVideoPreviewLayer but got \(type(of: layer))")
        }
        return layer
    }

    // MARK: - Initialization

    override public init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    private func setupView() {
        // Configure the video preview layer
        videoPreviewLayer.videoGravity = .resizeAspectFill

        // Handle device orientation changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(deviceOrientationDidChange),
            name: UIDevice.orientationDidChangeNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Orientation Handling

    @objc private func deviceOrientationDidChange() {
        updateVideoOrientation()
    }

    private func updateVideoOrientation() {
        guard let connection = videoPreviewLayer.connection,
              connection.isVideoRotationAngleSupported(0) else {
            return
        }

        let orientation = UIDevice.current.orientation
        let angle: CGFloat

        switch orientation {
        case .portrait:
            angle = 90
        case .portraitUpsideDown:
            angle = 270
        case .landscapeLeft:
            angle = 0
        case .landscapeRight:
            angle = 180
        default:
            angle = 90 // Default to portrait
        }

        if connection.isVideoRotationAngleSupported(angle) {
            connection.videoRotationAngle = angle
        }
    }

    // MARK: - Layout

    override public func layoutSubviews() {
        super.layoutSubviews()
        videoPreviewLayer.frame = bounds
        updateVideoOrientation()
    }

    // MARK: - Focus Animation

    /// Show focus animation at the specified point.
    public func showFocusAnimation(at point: CGPoint) {
        let focusView = FocusIndicatorView(frame: CGRect(x: 0, y: 0, width: 80, height: 80))
        focusView.center = point
        addSubview(focusView)
        focusView.animate {
            focusView.removeFromSuperview()
        }
    }

    /// Convert a point in this view to capture device coordinates (0-1 range).
    public func devicePoint(for point: CGPoint) -> CGPoint {
        videoPreviewLayer.captureDevicePointConverted(fromLayerPoint: point)
    }
}

// MARK: - Focus Indicator View

/// Animated focus indicator shown when user taps to focus.
private class FocusIndicatorView: UIView {

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    private func setupView() {
        backgroundColor = .clear
        layer.borderColor = UIColor.systemYellow.cgColor
        layer.borderWidth = 2
        alpha = 0
        transform = CGAffineTransform(scaleX: 1.5, y: 1.5)
    }

    func animate(completion: @escaping () -> Void) {
        // Animate in
        UIView.animate(
            withDuration: 0.15,
            delay: 0,
            options: .curveEaseOut
        ) {
            self.alpha = 1
            self.transform = .identity
        } completion: { _ in
            // Hold
            UIView.animate(
                withDuration: 0.15,
                delay: 0.5,
                options: .curveEaseIn
            ) {
                self.alpha = 0
                self.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
            } completion: { _ in
                completion()
            }
        }
    }
}

// MARK: - Camera Preview Modifiers

extension CameraPreviewView {
    /// Set the video gravity mode.
    public func videoGravity(_ gravity: AVLayerVideoGravity) -> CameraPreviewView {
        var copy = self
        copy.videoGravity = gravity
        return copy
    }
}

// MARK: - Preview Provider

#if DEBUG
struct CameraPreviewView_Previews: PreviewProvider {
    static var previews: some View {
        // Note: Camera preview won't work in SwiftUI preview
        ZStack {
            Color.black
            Text("Camera Preview\n(Requires device)")
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
        }
        .ignoresSafeArea()
    }
}
#endif

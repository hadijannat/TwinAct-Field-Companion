//
//  QRScannerViewModel.swift
//  TwinAct Field Companion
//
//  ViewModel for QR code scanner handling camera capture,
//  QR detection, and IEC 61406 link parsing.
//

import AVFoundation
import Combine
import os.log
import SwiftUI

// MARK: - Scanner Error

/// Errors that can occur during QR scanning.
public enum ScannerError: Error, LocalizedError {
    case cameraAccessDenied
    case cameraAccessRestricted
    case cameraUnavailable
    case captureSessionConfigurationFailed
    case torchUnavailable
    case invalidQRCode
    case parsingFailed(String)

    public var errorDescription: String? {
        switch self {
        case .cameraAccessDenied:
            return "Camera access was denied. Please enable camera access in Settings."
        case .cameraAccessRestricted:
            return "Camera access is restricted on this device."
        case .cameraUnavailable:
            return "Camera is not available on this device."
        case .captureSessionConfigurationFailed:
            return "Failed to configure camera for scanning."
        case .torchUnavailable:
            return "Torch is not available on this device."
        case .invalidQRCode:
            return "The scanned QR code is not a valid identification link."
        case .parsingFailed(let reason):
            return "Failed to parse QR code: \(reason)"
        }
    }
}

// MARK: - Scanner State

/// Current state of the QR scanner.
public enum ScannerState: Equatable {
    case idle
    case requestingPermission
    case configuring
    case scanning
    case processing
    case detected(String)
    case error(String)

    public var isActive: Bool {
        switch self {
        case .scanning, .processing: return true
        default: return false
        }
    }
}

// MARK: - QR Scanner ViewModel

/// ViewModel for QR code scanning with camera capture and IEC 61406 parsing.
@MainActor
public final class QRScannerViewModel: NSObject, ObservableObject {

    // MARK: - Published Properties

    /// Current scanner state
    @Published public var state: ScannerState = .idle

    /// Whether the scanner is actively scanning
    @Published public var isScanning: Bool = false

    /// Most recently detected QR code content
    @Published public var detectedCode: String?

    /// Parsed identification link from detected code
    @Published public var parsedAssetLink: AssetIdentificationLink?

    /// Current error (if any)
    @Published public var error: ScannerError?

    /// Whether torch is enabled
    @Published public var torchEnabled: Bool = false

    /// Whether torch is available
    @Published public var torchAvailable: Bool = false

    /// Camera authorization status
    @Published public var authorizationStatus: AVAuthorizationStatus = .notDetermined

    // MARK: - Capture Session

    /// The AVCaptureSession used for camera capture
    public let captureSession = AVCaptureSession()

    /// Metadata output for QR code detection
    private let metadataOutput = AVCaptureMetadataOutput()

    /// Video preview layer (lazily created)
    private var videoPreviewLayer: AVCaptureVideoPreviewLayer?

    // MARK: - Private Properties

    private let logger = Logger(
        subsystem: AppConfiguration.AppInfo.bundleIdentifier,
        category: "QRScannerViewModel"
    )

    /// Queue for capture session operations
    private let sessionQueue = DispatchQueue(label: "com.twinact.scanner.session")

    /// Queue for metadata processing
    private let metadataQueue = DispatchQueue(label: "com.twinact.scanner.metadata")

    /// The active video capture device
    private var videoCaptureDevice: AVCaptureDevice?

    /// Debounce timer for continuous scanning
    private var scanDebounceTimer: Timer?

    /// Time of last successful scan (for debouncing)
    private var lastScanTime: Date?

    /// Minimum interval between processing the same code
    private let scanDebounceInterval: TimeInterval = 2.0

    /// Last detected code (for debouncing duplicates)
    private var lastDetectedCode: String?

    /// Cancellables for Combine subscriptions
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Configuration

    /// Supported metadata object types
    private let supportedCodeTypes: [AVMetadataObject.ObjectType] = [
        .qr,
        .dataMatrix,
        .aztec,
        .pdf417
    ]

    // MARK: - Initialization

    public override init() {
        super.init()
        checkAuthorizationStatus()
    }

    deinit {
        stopScanning()
    }

    // MARK: - Public API

    /// Start the QR code scanner.
    public func startScanning() {
        logger.debug("Starting scanner")

        switch authorizationStatus {
        case .authorized:
            configureAndStartSession()

        case .notDetermined:
            requestCameraAccess()

        case .denied:
            state = .error(ScannerError.cameraAccessDenied.localizedDescription)
            error = .cameraAccessDenied

        case .restricted:
            state = .error(ScannerError.cameraAccessRestricted.localizedDescription)
            error = .cameraAccessRestricted

        @unknown default:
            state = .error("Unknown camera authorization status")
        }
    }

    /// Stop the QR code scanner.
    public func stopScanning() {
        logger.debug("Stopping scanner")

        sessionQueue.async { [weak self] in
            self?.captureSession.stopRunning()
        }

        isScanning = false
        state = .idle
        scanDebounceTimer?.invalidate()
        scanDebounceTimer = nil
    }

    /// Pause scanning temporarily (keeps session running).
    public func pauseScanning() {
        isScanning = false
    }

    /// Resume scanning after pause.
    public func resumeScanning() {
        guard captureSession.isRunning else {
            startScanning()
            return
        }
        isScanning = true
        state = .scanning
        detectedCode = nil
        parsedAssetLink = nil
    }

    /// Toggle the device torch.
    public func toggleTorch() {
        guard let device = videoCaptureDevice,
              device.hasTorch else {
            error = .torchUnavailable
            return
        }

        sessionQueue.async { [weak self] in
            do {
                try device.lockForConfiguration()
                let newMode: AVCaptureDevice.TorchMode = device.torchMode == .on ? .off : .on
                device.torchMode = newMode

                Task { @MainActor [weak self] in
                    self?.torchEnabled = newMode == .on
                }

                device.unlockForConfiguration()
                self?.logger.debug("Torch toggled: \(newMode == .on ? "on" : "off")")
            } catch {
                self?.logger.error("Failed to toggle torch: \(error.localizedDescription)")
            }
        }
    }

    /// Focus the camera on a specific point.
    public func focus(at point: CGPoint) {
        guard let device = videoCaptureDevice,
              device.isFocusPointOfInterestSupported else {
            return
        }

        sessionQueue.async { [weak self] in
            do {
                try device.lockForConfiguration()

                device.focusPointOfInterest = point
                device.focusMode = .autoFocus

                if device.isExposurePointOfInterestSupported {
                    device.exposurePointOfInterest = point
                    device.exposureMode = .autoExpose
                }

                device.unlockForConfiguration()
                self?.logger.debug("Focused at point: \(point)")
            } catch {
                self?.logger.error("Failed to focus: \(error.localizedDescription)")
            }
        }
    }

    /// Reset the scanner to initial state.
    public func reset() {
        detectedCode = nil
        parsedAssetLink = nil
        error = nil
        lastDetectedCode = nil
        lastScanTime = nil

        if captureSession.isRunning {
            isScanning = true
            state = .scanning
        }
    }

    // MARK: - Authorization

    private func checkAuthorizationStatus() {
        authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
        logger.debug("Camera authorization status: \(String(describing: self.authorizationStatus.rawValue))")
    }

    private func requestCameraAccess() {
        logger.debug("Requesting camera access")
        state = .requestingPermission

        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            Task { @MainActor [weak self] in
                guard let self = self else { return }

                self.authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)

                if granted {
                    self.logger.debug("Camera access granted")
                    self.configureAndStartSession()
                } else {
                    self.logger.warning("Camera access denied")
                    self.state = .error(ScannerError.cameraAccessDenied.localizedDescription)
                    self.error = .cameraAccessDenied
                }
            }
        }
    }

    // MARK: - Session Configuration

    private func configureAndStartSession() {
        state = .configuring
        logger.debug("Configuring capture session")

        sessionQueue.async { [weak self] in
            guard let self = self else { return }

            do {
                try self.configureCaptureSession()
                self.captureSession.startRunning()

                Task { @MainActor [weak self] in
                    self?.isScanning = true
                    self?.state = .scanning
                    self?.logger.debug("Capture session started")
                }
            } catch {
                Task { @MainActor [weak self] in
                    self?.logger.error("Failed to configure session: \(error.localizedDescription)")
                    self?.state = .error(error.localizedDescription)
                    if let scannerError = error as? ScannerError {
                        self?.error = scannerError
                    } else {
                        self?.error = .captureSessionConfigurationFailed
                    }
                }
            }
        }
    }

    private func configureCaptureSession() throws {
        captureSession.beginConfiguration()
        defer { captureSession.commitConfiguration() }

        // Remove existing inputs/outputs
        captureSession.inputs.forEach { captureSession.removeInput($0) }
        captureSession.outputs.forEach { captureSession.removeOutput($0) }

        // Set session preset
        if captureSession.canSetSessionPreset(.high) {
            captureSession.sessionPreset = .high
        }

        // Configure video input
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            throw ScannerError.cameraUnavailable
        }

        videoCaptureDevice = device

        // Check torch availability
        Task { @MainActor [weak self] in
            self?.torchAvailable = device.hasTorch
        }

        let videoInput = try AVCaptureDeviceInput(device: device)

        guard captureSession.canAddInput(videoInput) else {
            throw ScannerError.captureSessionConfigurationFailed
        }
        captureSession.addInput(videoInput)

        // Configure metadata output
        guard captureSession.canAddOutput(metadataOutput) else {
            throw ScannerError.captureSessionConfigurationFailed
        }
        captureSession.addOutput(metadataOutput)

        // Set delegate and supported types
        metadataOutput.setMetadataObjectsDelegate(self, queue: metadataQueue)

        // Filter to supported types that the output can handle
        let availableTypes = metadataOutput.availableMetadataObjectTypes
        let typesToUse = supportedCodeTypes.filter { availableTypes.contains($0) }
        metadataOutput.metadataObjectTypes = typesToUse

        logger.debug("Configured metadata output with types: \(typesToUse.map { $0.rawValue })")

        // Configure focus/exposure
        configureDeviceSettings(device)
    }

    private func configureDeviceSettings(_ device: AVCaptureDevice) {
        do {
            try device.lockForConfiguration()

            // Enable continuous autofocus
            if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
            }

            // Enable continuous auto exposure
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
            }

            device.unlockForConfiguration()
        } catch {
            logger.warning("Failed to configure device settings: \(error.localizedDescription)")
        }
    }

    // MARK: - QR Code Processing

    private func processDetectedCode(_ code: String) {
        guard isScanning else { return }

        // Debounce duplicate scans
        if code == lastDetectedCode,
           let lastTime = lastScanTime,
           Date().timeIntervalSince(lastTime) < scanDebounceInterval {
            return
        }

        lastDetectedCode = code
        lastScanTime = Date()

        logger.debug("Processing detected code: \(code.prefix(50))...")

        Task { @MainActor [weak self] in
            guard let self = self else { return }

            self.state = .processing
            self.detectedCode = code

            // Parse the code
            if let link = IdentificationLinkParser.parse(code) {
                self.parsedAssetLink = link
                self.state = .detected(code)
                self.isScanning = false

                self.logger.info("Parsed link: type=\(link.linkType.rawValue), confidence=\(link.confidence)")

                // Haptic feedback
                self.triggerSuccessFeedback()
            } else {
                // Still treat as detected but without parsed link
                self.state = .detected(code)
                self.isScanning = false

                self.logger.warning("Could not parse code as identification link")
                self.triggerSuccessFeedback()
            }
        }
    }

    // MARK: - Feedback

    private func triggerSuccessFeedback() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    private func triggerErrorFeedback() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
    }
}

// MARK: - AVCaptureMetadataOutputObjectsDelegate

extension QRScannerViewModel: AVCaptureMetadataOutputObjectsDelegate {
    nonisolated public func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        // Find the first readable code
        guard let metadataObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let stringValue = metadataObject.stringValue,
              !stringValue.isEmpty else {
            return
        }

        Task { @MainActor [weak self] in
            self?.processDetectedCode(stringValue)
        }
    }
}

// MARK: - Viewfinder Region

extension QRScannerViewModel {
    /// Set the region of interest for QR detection (normalized coordinates 0-1).
    public func setRegionOfInterest(_ rect: CGRect) {
        metadataOutput.rectOfInterest = rect
    }

    /// Reset region of interest to full frame.
    public func resetRegionOfInterest() {
        metadataOutput.rectOfInterest = CGRect(x: 0, y: 0, width: 1, height: 1)
    }
}

// MARK: - Preview Helpers

#if DEBUG
extension QRScannerViewModel {
    /// Create a preview instance with mock detected code.
    static func preview(withCode code: String? = nil) -> QRScannerViewModel {
        let viewModel = QRScannerViewModel()
        viewModel.state = code != nil ? .detected(code!) : .scanning
        viewModel.isScanning = code == nil
        viewModel.detectedCode = code
        if let code = code {
            viewModel.parsedAssetLink = IdentificationLinkParser.parse(code)
        }
        return viewModel
    }
}
#endif

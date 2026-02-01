//
//  SpeechRecognizer.swift
//  TwinAct Field Companion
//
//  Speech framework wrapper for voice command recognition.
//  Provides hands-free operation for field technicians.
//

import Speech
import AVFoundation
import Foundation
import Combine

// MARK: - Speech Error

/// Errors that can occur during speech recognition
public enum SpeechError: Error, LocalizedError {
    /// User has not authorized speech recognition
    case notAuthorized

    /// Speech recognizer is not available for the current locale
    case recognizerUnavailable

    /// Audio engine failed to start or encountered an error
    case audioEngineError(underlying: Error?)

    /// Speech recognition request failed
    case recognitionFailed(underlying: Error)

    /// Microphone permission not granted
    case microphoneNotAuthorized

    /// Recognition was interrupted
    case interrupted

    /// No speech was detected
    case noSpeechDetected

    public var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Speech recognition is not authorized. Please enable it in Settings."
        case .recognizerUnavailable:
            return "Speech recognition is not available for your language."
        case .audioEngineError(let underlying):
            if let error = underlying {
                return "Audio error: \(error.localizedDescription)"
            }
            return "Failed to start audio capture."
        case .recognitionFailed(let underlying):
            return "Recognition failed: \(underlying.localizedDescription)"
        case .microphoneNotAuthorized:
            return "Microphone access is not authorized. Please enable it in Settings."
        case .interrupted:
            return "Speech recognition was interrupted."
        case .noSpeechDetected:
            return "No speech was detected. Please try again."
        }
    }
}

// MARK: - Speech Recognizer

/// Wrapper for the Speech framework providing speech-to-text functionality.
///
/// Supports push-to-talk and continuous listening modes with real-time
/// transcription updates. All operations are @MainActor to ensure UI safety.
///
/// ## Usage
/// ```swift
/// let recognizer = SpeechRecognizer()
/// let authorized = await recognizer.requestAuthorization()
/// if authorized {
///     try recognizer.startListening()
/// }
/// ```
@MainActor
public final class SpeechRecognizer: ObservableObject, @unchecked Sendable {

    // MARK: - Published Properties

    /// Whether the recognizer is currently listening for speech
    @Published public private(set) var isListening = false

    /// Current transcript from speech recognition
    @Published public private(set) var transcript = ""

    /// Confidence score for the current transcript (0.0 - 1.0)
    @Published public private(set) var confidence: Float = 0

    /// Current error state, if any
    @Published public private(set) var error: SpeechError?

    /// Whether authorization has been granted
    @Published public private(set) var isAuthorized = false

    /// Audio level for visualization (0.0 - 1.0)
    @Published public private(set) var audioLevel: Float = 0

    // MARK: - Private Properties

    private var recognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private let locale: Locale

    /// Timer for detecting silence/end of speech
    private var silenceTimer: Timer?
    private let silenceTimeout: TimeInterval = 2.0

    /// Callback when speech recognition completes
    public var onRecognitionComplete: ((String, Float) -> Void)?

    // MARK: - Initialization

    /// Initialize with a specific locale for recognition
    /// - Parameter locale: The locale for speech recognition. Defaults to current locale.
    public init(locale: Locale = .current) {
        self.locale = locale
        self.recognizer = SFSpeechRecognizer(locale: locale)

        // Check initial authorization status
        updateAuthorizationStatus()
    }

    // MARK: - Authorization

    /// Request authorization for speech recognition and microphone access.
    /// - Returns: True if both speech recognition and microphone are authorized.
    public func requestAuthorization() async -> Bool {
        // Request speech recognition authorization
        let speechAuthorized = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }

        guard speechAuthorized else {
            error = .notAuthorized
            return false
        }

        // Request microphone authorization
        let micAuthorized: Bool
        if #available(iOS 17.0, *) {
            micAuthorized = await AVAudioApplication.requestRecordPermission()
        } else {
            micAuthorized = await withCheckedContinuation { continuation in
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        }

        guard micAuthorized else {
            error = .microphoneNotAuthorized
            return false
        }

        isAuthorized = true
        error = nil
        return true
    }

    /// Update the authorization status based on current permissions
    private func updateAuthorizationStatus() {
        let speechStatus = SFSpeechRecognizer.authorizationStatus()
        let micAuthorized: Bool

        if #available(iOS 17.0, *) {
            micAuthorized = AVAudioApplication.shared.recordPermission == .granted
        } else {
            micAuthorized = AVAudioSession.sharedInstance().recordPermission == .granted
        }

        isAuthorized = (speechStatus == .authorized && micAuthorized)
    }

    // MARK: - Recognition Control

    /// Start listening for speech input.
    /// - Throws: SpeechError if recognition cannot be started.
    public func startListening() throws {
        // Reset state
        error = nil
        transcript = ""
        confidence = 0

        // Check authorization
        guard isAuthorized else {
            throw SpeechError.notAuthorized
        }

        // Check recognizer availability
        guard let recognizer = recognizer, recognizer.isAvailable else {
            throw SpeechError.recognizerUnavailable
        }

        // Stop any existing recognition
        stopListening()

        do {
            try configureAudioSession()
            try startRecognition()
            isListening = true
        } catch {
            self.error = .audioEngineError(underlying: error)
            throw SpeechError.audioEngineError(underlying: error)
        }
    }

    /// Stop listening and finalize recognition.
    public func stopListening() {
        silenceTimer?.invalidate()
        silenceTimer = nil

        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)

        recognitionRequest?.endAudio()
        recognitionRequest = nil

        recognitionTask?.cancel()
        recognitionTask = nil

        isListening = false
        audioLevel = 0

        // Deactivate audio session
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)

        // Notify completion if we have a transcript
        if !transcript.isEmpty {
            onRecognitionComplete?(transcript, confidence)
        }
    }

    /// Cancel recognition without triggering completion callback.
    public func cancelListening() {
        let previousTranscript = transcript
        transcript = ""
        confidence = 0
        stopListening()

        // Don't trigger completion callback
        if !previousTranscript.isEmpty {
            // Restore transcript for reference but don't notify
            transcript = previousTranscript
        }
    }

    // MARK: - Private Methods

    /// Configure the audio session for recording
    private func configureAudioSession() throws {
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
    }

    /// Start the speech recognition process
    private func startRecognition() throws {
        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()

        guard let recognitionRequest = recognitionRequest else {
            throw SpeechError.audioEngineError(underlying: nil)
        }

        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.requiresOnDeviceRecognition = false

        // Configure for best results
        if #available(iOS 16.0, *) {
            recognitionRequest.addsPunctuation = true
        }

        // Start recognition task
        recognitionTask = recognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            Task { @MainActor in
                self?.handleRecognitionResult(result, error: error)
            }
        }

        // Configure audio tap
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)

            // Calculate audio level for visualization
            Task { @MainActor in
                self?.updateAudioLevel(from: buffer)
            }
        }

        // Prepare and start audio engine
        audioEngine.prepare()
        try audioEngine.start()

        // Start silence detection timer
        resetSilenceTimer()
    }

    /// Handle recognition results
    private func handleRecognitionResult(_ result: SFSpeechRecognitionResult?, error: Error?) {
        if let error = error {
            // Check if it's a cancellation (not a real error)
            let nsError = error as NSError
            if nsError.domain == "kAFAssistantErrorDomain" && nsError.code == 209 {
                // Recognition was cancelled - this is expected
                return
            }

            self.error = .recognitionFailed(underlying: error)
            stopListening()
            return
        }

        guard let result = result else { return }

        // Update transcript with best transcription
        transcript = result.bestTranscription.formattedString

        // Calculate confidence from transcription segments
        let segments = result.bestTranscription.segments
        if !segments.isEmpty {
            let totalConfidence = segments.reduce(Float(0)) { $0 + $1.confidence }
            confidence = totalConfidence / Float(segments.count)
        }

        // Reset silence timer on new speech
        resetSilenceTimer()

        // If recognition is final, stop listening
        if result.isFinal {
            stopListening()
        }
    }

    /// Update audio level for visualization
    private func updateAudioLevel(from buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameLength = Int(buffer.frameLength)

        var sum: Float = 0
        for i in 0..<frameLength {
            sum += abs(channelData[i])
        }

        let average = sum / Float(frameLength)
        // Normalize to 0-1 range with some scaling
        audioLevel = min(1.0, average * 10)
    }

    /// Reset the silence detection timer
    private func resetSilenceTimer() {
        silenceTimer?.invalidate()
        silenceTimer = Timer.scheduledTimer(withTimeInterval: silenceTimeout, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self = self, !self.transcript.isEmpty else { return }
                self.stopListening()
            }
        }
    }
}

// MARK: - Speech Recognizer Delegate

extension SpeechRecognizer {
    /// Check if speech recognition is supported on this device
    public static var isSupported: Bool {
        SFSpeechRecognizer.authorizationStatus() != .restricted
    }

    /// Get the current authorization status
    public static var authorizationStatus: SFSpeechRecognizerAuthorizationStatus {
        SFSpeechRecognizer.authorizationStatus()
    }
}

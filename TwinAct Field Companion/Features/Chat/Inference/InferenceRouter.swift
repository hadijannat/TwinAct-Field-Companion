//
//  InferenceRouter.swift
//  TwinAct Field Companion
//
//  Routes inference to best available provider (on-device or cloud).
//

import Foundation
import os.log

// MARK: - Routing Strategy

/// Strategy for routing inference requests
public enum InferenceRoutingStrategy: String, Sendable, CaseIterable {
    /// Prefer on-device, fall back to cloud if unavailable
    case preferOnDevice

    /// Prefer cloud, fall back to on-device if unavailable
    case preferCloud

    /// Always use on-device only (offline mode)
    case onDeviceOnly

    /// Always use cloud only
    case cloudOnly

    /// Automatically choose based on query complexity and network conditions
    case adaptive

    public var displayName: String {
        switch self {
        case .preferOnDevice:
            return "Privacy First (On-Device Preferred)"
        case .preferCloud:
            return "Quality First (Cloud Preferred)"
        case .onDeviceOnly:
            return "Offline Mode"
        case .cloudOnly:
            return "Cloud Only"
        case .adaptive:
            return "Adaptive"
        }
    }
}

// MARK: - Inference Router

/// Routes inference to best available provider
public final class InferenceRouter: @unchecked Sendable {

    // MARK: - Properties

    private let onDevice: OnDeviceInference
    private let cloud: CloudInference
    private let safetyAudit: SafetyAudit
    private let logger: Logger

    private var strategy: InferenceRoutingStrategy
    private var lastUsedProvider: InferenceProviderType?

    // MARK: - Initialization

    /// Initialize inference router
    /// - Parameters:
    ///   - onDevice: On-device inference provider
    ///   - cloud: Cloud inference provider
    ///   - strategy: Routing strategy (defaults to app configuration)
    public init(
        onDevice: OnDeviceInference = OnDeviceInference(),
        cloud: CloudInference = CloudInference(),
        strategy: InferenceRoutingStrategy? = nil
    ) {
        self.onDevice = onDevice
        self.cloud = cloud
        self.safetyAudit = SafetyAudit()
        self.logger = Logger(
            subsystem: AppConfiguration.AppInfo.bundleIdentifier,
            category: "InferenceRouter"
        )

        // Determine strategy from app configuration
        if let explicitStrategy = strategy {
            self.strategy = explicitStrategy
        } else if AppConfiguration.GenAI.useOnDeviceInference {
            self.strategy = .preferOnDevice
        } else {
            self.strategy = .preferCloud
        }
    }

    // MARK: - Public API

    /// Generate text using the best available provider
    /// - Parameters:
    ///   - prompt: Input prompt
    ///   - options: Generation options
    /// - Returns: Generation result
    public func generate(
        prompt: String,
        options: GenerationOptions = .default
    ) async throws -> GenerationResult {
        // Validate prompt safety
        let promptValidation = SafetyPolicy.validatePrompt(prompt)
        guard promptValidation.isValid else {
            await safetyAudit.log(event: .promptRejected, details: promptValidation.reason)
            throw InferenceError.safetyViolation(
                reason: promptValidation.reason ?? "Invalid prompt"
            )
        }

        // Route based on strategy
        let result: GenerationResult

        switch strategy {
        case .preferOnDevice:
            result = try await generatePreferOnDevice(prompt: prompt, options: options)

        case .preferCloud:
            result = try await generatePreferCloud(prompt: prompt, options: options)

        case .onDeviceOnly:
            result = try await generateOnDeviceOnly(prompt: prompt, options: options)

        case .cloudOnly:
            result = try await generateCloudOnly(prompt: prompt, options: options)

        case .adaptive:
            result = try await generateAdaptive(prompt: prompt, options: options)
        }

        lastUsedProvider = result.provider
        return result
    }

    /// Generate text (convenience method)
    public func generate(prompt: String) async throws -> String {
        let result = try await generate(prompt: prompt, options: .default)
        return result.text
    }

    /// Cancel any ongoing generation
    public func cancel() async {
        await onDevice.cancel()
        await cloud.cancel()
    }

    /// Update routing strategy
    public func setStrategy(_ newStrategy: InferenceRoutingStrategy) {
        strategy = newStrategy
        logger.info("Routing strategy changed to: \(newStrategy.rawValue)")
    }

    /// Get current strategy
    public func getStrategy() -> InferenceRoutingStrategy {
        strategy
    }

    // MARK: - Routing Implementations

    private func generatePreferOnDevice(
        prompt: String,
        options: GenerationOptions
    ) async throws -> GenerationResult {
        // Try on-device first
        if await onDevice.isAvailable {
            do {
                logger.info("Using on-device inference")
                return try await onDevice.generate(prompt: prompt, options: options)
            } catch {
                logger.warning("On-device inference failed: \(error.localizedDescription)")
                // Fall through to cloud
            }
        }

        // Fall back to cloud
        if await cloud.isAvailable {
            logger.info("Falling back to cloud inference")
            return try await cloud.generate(prompt: prompt, options: options)
        }

        throw InferenceError.noProviderAvailable
    }

    private func generatePreferCloud(
        prompt: String,
        options: GenerationOptions
    ) async throws -> GenerationResult {
        // Try cloud first
        if await cloud.isAvailable {
            do {
                logger.info("Using cloud inference")
                return try await cloud.generate(prompt: prompt, options: options)
            } catch let error as InferenceError where error.isRetryable {
                logger.warning("Cloud inference failed (retryable): \(error.localizedDescription)")
                // Fall through to on-device
            } catch {
                throw error  // Non-retryable errors propagate
            }
        }

        // Fall back to on-device
        if await onDevice.isAvailable {
            logger.info("Falling back to on-device inference")
            return try await onDevice.generate(prompt: prompt, options: options)
        }

        throw InferenceError.noProviderAvailable
    }

    private func generateOnDeviceOnly(
        prompt: String,
        options: GenerationOptions
    ) async throws -> GenerationResult {
        guard await onDevice.isAvailable else {
            throw InferenceError.modelNotLoaded
        }

        logger.info("Using on-device inference (offline mode)")
        return try await onDevice.generate(prompt: prompt, options: options)
    }

    private func generateCloudOnly(
        prompt: String,
        options: GenerationOptions
    ) async throws -> GenerationResult {
        guard await cloud.isAvailable else {
            throw InferenceError.endpointNotConfigured
        }

        logger.info("Using cloud inference (cloud-only mode)")
        return try await cloud.generate(prompt: prompt, options: options)
    }

    private func generateAdaptive(
        prompt: String,
        options: GenerationOptions
    ) async throws -> GenerationResult {
        // Adaptive routing based on:
        // 1. Prompt complexity (length, technical terms)
        // 2. Network availability
        // 3. Battery level (future enhancement)

        let complexity = estimatePromptComplexity(prompt)
        let onDeviceAvailable = await onDevice.isAvailable
        let cloudAvailable = await cloud.isAvailable

        logger.info("Adaptive routing - complexity: \(complexity), onDevice: \(onDeviceAvailable), cloud: \(cloudAvailable)")

        // For complex queries, prefer cloud if available
        if complexity == .high && cloudAvailable {
            do {
                return try await cloud.generate(prompt: prompt, options: options)
            } catch {
                if onDeviceAvailable {
                    return try await onDevice.generate(prompt: prompt, options: options)
                }
                throw error
            }
        }

        // For simple queries or when cloud unavailable, use on-device
        if onDeviceAvailable {
            do {
                return try await onDevice.generate(prompt: prompt, options: options)
            } catch {
                if cloudAvailable {
                    return try await cloud.generate(prompt: prompt, options: options)
                }
                throw error
            }
        }

        // Last resort: try cloud
        if cloudAvailable {
            return try await cloud.generate(prompt: prompt, options: options)
        }

        throw InferenceError.noProviderAvailable
    }

    // MARK: - Complexity Estimation

    private enum QueryComplexity: String, CustomStringConvertible {
        case low
        case medium
        case high

        var description: String {
            rawValue
        }
    }

    private func estimatePromptComplexity(_ prompt: String) -> QueryComplexity {
        let wordCount = prompt.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .count

        // Check for technical indicators
        let technicalTerms = [
            "troubleshoot", "diagnose", "calibrate", "configure",
            "procedure", "specification", "tolerance", "maintenance",
            "error code", "fault", "warning"
        ]
        let lowercased = prompt.lowercased()
        let technicalCount = technicalTerms.filter { lowercased.contains($0) }.count

        // Determine complexity
        if wordCount > 100 || technicalCount >= 3 {
            return .high
        } else if wordCount > 30 || technicalCount >= 1 {
            return .medium
        } else {
            return .low
        }
    }

    // MARK: - Status

    /// Get status of all providers
    public func getProviderStatus() async -> [InferenceProviderStatus] {
        async let onDeviceStatus = onDevice.getStatus()
        async let cloudStatus = cloud.getStatus()

        return await [onDeviceStatus, cloudStatus]
    }

    /// Get the last used provider type
    public func getLastUsedProvider() -> InferenceProviderType? {
        lastUsedProvider
    }

    /// Check if any provider is available
    public func hasAvailableProvider() async -> Bool {
        let onDeviceAvailable = await onDevice.isAvailable
        if onDeviceAvailable {
            return true
        }
        return await cloud.isAvailable
    }
}

// MARK: - Inference Router Factory

/// Factory for creating configured inference routers
public struct InferenceRouterFactory {

    /// Create router with default configuration
    public static func createDefault() -> InferenceRouter {
        InferenceRouter()
    }

    /// Create router for offline-only operation
    public static func createOfflineRouter() -> InferenceRouter {
        InferenceRouter(strategy: .onDeviceOnly)
    }

    /// Create router for cloud-only operation
    public static func createCloudRouter(apiKey: String? = nil) -> InferenceRouter {
        let cloud = CloudInference(apiKey: apiKey)
        return InferenceRouter(cloud: cloud, strategy: .cloudOnly)
    }

    /// Create router for privacy-first operation
    public static func createPrivacyFirst() -> InferenceRouter {
        InferenceRouter(strategy: .preferOnDevice)
    }
}

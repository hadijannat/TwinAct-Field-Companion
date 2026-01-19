//
//  MockDiscoveryService.swift
//  TwinAct Field Companion
//
//  Mock implementation of DiscoveryServiceProtocol for demo mode.
//  Returns demo asset data without requiring a real backend.
//

import Foundation
import os.log

/// Mock Discovery Service that returns demo data for offline/demo mode.
public final class MockDiscoveryService: DiscoveryServiceProtocol, @unchecked Sendable {

    // MARK: - Properties

    private let demoProvider = DemoDataProvider.shared
    private let logger = Logger(
        subsystem: AppConfiguration.AppInfo.bundleIdentifier,
        category: "MockDiscoveryService"
    )

    /// Simulated network delay range (in seconds)
    private let simulatedDelayRange: ClosedRange<Double> = 0.1...0.5

    // MARK: - Initialization

    public init() {
        logger.debug("MockDiscoveryService initialized for demo mode")
    }

    // MARK: - DiscoveryServiceProtocol

    public func lookupShells(assetIds: [SpecificAssetId]) async throws -> [String] {
        logger.debug("Mock lookup for \(assetIds.count) asset IDs")

        // Simulate network delay
        await simulateNetworkDelay()

        // Return demo AAS ID for any lookup that matches demo asset criteria
        let demoAASId = demoProvider.demoAASId
        let demoSerialNumber = demoProvider.demoSerialNumber

        // Check if any of the provided asset IDs match demo data
        for assetId in assetIds {
            if assetId.name == "serialNumber" && assetId.value == demoSerialNumber {
                logger.debug("Mock discovery: matched serial number, returning demo AAS")
                return [demoAASId]
            }
            if assetId.name == "globalAssetId" && assetId.value == demoProvider.demoGlobalAssetId {
                logger.debug("Mock discovery: matched global asset ID, returning demo AAS")
                return [demoAASId]
            }
        }

        // For demo purposes, return the demo AAS for any lookup
        // This makes it easy to test the app with any QR code
        logger.debug("Mock discovery: returning demo AAS for any lookup")
        return [demoAASId]
    }

    public func lookupShells(name: String, value: String) async throws -> [String] {
        let assetId = SpecificAssetId(name: name, value: value)
        return try await lookupShells(assetIds: [assetId])
    }

    public func getAllLinkedAssetIds(aasId: String) async throws -> [SpecificAssetId] {
        logger.debug("Mock getting linked asset IDs for: \(aasId)")

        // Simulate network delay
        await simulateNetworkDelay()

        // Return demo asset's specific IDs
        do {
            let descriptor = try demoProvider.loadAASDescriptor()
            return descriptor.specificAssetIds ?? []
        } catch {
            logger.error("Failed to load demo AAS descriptor: \(error.localizedDescription)")
            throw AASError.shellNotFound(identifier: aasId)
        }
    }

    public func linkAssetIds(aasId: String, assetIds: [SpecificAssetId]) async throws {
        logger.debug("Mock link asset IDs (no-op in demo mode)")

        // Simulate network delay
        await simulateNetworkDelay()

        // In demo mode, this is a no-op since we can't persist changes
        logger.info("Demo mode: linkAssetIds is a no-op")
    }

    public func unlinkAssetIds(aasId: String, assetIds: [SpecificAssetId]) async throws {
        logger.debug("Mock unlink asset IDs (no-op in demo mode)")

        // Simulate network delay
        await simulateNetworkDelay()

        // In demo mode, this is a no-op since we can't persist changes
        logger.info("Demo mode: unlinkAssetIds is a no-op")
    }

    // MARK: - Helpers

    /// Simulate a realistic network delay.
    private func simulateNetworkDelay() async {
        let delay = Double.random(in: simulatedDelayRange)
        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
    }
}

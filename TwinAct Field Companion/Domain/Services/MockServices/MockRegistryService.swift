//
//  MockRegistryService.swift
//  TwinAct Field Companion
//
//  Mock implementation of RegistryServiceProtocol for demo mode.
//  Returns demo AAS descriptors without requiring a real backend.
//

import Foundation
import os.log

/// Mock Registry Service that returns demo data for offline/demo mode.
public final class MockRegistryService: RegistryServiceProtocol, @unchecked Sendable {

    // MARK: - Properties

    private let demoProvider = DemoDataProvider.shared
    private let logger = Logger(
        subsystem: AppConfiguration.AppInfo.bundleIdentifier,
        category: "MockRegistryService"
    )

    /// Simulated network delay range (in seconds)
    private let simulatedDelayRange: ClosedRange<Double> = 0.1...0.5

    // MARK: - Initialization

    public init() {
        logger.debug("MockRegistryService initialized for demo mode")
    }

    // MARK: - Read Operations

    public func getAllShellDescriptors(cursor: String? = nil) async throws -> PagedResult<AASDescriptor> {
        logger.debug("Mock getting all shell descriptors")

        await simulateNetworkDelay()

        do {
            let descriptor = try demoProvider.loadAASDescriptor()
            return PagedResult(result: [descriptor], pagingMetadata: nil)
        } catch {
            logger.error("Failed to load demo AAS descriptor: \(error.localizedDescription)")
            throw AASError.networkError(underlying: error)
        }
    }

    public func getShellDescriptor(aasId: String) async throws -> AASDescriptor {
        logger.debug("Mock getting shell descriptor: \(aasId)")

        await simulateNetworkDelay()

        do {
            let descriptor = try demoProvider.loadAASDescriptor()

            // Return demo descriptor for any AAS ID in demo mode
            if aasId == descriptor.id || aasId == demoProvider.demoAASId {
                return descriptor
            }

            // For demo purposes, return the demo descriptor for any lookup
            logger.debug("Returning demo descriptor for unrecognized AAS ID")
            return descriptor
        } catch {
            logger.error("Failed to load demo AAS descriptor: \(error.localizedDescription)")
            throw AASError.shellNotFound(identifier: aasId)
        }
    }

    public func getSubmodelDescriptors(aasId: String) async throws -> [SubmodelDescriptor] {
        logger.debug("Mock getting submodel descriptors for AAS: \(aasId)")

        await simulateNetworkDelay()

        do {
            let descriptor = try demoProvider.loadAASDescriptor()
            return descriptor.submodelDescriptors ?? []
        } catch {
            logger.error("Failed to load demo AAS descriptor: \(error.localizedDescription)")
            throw AASError.shellNotFound(identifier: aasId)
        }
    }

    public func getSubmodelDescriptor(aasId: String, submodelId: String) async throws -> SubmodelDescriptor {
        logger.debug("Mock getting submodel descriptor: \(submodelId)")

        await simulateNetworkDelay()

        let descriptors = try await getSubmodelDescriptors(aasId: aasId)

        if let found = descriptors.first(where: { $0.id == submodelId }) {
            return found
        }

        // Try matching by idShort
        if let found = descriptors.first(where: { $0.idShort == submodelId }) {
            return found
        }

        throw AASError.submodelNotFound(identifier: submodelId)
    }

    public func searchShells(idShort: String) async throws -> [AASDescriptor] {
        logger.debug("Mock searching shells by idShort: \(idShort)")

        await simulateNetworkDelay()

        do {
            let descriptor = try demoProvider.loadAASDescriptor()

            // Match if idShort contains search term
            if let descriptorIdShort = descriptor.idShort,
               descriptorIdShort.lowercased().contains(idShort.lowercased()) {
                return [descriptor]
            }

            // In demo mode, return the demo asset for any search
            return [descriptor]
        } catch {
            return []
        }
    }

    public func searchShells(query: ShellSearchQuery) async throws -> PagedResult<AASDescriptor> {
        logger.debug("Mock searching shells with query")

        await simulateNetworkDelay()

        do {
            let descriptor = try demoProvider.loadAASDescriptor()
            return PagedResult(result: [descriptor], pagingMetadata: nil)
        } catch {
            return PagedResult(result: [], pagingMetadata: nil)
        }
    }

    // MARK: - Write Operations (No-ops in Demo Mode)

    public func registerShell(descriptor: AASDescriptor) async throws {
        logger.info("Demo mode: registerShell is a no-op")
        await simulateNetworkDelay()
        // No-op in demo mode
    }

    public func updateShellDescriptor(aasId: String, descriptor: AASDescriptor) async throws {
        logger.info("Demo mode: updateShellDescriptor is a no-op")
        await simulateNetworkDelay()
        // No-op in demo mode
    }

    public func deleteShellDescriptor(aasId: String) async throws {
        logger.info("Demo mode: deleteShellDescriptor is a no-op")
        await simulateNetworkDelay()
        // No-op in demo mode
    }

    public func registerSubmodelDescriptor(aasId: String, descriptor: SubmodelDescriptor) async throws {
        logger.info("Demo mode: registerSubmodelDescriptor is a no-op")
        await simulateNetworkDelay()
        // No-op in demo mode
    }

    public func deleteSubmodelDescriptor(aasId: String, submodelId: String) async throws {
        logger.info("Demo mode: deleteSubmodelDescriptor is a no-op")
        await simulateNetworkDelay()
        // No-op in demo mode
    }

    // MARK: - Helpers

    private func simulateNetworkDelay() async {
        let delay = Double.random(in: simulatedDelayRange)
        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
    }
}

//
//  MockSubmodelService.swift
//  TwinAct Field Companion
//
//  Mock implementation of SubmodelServiceProtocol for demo mode.
//  Provides demo submodel data without requiring a real backend.
//

import Foundation
import os.log

/// Mock Submodel Service that returns demo data for offline/demo mode.
public final class MockSubmodelService: SubmodelServiceProtocol, @unchecked Sendable {

    // MARK: - Properties

    private let demoProvider = DemoDataProvider.shared
    private let mockRegistry: MockRegistryService
    private let mockRepository: MockRepositoryService
    private let logger = Logger(
        subsystem: AppConfiguration.AppInfo.bundleIdentifier,
        category: "MockSubmodelService"
    )

    /// Simulated network delay range (in seconds)
    private let simulatedDelayRange: ClosedRange<Double> = 0.1...0.5

    // MARK: - Initialization

    public init(
        registryService: RegistryServiceProtocol? = nil,
        repositoryService: RepositoryServiceProtocol? = nil
    ) {
        // Use provided mock services or create new ones
        self.mockRegistry = (registryService as? MockRegistryService) ?? MockRegistryService()
        self.mockRepository = (repositoryService as? MockRepositoryService) ?? MockRepositoryService()
        logger.debug("MockSubmodelService initialized for demo mode")
    }

    // MARK: - SubmodelServiceProtocol

    public func getSubmodel(submodelId: String) async throws -> Submodel {
        logger.debug("Mock getting submodel: \(submodelId)")
        return try await mockRepository.getSubmodel(submodelId: submodelId)
    }

    public func getElementValue<T: Decodable>(submodelId: String, path: String) async throws -> T {
        logger.debug("Mock getting element value: \(path)")
        await simulateNetworkDelay()

        // Return demo values based on path
        if let result = getDemoValue(for: path) as? T {
            return result
        }

        throw AASError.elementNotFound(path: path)
    }

    public func setElementValue<T: Encodable>(submodelId: String, path: String, value: T) async throws {
        logger.info("Demo mode: setElementValue is a no-op")
        await simulateNetworkDelay()
    }

    public func getPropertyValue(submodelId: String, path: String) async throws -> String? {
        logger.debug("Mock getting property value: \(path)")
        await simulateNetworkDelay()

        // Return demo value based on path
        return getDemoValue(for: path) as? String
    }

    public func setPropertyValue(submodelId: String, path: String, value: String) async throws {
        logger.info("Demo mode: setPropertyValue is a no-op")
        await simulateNetworkDelay()
    }

    public func getSubmodelBySemanticId(aasId: String, semanticId: String) async throws -> Submodel? {
        logger.debug("Mock getting submodel by semantic ID: \(semanticId)")
        await simulateNetworkDelay()

        // Map semantic ID to demo submodel
        let lowerId = semanticId.lowercased()

        if lowerId.contains("nameplate") {
            return try await mockRepository.getSubmodel(submodelId: "urn:demo:submodel:nameplate:smartpump001")
        } else if lowerId.contains("documentation") {
            return try await mockRepository.getSubmodel(submodelId: "urn:demo:submodel:documentation:smartpump001")
        } else if lowerId.contains("carbonfootprint") || lowerId.contains("sustainability") {
            return try await mockRepository.getSubmodel(submodelId: "urn:demo:submodel:carbonfootprint:smartpump001")
        } else if lowerId.contains("servicerequest") {
            return try await mockRepository.getSubmodel(submodelId: "urn:demo:submodel:servicerequest:smartpump001")
        } else if lowerId.contains("timeseries") {
            return try await mockRepository.getSubmodel(submodelId: "urn:demo:submodel:timeseries:smartpump001")
        } else if lowerId.contains("maintenance") {
            return try await mockRepository.getSubmodel(submodelId: "urn:demo:submodel:maintenance:smartpump001")
        } else if lowerId.contains("technicaldata") {
            return try await mockRepository.getSubmodel(submodelId: "urn:demo:submodel:technicaldata:smartpump001")
        }

        return nil
    }

    public func getSubmodelsForShell(aasId: String) async throws -> [Submodel] {
        logger.debug("Mock getting all submodels for AAS: \(aasId)")
        await simulateNetworkDelay()

        // Return all demo submodels
        var submodels: [Submodel] = []

        let submodelIds = [
            "urn:demo:submodel:nameplate:smartpump001",
            "urn:demo:submodel:documentation:smartpump001",
            "urn:demo:submodel:carbonfootprint:smartpump001",
            "urn:demo:submodel:servicerequest:smartpump001",
            "urn:demo:submodel:timeseries:smartpump001",
            "urn:demo:submodel:maintenance:smartpump001",
            "urn:demo:submodel:technicaldata:smartpump001"
        ]

        for id in submodelIds {
            if let submodel = try? await mockRepository.getSubmodel(submodelId: id) {
                submodels.append(submodel)
            }
        }

        return submodels
    }

    // MARK: - Helpers

    private func simulateNetworkDelay() async {
        let delay = Double.random(in: simulatedDelayRange)
        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
    }

    /// Get demo value for common property paths.
    private func getDemoValue(for path: String) -> Any? {
        let lowerPath = path.lowercased()

        // Nameplate values
        if lowerPath.contains("manufacturername") {
            return (try? demoProvider.loadDigitalNameplate().manufacturerName) ?? "PumpTech Industrial Solutions GmbH"
        }
        if lowerPath.contains("serialnumber") {
            return (try? demoProvider.loadDigitalNameplate().serialNumber) ?? "SP500-2025-0042"
        }
        if lowerPath.contains("productdesignation") {
            return (try? demoProvider.loadDigitalNameplate().manufacturerProductDesignation) ?? "Smart Industrial Pump SP-500"
        }
        if lowerPath.contains("yearofconstruction") {
            return (try? demoProvider.loadDigitalNameplate().yearOfConstruction).map { String($0) } ?? "2025"
        }

        // Technical data values
        if lowerPath.contains("maxpressure") { return "16" }
        if lowerPath.contains("maxflowrate") { return "150" }
        if lowerPath.contains("ratedpower") { return "22" }
        if lowerPath.contains("ratedspeed") { return "2950" }
        if lowerPath.contains("weight") { return "85" }
        if lowerPath.contains("noiselevel") { return "72" }
        if lowerPath.contains("operatingtemperature") { return "-10 to +60 C" }
        if lowerPath.contains("protectionclass") { return "IP55" }

        // Carbon footprint values
        if lowerPath.contains("pcfco2eq") {
            return (try? demoProvider.loadCarbonFootprint().pcfCO2eq).map { String($0) }
        }
        if lowerPath.contains("recyclability") {
            return (try? demoProvider.loadCarbonFootprint().recyclabilityPercentage).map { String($0) }
        }

        return nil
    }
}

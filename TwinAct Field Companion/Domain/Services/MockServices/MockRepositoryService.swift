//
//  MockRepositoryService.swift
//  TwinAct Field Companion
//
//  Mock implementation of RepositoryServiceProtocol for demo mode.
//  Returns demo data without requiring a real backend.
//

import Foundation
import os.log

/// Mock Repository Service that returns demo data for offline/demo mode.
public final class MockRepositoryService: RepositoryServiceProtocol, @unchecked Sendable {

    // MARK: - Properties

    private let demoProvider = DemoDataProvider.shared
    private let logger = Logger(
        subsystem: AppConfiguration.AppInfo.bundleIdentifier,
        category: "MockRepositoryService"
    )

    /// Simulated network delay range (in seconds)
    private let simulatedDelayRange: ClosedRange<Double> = 0.1...0.5

    /// In-memory storage for service requests (to simulate write operations)
    private var serviceRequestsStorage: [ServiceRequest]?

    // MARK: - Initialization

    public init() {
        logger.debug("MockRepositoryService initialized for demo mode")
    }

    // MARK: - Shell Operations

    public func getAllShells(cursor: String? = nil) async throws -> PagedResult<AssetAdministrationShell> {
        logger.debug("Mock getting all shells")
        await simulateNetworkDelay()

        // Create a demo shell from the descriptor
        let descriptor = try demoProvider.loadAASDescriptor()
        let nameplate = try? demoProvider.loadDigitalNameplate()

        let shell = AssetAdministrationShell(
            id: descriptor.id,
            idShort: descriptor.idShort,
            description: descriptor.description,
            displayName: descriptor.displayName,
            administration: descriptor.administration,
            assetInformation: AssetInformation(
                assetKind: descriptor.assetKind ?? .instance,
                globalAssetId: descriptor.globalAssetId,
                specificAssetIds: descriptor.specificAssetIds
            )
        )

        return PagedResult(result: [shell], pagingMetadata: nil)
    }

    public func getShell(aasId: String) async throws -> AssetAdministrationShell {
        logger.debug("Mock getting shell: \(aasId)")
        await simulateNetworkDelay()

        let result = try await getAllShells()
        guard let shell = result.result.first else {
            throw AASError.shellNotFound(identifier: aasId)
        }
        return shell
    }

    public func createShell(_ shell: AssetAdministrationShell) async throws {
        logger.info("Demo mode: createShell is a no-op")
        await simulateNetworkDelay()
    }

    public func updateShell(aasId: String, shell: AssetAdministrationShell) async throws {
        logger.info("Demo mode: updateShell is a no-op")
        await simulateNetworkDelay()
    }

    public func deleteShell(aasId: String) async throws {
        logger.info("Demo mode: deleteShell is a no-op")
        await simulateNetworkDelay()
    }

    // MARK: - Submodel Operations

    public func getSubmodel(submodelId: String) async throws -> Submodel {
        logger.debug("Mock getting submodel: \(submodelId)")
        await simulateNetworkDelay()

        // Create demo submodel based on semantic ID or idShort
        let lowerId = submodelId.lowercased()

        if lowerId.contains("nameplate") {
            return try createNameplateSubmodel()
        } else if lowerId.contains("documentation") {
            return try createDocumentationSubmodel()
        } else if lowerId.contains("carbonfootprint") || lowerId.contains("sustainability") {
            return try createCarbonFootprintSubmodel()
        } else if lowerId.contains("servicerequest") {
            return try createServiceRequestSubmodel()
        } else if lowerId.contains("timeseries") {
            return try createTimeSeriesSubmodel()
        } else if lowerId.contains("maintenance") {
            return try createMaintenanceSubmodel()
        } else if lowerId.contains("technicaldata") {
            return createTechnicalDataSubmodel()
        }

        // Default: return a generic demo submodel
        return Submodel(
            id: submodelId,
            idShort: "DemoSubmodel",
            description: [LangString(language: "en", text: "Demo submodel data")]
        )
    }

    public func getSubmodelValue(submodelId: String) async throws -> SubmodelValue {
        logger.debug("Mock getting submodel value: \(submodelId)")
        await simulateNetworkDelay()

        // Return simple value representation
        return SubmodelValue(values: ["demo": AnyCodable("Demo value")])
    }

    public func createSubmodel(_ submodel: Submodel) async throws {
        logger.info("Demo mode: createSubmodel is a no-op")
        await simulateNetworkDelay()
    }

    public func updateSubmodel(submodelId: String, submodel: Submodel) async throws {
        logger.info("Demo mode: updateSubmodel is a no-op")
        await simulateNetworkDelay()
    }

    public func deleteSubmodel(submodelId: String) async throws {
        logger.info("Demo mode: deleteSubmodel is a no-op")
        await simulateNetworkDelay()
    }

    // MARK: - Submodel Element Operations

    public func getAllSubmodelElements(submodelId: String) async throws -> [SubmodelElement] {
        logger.debug("Mock getting all elements for: \(submodelId)")
        await simulateNetworkDelay()

        let submodel = try await getSubmodel(submodelId: submodelId)
        return submodel.submodelElements ?? []
    }

    public func getSubmodelElement(submodelId: String, idShortPath: String) async throws -> SubmodelElement {
        logger.debug("Mock getting element: \(idShortPath)")
        await simulateNetworkDelay()

        let submodel = try await getSubmodel(submodelId: submodelId)
        guard let element = submodel.element(at: idShortPath) else {
            throw AASError.elementNotFound(path: idShortPath)
        }
        return element
    }

    public func getSubmodelElementValue(submodelId: String, idShortPath: String) async throws -> Data {
        logger.debug("Mock getting element value: \(idShortPath)")
        await simulateNetworkDelay()

        // Return a simple JSON value
        return Data("{\"value\": \"demo\"}".utf8)
    }

    public func updateSubmodelElement(submodelId: String, idShortPath: String, element: SubmodelElement) async throws {
        logger.info("Demo mode: updateSubmodelElement is a no-op")
        await simulateNetworkDelay()
    }

    public func updateSubmodelElementValue(submodelId: String, idShortPath: String, value: String) async throws {
        logger.info("Demo mode: updateSubmodelElementValue is a no-op")
        await simulateNetworkDelay()
    }

    public func createSubmodelElement(submodelId: String, element: SubmodelElement) async throws {
        logger.info("Demo mode: createSubmodelElement is a no-op")
        await simulateNetworkDelay()
    }

    public func deleteSubmodelElement(submodelId: String, idShortPath: String) async throws {
        logger.info("Demo mode: deleteSubmodelElement is a no-op")
        await simulateNetworkDelay()
    }

    // MARK: - Operation Invocation

    public func invokeOperation(submodelId: String, idShortPath: String, request: OperationRequest) async throws -> OperationResult {
        logger.debug("Mock invoking operation: \(idShortPath)")
        await simulateNetworkDelay()

        return OperationResult(
            executionState: .completed,
            success: true,
            messages: [OperationMessage(text: "Demo operation completed successfully")]
        )
    }

    public func invokeOperationAsync(submodelId: String, idShortPath: String, request: OperationRequest) async throws -> String {
        logger.debug("Mock invoking async operation: \(idShortPath)")
        await simulateNetworkDelay()

        return "demo-handle-\(UUID().uuidString.prefix(8))"
    }

    public func getOperationResult(submodelId: String, idShortPath: String, handleId: String) async throws -> OperationResult {
        logger.debug("Mock getting operation result: \(handleId)")
        await simulateNetworkDelay()

        return OperationResult(
            executionState: .completed,
            success: true
        )
    }

    // MARK: - File Operations

    public func getFileContent(submodelId: String, idShortPath: String) async throws -> (data: Data, contentType: String) {
        logger.debug("Mock getting file content: \(idShortPath)")
        await simulateNetworkDelay()

        // Return placeholder PDF data
        let placeholderText = "Demo file content for \(idShortPath)"
        return (Data(placeholderText.utf8), "text/plain")
    }

    public func uploadFileContent(submodelId: String, idShortPath: String, data: Data, contentType: String) async throws {
        logger.info("Demo mode: uploadFileContent is a no-op")
        await simulateNetworkDelay()
    }

    // MARK: - Demo Submodel Builders

    private func createNameplateSubmodel() throws -> Submodel {
        let nameplate = try demoProvider.loadDigitalNameplate()

        var elements: [SubmodelElement] = []

        if let name = nameplate.manufacturerName {
            elements.append(.property(Property(idShort: "ManufacturerName", valueType: .string, value: name)))
        }
        if let designation = nameplate.manufacturerProductDesignation {
            elements.append(.property(Property(idShort: "ManufacturerProductDesignation", valueType: .string, value: designation)))
        }
        if let serialNumber = nameplate.serialNumber {
            elements.append(.property(Property(idShort: "SerialNumber", valueType: .string, value: serialNumber)))
        }
        if let yearOfConstruction = nameplate.yearOfConstruction {
            elements.append(.property(Property(idShort: "YearOfConstruction", valueType: .int, value: String(yearOfConstruction))))
        }

        return Submodel(
            id: "urn:demo:submodel:nameplate:smartpump001",
            idShort: "DigitalNameplate",
            semanticId: Reference(type: .externalReference, keys: [Key(type: .globalReference, value: DigitalNameplate.semanticId)]),
            submodelElements: elements
        )
    }

    private func createDocumentationSubmodel() throws -> Submodel {
        let docs = try demoProvider.loadDocumentation()

        var elements: [SubmodelElement] = []
        for doc in docs.documents {
            let title = doc.title.englishText ?? doc.id
            elements.append(.property(Property(idShort: doc.id, valueType: .string, value: title)))
        }

        return Submodel(
            id: "urn:demo:submodel:documentation:smartpump001",
            idShort: "HandoverDocumentation",
            semanticId: Reference(type: .externalReference, keys: [Key(type: .globalReference, value: HandoverDocumentation.semanticId)]),
            submodelElements: elements
        )
    }

    private func createCarbonFootprintSubmodel() throws -> Submodel {
        let footprint = try demoProvider.loadCarbonFootprint()

        var elements: [SubmodelElement] = []

        if let pcf = footprint.pcfCO2eq {
            elements.append(.property(Property(idShort: "PCFCO2eq", valueType: .double, value: String(pcf))))
        }
        if let tcf = footprint.tcfCO2eq {
            elements.append(.property(Property(idShort: "TCFCO2eq", valueType: .double, value: String(tcf))))
        }
        if let ucf = footprint.ucfCO2eq {
            elements.append(.property(Property(idShort: "UCFCO2eq", valueType: .double, value: String(ucf))))
        }
        if let recyclability = footprint.recyclabilityPercentage {
            elements.append(.property(Property(idShort: "RecyclabilityPercentage", valueType: .double, value: String(recyclability))))
        }

        return Submodel(
            id: "urn:demo:submodel:carbonfootprint:smartpump001",
            idShort: "CarbonFootprint",
            semanticId: Reference(type: .externalReference, keys: [Key(type: .globalReference, value: CarbonFootprint.semanticId)]),
            submodelElements: elements
        )
    }

    private func createServiceRequestSubmodel() throws -> Submodel {
        // Load from storage if modified, otherwise from demo provider
        let requests = serviceRequestsStorage ?? (try? demoProvider.loadServiceRequests()) ?? []

        var elements: [SubmodelElement] = []
        for request in requests {
            elements.append(.property(Property(idShort: request.id, valueType: .string, value: request.title)))
        }

        return Submodel(
            id: "urn:demo:submodel:servicerequest:smartpump001",
            idShort: "ServiceRequest",
            semanticId: Reference(type: .externalReference, keys: [Key(type: .globalReference, value: ServiceRequest.semanticId)]),
            submodelElements: elements
        )
    }

    private func createTimeSeriesSubmodel() throws -> Submodel {
        let timeSeries = try demoProvider.loadTimeSeriesData()

        var elements: [SubmodelElement] = []
        elements.append(.property(Property(idShort: "Name", valueType: .string, value: timeSeries.metadata.name)))
        elements.append(.property(Property(idShort: "RecordCount", valueType: .int, value: String(timeSeries.records.count))))

        if let samplingInterval = timeSeries.metadata.samplingInterval {
            elements.append(.property(Property(idShort: "SamplingInterval", valueType: .double, value: String(samplingInterval))))
        }

        return Submodel(
            id: "urn:demo:submodel:timeseries:smartpump001",
            idShort: "TimeSeriesData",
            semanticId: Reference(type: .externalReference, keys: [Key(type: .globalReference, value: TimeSeriesData.semanticId)]),
            submodelElements: elements
        )
    }

    private func createMaintenanceSubmodel() throws -> Submodel {
        let maintenance = try demoProvider.loadMaintenanceInstructions()

        var elements: [SubmodelElement] = []
        for instruction in maintenance.instructions {
            let title = instruction.title.englishText ?? instruction.id
            elements.append(.property(Property(idShort: instruction.id, valueType: .string, value: title)))
        }

        return Submodel(
            id: "urn:demo:submodel:maintenance:smartpump001",
            idShort: "MaintenanceInstructions",
            semanticId: Reference(type: .externalReference, keys: [Key(type: .globalReference, value: MaintenanceInstructions.semanticId)]),
            submodelElements: elements
        )
    }

    private func createTechnicalDataSubmodel() -> Submodel {
        let elements: [SubmodelElement] = [
            .property(Property(idShort: "MaxPressure", valueType: .double, value: "16")),
            .property(Property(idShort: "MaxFlowRate", valueType: .double, value: "150")),
            .property(Property(idShort: "RatedPower", valueType: .double, value: "22")),
            .property(Property(idShort: "RatedSpeed", valueType: .int, value: "2950")),
            .property(Property(idShort: "Weight", valueType: .double, value: "85")),
            .property(Property(idShort: "NoiseLevel", valueType: .double, value: "72")),
            .property(Property(idShort: "OperatingTemperature", valueType: .string, value: "-10 to +60 C")),
            .property(Property(idShort: "ProtectionClass", valueType: .string, value: "IP55"))
        ]

        return Submodel(
            id: "urn:demo:submodel:technicaldata:smartpump001",
            idShort: "TechnicalData",
            semanticId: Reference(type: .externalReference, keys: [Key(type: .globalReference, value: IDTASemanticId.technicalData)]),
            submodelElements: elements
        )
    }

    // MARK: - Helpers

    private func simulateNetworkDelay() async {
        let delay = Double.random(in: simulatedDelayRange)
        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
    }
}

//
//  SubmodelService.swift
//  TwinAct Field Companion
//
//  Unified submodel access service combining registry and repository operations.
//  Provides high-level APIs for common submodel operations.
//

import Foundation
import os.log

// MARK: - Submodel Service Protocol

/// Unified submodel access protocol combining registry and repository operations.
public protocol SubmodelServiceProtocol: Sendable {
    /// Get submodel with all elements populated.
    /// - Parameter submodelId: The submodel identifier
    /// - Returns: The complete submodel
    func getSubmodel(submodelId: String) async throws -> Submodel

    /// Get specific element value with type conversion.
    /// - Parameters:
    ///   - submodelId: The submodel identifier
    ///   - path: The idShort path to the element
    /// - Returns: The decoded value
    func getElementValue<T: Decodable>(submodelId: String, path: String) async throws -> T

    /// Set element value with type conversion.
    /// - Parameters:
    ///   - submodelId: The submodel identifier
    ///   - path: The idShort path to the element
    ///   - value: The value to set
    func setElementValue<T: Encodable>(submodelId: String, path: String, value: T) async throws

    /// Get property value as string.
    /// - Parameters:
    ///   - submodelId: The submodel identifier
    ///   - path: The idShort path to the property
    /// - Returns: The property value as string
    func getPropertyValue(submodelId: String, path: String) async throws -> String?

    /// Set property value from string.
    /// - Parameters:
    ///   - submodelId: The submodel identifier
    ///   - path: The idShort path to the property
    ///   - value: The string value to set
    func setPropertyValue(submodelId: String, path: String, value: String) async throws

    /// Get submodel by semantic ID for an AAS.
    /// - Parameters:
    ///   - aasId: The AAS identifier
    ///   - semanticId: The semantic ID of the submodel
    /// - Returns: The submodel if found
    func getSubmodelBySemanticId(aasId: String, semanticId: String) async throws -> Submodel?

    /// Get all submodels for an AAS.
    /// - Parameter aasId: The AAS identifier
    /// - Returns: Array of submodels
    func getSubmodelsForShell(aasId: String) async throws -> [Submodel]
}

// MARK: - Submodel Service Implementation

/// Implementation of unified submodel access service.
public final class SubmodelService: SubmodelServiceProtocol, @unchecked Sendable {

    // MARK: - Properties

    private let registryService: RegistryServiceProtocol
    private let repositoryService: RepositoryServiceProtocol
    private let logger: Logger

    // MARK: - Initialization

    /// Initialize with registry and repository services.
    /// - Parameters:
    ///   - registryService: The registry service
    ///   - repositoryService: The repository service
    public init(
        registryService: RegistryServiceProtocol,
        repositoryService: RepositoryServiceProtocol
    ) {
        self.registryService = registryService
        self.repositoryService = repositoryService
        self.logger = Logger(
            subsystem: AppConfiguration.AppInfo.bundleIdentifier,
            category: "SubmodelService"
        )
    }

    /// Initialize with default services.
    /// - Parameter tokenProvider: Optional token provider for authentication
    public convenience init(tokenProvider: TokenProvider? = nil) {
        self.init(
            registryService: RegistryService(tokenProvider: tokenProvider),
            repositoryService: RepositoryService(tokenProvider: tokenProvider)
        )
    }

    // MARK: - SubmodelServiceProtocol Implementation

    public func getSubmodel(submodelId: String) async throws -> Submodel {
        logger.debug("Getting submodel: \(submodelId)")
        return try await repositoryService.getSubmodel(submodelId: submodelId)
    }

    public func getElementValue<T: Decodable>(submodelId: String, path: String) async throws -> T {
        logger.debug("Getting element value: \(path) from submodel: \(submodelId)")

        let data = try await repositoryService.getSubmodelElementValue(
            submodelId: submodelId,
            idShortPath: path
        )

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw AASError.decodingError(
                message: "Failed to decode value at path '\(path)'",
                underlying: error
            )
        }
    }

    public func setElementValue<T: Encodable>(submodelId: String, path: String, value: T) async throws {
        logger.debug("Setting element value: \(path) in submodel: \(submodelId)")

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601

        let data: Data
        do {
            data = try encoder.encode(value)
        } catch {
            throw AASError.encodingError(identifier: path)
        }

        // Convert to string for the API
        guard let stringValue = String(data: data, encoding: .utf8) else {
            throw AASError.encodingError(identifier: path)
        }

        // Remove quotes if it's a simple string value
        let cleanValue = stringValue.trimmingCharacters(in: CharacterSet(charactersIn: "\""))

        try await repositoryService.updateSubmodelElementValue(
            submodelId: submodelId,
            idShortPath: path,
            value: cleanValue
        )
    }

    public func getPropertyValue(submodelId: String, path: String) async throws -> String? {
        logger.debug("Getting property value: \(path)")

        let element = try await repositoryService.getSubmodelElement(
            submodelId: submodelId,
            idShortPath: path
        )

        switch element {
        case .property(let property):
            return property.value

        case .multiLanguageProperty(let mlp):
            return mlp.value?.englishText

        default:
            throw AASError.invalidPath(
                path: path,
                reason: "Element at path is not a property"
            )
        }
    }

    public func setPropertyValue(submodelId: String, path: String, value: String) async throws {
        logger.debug("Setting property value: \(path)")

        try await repositoryService.updateSubmodelElementValue(
            submodelId: submodelId,
            idShortPath: path,
            value: value
        )
    }

    public func getSubmodelBySemanticId(aasId: String, semanticId: String) async throws -> Submodel? {
        logger.debug("Getting submodel with semantic ID: \(semanticId) for AAS: \(aasId)")

        // Get all submodel descriptors for this AAS
        let descriptors = try await registryService.getSubmodelDescriptors(aasId: aasId)

        // Find the one with matching semantic ID
        guard let descriptor = descriptors.first(where: { descriptor in
            guard let descSemanticId = descriptor.semanticId else { return false }
            return descSemanticId.keys.contains { $0.value == semanticId }
        }) else {
            logger.debug("No submodel found with semantic ID: \(semanticId)")
            return nil
        }

        // Fetch the full submodel
        return try await repositoryService.getSubmodel(submodelId: descriptor.id)
    }

    public func getSubmodelsForShell(aasId: String) async throws -> [Submodel] {
        logger.debug("Getting all submodels for AAS: \(aasId)")

        // Get submodel descriptors from registry
        let descriptors = try await registryService.getSubmodelDescriptors(aasId: aasId)

        // Fetch each submodel in parallel
        return try await withThrowingTaskGroup(of: Submodel?.self) { group in
            for descriptor in descriptors {
                group.addTask {
                    do {
                        return try await self.repositoryService.getSubmodel(submodelId: descriptor.id)
                    } catch {
                        self.logger.error("Failed to fetch submodel \(descriptor.id): \(error.localizedDescription)")
                        return nil
                    }
                }
            }

            var submodels: [Submodel] = []
            for try await submodel in group {
                if let submodel = submodel {
                    submodels.append(submodel)
                }
            }

            return submodels
        }
    }
}

// MARK: - Convenience Extensions

extension SubmodelService {

    // MARK: - Digital Nameplate Access

    /// Get the Digital Nameplate submodel for an AAS.
    /// - Parameter aasId: The AAS identifier
    /// - Returns: The nameplate submodel if found
    public func getDigitalNameplate(aasId: String) async throws -> Submodel? {
        try await getSubmodelBySemanticId(aasId: aasId, semanticId: IDTASemanticId.digitalNameplate)
    }

    /// Get manufacturer name from Digital Nameplate.
    /// - Parameter aasId: The AAS identifier
    /// - Returns: The manufacturer name
    public func getManufacturerName(aasId: String) async throws -> String? {
        guard let nameplate = try await getDigitalNameplate(aasId: aasId) else {
            return nil
        }
        return try await getPropertyValue(submodelId: nameplate.id, path: "ManufacturerName")
    }

    /// Get serial number from Digital Nameplate.
    /// - Parameter aasId: The AAS identifier
    /// - Returns: The serial number
    public func getSerialNumber(aasId: String) async throws -> String? {
        guard let nameplate = try await getDigitalNameplate(aasId: aasId) else {
            return nil
        }
        return try await getPropertyValue(submodelId: nameplate.id, path: "SerialNumber")
    }

    // MARK: - Technical Data Access

    /// Get the Technical Data submodel for an AAS.
    /// - Parameter aasId: The AAS identifier
    /// - Returns: The technical data submodel if found
    public func getTechnicalData(aasId: String) async throws -> Submodel? {
        try await getSubmodelBySemanticId(aasId: aasId, semanticId: IDTASemanticId.technicalData)
    }

    // MARK: - Documentation Access

    /// Get the Documentation submodel for an AAS.
    /// - Parameter aasId: The AAS identifier
    /// - Returns: The documentation submodel if found
    public func getDocumentation(aasId: String) async throws -> Submodel? {
        try await getSubmodelBySemanticId(aasId: aasId, semanticId: IDTASemanticId.documentation)
    }

    // MARK: - Carbon Footprint Access

    /// Get the Carbon Footprint (PCF) submodel for an AAS.
    /// - Parameter aasId: The AAS identifier
    /// - Returns: The carbon footprint submodel if found
    public func getCarbonFootprint(aasId: String) async throws -> Submodel? {
        try await getSubmodelBySemanticId(aasId: aasId, semanticId: IDTASemanticId.carbonFootprint)
    }

    // MARK: - Element Traversal

    /// Get all properties from a submodel as a dictionary.
    /// - Parameter submodelId: The submodel identifier
    /// - Returns: Dictionary of property idShorts to values
    public func getAllProperties(submodelId: String) async throws -> [String: String?] {
        let submodel = try await getSubmodel(submodelId: submodelId)

        var properties: [String: String?] = [:]
        let flattened = submodel.flattenedElements()

        for (path, element) in flattened {
            switch element {
            case .property(let property):
                properties[path] = property.value
            case .multiLanguageProperty(let mlp):
                properties[path] = mlp.value?.englishText
            default:
                break
            }
        }

        return properties
    }

    /// Find elements by semantic ID within a submodel.
    /// - Parameters:
    ///   - submodelId: The submodel identifier
    ///   - semanticId: The semantic ID to search for
    /// - Returns: Array of matching elements with their paths
    public func findElementsBySemanticId(
        submodelId: String,
        semanticId: String
    ) async throws -> [(path: String, element: SubmodelElement)] {
        let submodel = try await getSubmodel(submodelId: submodelId)
        let flattened = submodel.flattenedElements()

        return flattened.filter { _, element in
            guard let elemSemanticId = element.semanticId else { return false }
            return elemSemanticId.keys.contains { $0.value == semanticId }
        }
    }
}

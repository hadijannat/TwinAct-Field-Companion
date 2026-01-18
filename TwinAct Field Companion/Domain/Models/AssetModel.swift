//
//  AssetModel.swift
//  TwinAct Field Companion
//
//  Core asset domain models that aggregate AAS data into app-friendly structures.
//

import Foundation

// MARK: - Asset

/// A high-level asset representation combining AAS descriptor with parsed submodels.
public struct Asset: Identifiable, Sendable {
    /// Unique identifier (matches AAS globalAssetId)
    public let id: String

    /// Short display name
    public let name: String

    /// Asset type/category
    public let assetType: String?

    /// Manufacturer name
    public let manufacturer: String?

    /// Serial number
    public let serialNumber: String?

    /// Model/product designation
    public let model: String?

    /// Thumbnail image URL
    public let thumbnailURL: URL?

    /// AAS descriptor for API access
    public let aasDescriptor: AASDescriptor?

    /// Available submodel types
    public let availableSubmodels: Set<SubmodelType>

    public init(
        id: String,
        name: String,
        assetType: String? = nil,
        manufacturer: String? = nil,
        serialNumber: String? = nil,
        model: String? = nil,
        thumbnailURL: URL? = nil,
        aasDescriptor: AASDescriptor? = nil,
        availableSubmodels: Set<SubmodelType> = []
    ) {
        self.id = id
        self.name = name
        self.assetType = assetType
        self.manufacturer = manufacturer
        self.serialNumber = serialNumber
        self.model = model
        self.thumbnailURL = thumbnailURL
        self.aasDescriptor = aasDescriptor
        self.availableSubmodels = availableSubmodels
    }

    /// Create from AAS descriptor and digital nameplate
    public init(from descriptor: AASDescriptor, nameplate: DigitalNameplate? = nil) {
        self.id = descriptor.globalAssetId ?? descriptor.id
        self.name = descriptor.idShort ?? descriptor.displayName?.englishText ?? "Unknown Asset"
        self.aasDescriptor = descriptor
        self.assetType = descriptor.assetKind?.rawValue

        if let nameplate = nameplate {
            self.manufacturer = nameplate.manufacturerName
            self.serialNumber = nameplate.serialNumber
            self.model = nameplate.manufacturerProductDesignation
            self.thumbnailURL = nameplate.productImage
        } else {
            self.manufacturer = nil
            self.serialNumber = nil
            self.model = nil
            self.thumbnailURL = nil
        }

        // Determine available submodels from descriptors
        var submodels: Set<SubmodelType> = []
        for submodelDescriptor in descriptor.submodelDescriptors ?? [] {
            if let type = SubmodelType.from(semanticId: submodelDescriptor.semanticId) {
                submodels.insert(type)
            }
        }
        self.availableSubmodels = submodels
    }

    /// Whether this asset has a nameplate
    public var hasNameplate: Bool {
        availableSubmodels.contains(.digitalNameplate)
    }

    /// Whether this asset has documentation
    public var hasDocumentation: Bool {
        availableSubmodels.contains(.handoverDocumentation)
    }

    /// Whether this asset has maintenance info
    public var hasMaintenance: Bool {
        availableSubmodels.contains(.maintenanceInstructions)
    }

    /// Whether this asset supports service requests
    public var supportsServiceRequests: Bool {
        availableSubmodels.contains(.serviceRequest)
    }

    /// Whether this asset has time series data
    public var hasTimeSeriesData: Bool {
        availableSubmodels.contains(.timeSeriesData)
    }

    /// Whether this asset has carbon footprint data
    public var hasCarbonFootprint: Bool {
        availableSubmodels.contains(.carbonFootprint)
    }
}

// MARK: - Submodel Type

/// Supported IDTA submodel types.
public enum SubmodelType: String, CaseIterable, Sendable {
    case digitalNameplate
    case handoverDocumentation
    case maintenanceInstructions
    case serviceRequest
    case timeSeriesData
    case carbonFootprint
    case technicalData
    case contactInformation

    /// Human-readable display name
    public var displayName: String {
        switch self {
        case .digitalNameplate: return "Digital Nameplate"
        case .handoverDocumentation: return "Documentation"
        case .maintenanceInstructions: return "Maintenance"
        case .serviceRequest: return "Service Request"
        case .timeSeriesData: return "Time Series Data"
        case .carbonFootprint: return "Carbon Footprint"
        case .technicalData: return "Technical Data"
        case .contactInformation: return "Contact Information"
        }
    }

    /// SF Symbol icon name
    public var iconName: String {
        switch self {
        case .digitalNameplate: return "tag.fill"
        case .handoverDocumentation: return "doc.fill"
        case .maintenanceInstructions: return "wrench.and.screwdriver.fill"
        case .serviceRequest: return "ticket.fill"
        case .timeSeriesData: return "chart.line.uptrend.xyaxis"
        case .carbonFootprint: return "leaf.fill"
        case .technicalData: return "cpu.fill"
        case .contactInformation: return "person.crop.circle.fill"
        }
    }

    /// Whether this submodel is writable
    public var isWritable: Bool {
        self == .serviceRequest
    }

    /// IDTA semantic ID for this submodel type
    public var semanticId: String {
        switch self {
        case .digitalNameplate:
            return DigitalNameplate.semanticId
        case .handoverDocumentation:
            return HandoverDocumentation.semanticId
        case .maintenanceInstructions:
            return MaintenanceInstructions.semanticId
        case .serviceRequest:
            return ServiceRequest.semanticId
        case .timeSeriesData:
            return TimeSeriesData.semanticId
        case .carbonFootprint:
            return CarbonFootprint.semanticId
        case .technicalData:
            return IDTASemanticId.technicalData
        case .contactInformation:
            return IDTASemanticId.contactInformation
        }
    }

    /// Create from semantic ID reference
    public static func from(semanticId: Reference?) -> SubmodelType? {
        guard let semanticId = semanticId,
              let idValue = semanticId.keys.first?.value else {
            return nil
        }

        return from(semanticIdString: idValue)
    }

    /// Create from semantic ID string
    public static func from(semanticIdString: String) -> SubmodelType? {
        let lowercased = semanticIdString.lowercased()

        if lowercased.contains("nameplate") {
            return .digitalNameplate
        }
        if lowercased.contains("handoverdocumentation") || lowercased.contains("documentation") {
            return .handoverDocumentation
        }
        if lowercased.contains("maintenance") {
            return .maintenanceInstructions
        }
        if lowercased.contains("servicerequest") {
            return .serviceRequest
        }
        if lowercased.contains("timeseries") {
            return .timeSeriesData
        }
        if lowercased.contains("carbonfootprint") || lowercased.contains("sustainability") {
            return .carbonFootprint
        }
        if lowercased.contains("technicaldata") {
            return .technicalData
        }
        if lowercased.contains("contactinformation") {
            return .contactInformation
        }

        return nil
    }
}

// MARK: - Asset Summary

/// Lightweight summary for list displays.
public struct AssetSummary: Identifiable, Sendable, Hashable {
    public let id: String
    public let name: String
    public let manufacturer: String?
    public let model: String?
    public let thumbnailURL: URL?
    public let submodelCount: Int

    public init(
        id: String,
        name: String,
        manufacturer: String? = nil,
        model: String? = nil,
        thumbnailURL: URL? = nil,
        submodelCount: Int = 0
    ) {
        self.id = id
        self.name = name
        self.manufacturer = manufacturer
        self.model = model
        self.thumbnailURL = thumbnailURL
        self.submodelCount = submodelCount
    }

    /// Create from full Asset
    public init(from asset: Asset) {
        self.id = asset.id
        self.name = asset.name
        self.manufacturer = asset.manufacturer
        self.model = asset.model
        self.thumbnailURL = asset.thumbnailURL
        self.submodelCount = asset.availableSubmodels.count
    }
}

// MARK: - Asset Filter

/// Filter criteria for asset searches.
public struct AssetFilter: Sendable {
    public var searchText: String?
    public var manufacturer: String?
    public var assetType: String?
    public var hasSubmodel: SubmodelType?
    public var serialNumber: String?

    public init(
        searchText: String? = nil,
        manufacturer: String? = nil,
        assetType: String? = nil,
        hasSubmodel: SubmodelType? = nil,
        serialNumber: String? = nil
    ) {
        self.searchText = searchText
        self.manufacturer = manufacturer
        self.assetType = assetType
        self.hasSubmodel = hasSubmodel
        self.serialNumber = serialNumber
    }

    /// Whether this filter is empty
    public var isEmpty: Bool {
        searchText?.isEmpty != false &&
        manufacturer == nil &&
        assetType == nil &&
        hasSubmodel == nil &&
        serialNumber == nil
    }

    /// Apply filter to an asset
    public func matches(_ asset: Asset) -> Bool {
        if let searchText = searchText, !searchText.isEmpty {
            let lowercased = searchText.lowercased()
            let matches = asset.name.lowercased().contains(lowercased) ||
                          asset.manufacturer?.lowercased().contains(lowercased) == true ||
                          asset.model?.lowercased().contains(lowercased) == true ||
                          asset.serialNumber?.lowercased().contains(lowercased) == true
            if !matches { return false }
        }

        if let manufacturer = manufacturer,
           asset.manufacturer?.lowercased() != manufacturer.lowercased() {
            return false
        }

        if let assetType = assetType,
           asset.assetType?.lowercased() != assetType.lowercased() {
            return false
        }

        if let hasSubmodel = hasSubmodel,
           !asset.availableSubmodels.contains(hasSubmodel) {
            return false
        }

        if let serialNumber = serialNumber,
           asset.serialNumber?.lowercased() != serialNumber.lowercased() {
            return false
        }

        return true
    }
}

// MARK: - Asset Sort

/// Sort options for asset lists.
public enum AssetSort: String, CaseIterable, Sendable {
    case nameAscending
    case nameDescending
    case manufacturerAscending
    case manufacturerDescending
    case recentlyViewed

    public var displayName: String {
        switch self {
        case .nameAscending: return "Name (A-Z)"
        case .nameDescending: return "Name (Z-A)"
        case .manufacturerAscending: return "Manufacturer (A-Z)"
        case .manufacturerDescending: return "Manufacturer (Z-A)"
        case .recentlyViewed: return "Recently Viewed"
        }
    }

    /// Compare two assets using this sort
    public func compare(_ a: Asset, _ b: Asset) -> Bool {
        switch self {
        case .nameAscending:
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        case .nameDescending:
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedDescending
        case .manufacturerAscending:
            return (a.manufacturer ?? "").localizedCaseInsensitiveCompare(b.manufacturer ?? "") == .orderedAscending
        case .manufacturerDescending:
            return (a.manufacturer ?? "").localizedCaseInsensitiveCompare(b.manufacturer ?? "") == .orderedDescending
        case .recentlyViewed:
            // This would need external state to track view history
            return true
        }
    }
}

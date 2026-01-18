//
//  CarbonFootprint.swift
//  TwinAct Field Companion
//
//  Carbon Footprint domain model per IDTA 02023.
//  Sustainability/DPP (Digital Product Passport) data.
//  READ ONLY - This submodel cannot be modified by the app.
//

import Foundation

// MARK: - Carbon Footprint

/// Carbon Footprint per IDTA 02023
/// Used for Digital Product Passport (DPP) sustainability display.
/// This is a read-only submodel.
public struct CarbonFootprint: Codable, Sendable, Hashable {

    // MARK: - Product Carbon Footprint (PCF)

    /// Total PCF in kg CO2 equivalent (cradle-to-gate)
    public let pcfCO2eq: Double?

    /// Reference unit for PCF calculation (e.g., "1 piece", "1 kg")
    public let pcfReferenceUnitForCalculation: String?

    /// Method used for PCF calculation (e.g., "GHG Protocol", "ISO 14067")
    public let pcfCalculationMethod: String?

    /// Life cycle phases included in PCF calculation
    public let pcfLifeCyclePhase: [LifeCyclePhase]?

    /// Geographical region for PCF calculation
    public let pcfGeographicalRegion: String?

    /// Date of PCF calculation
    public let pcfCalculationDate: Date?

    // MARK: - Transport Carbon Footprint (TCF)

    /// Transport carbon footprint in kg CO2 equivalent
    public let tcfCO2eq: Double?

    /// Method used for TCF calculation
    public let tcfCalculationMethod: String?

    /// Transport distance in kilometers
    public let tcfTransportDistance: Double?

    /// Mode of transport
    public let tcfTransportMode: TransportMode?

    // MARK: - Use Phase Carbon Footprint (UCF)

    /// Use phase carbon footprint in kg CO2 equivalent
    public let ucfCO2eq: Double?

    /// Expected lifetime in years
    public let ucfExpectedLifetime: Double?

    /// Expected energy consumption in kWh/year
    public let ucfExpectedEnergyConsumption: Double?

    /// Energy source carbon intensity (kg CO2/kWh)
    public let ucfEnergyCarbonIntensity: Double?

    // MARK: - End of Life Carbon Footprint (EOLCF)

    /// End of life carbon footprint in kg CO2 equivalent
    public let eolCO2eq: Double?

    /// Recyclability percentage
    public let recyclabilityPercentage: Double?

    /// Recycled content percentage
    public let recycledContentPercentage: Double?

    // MARK: - Total and Verification

    /// Total carbon footprint across all phases
    public var totalCO2eq: Double? {
        let values = [pcfCO2eq, tcfCO2eq, ucfCO2eq, eolCO2eq].compactMap { $0 }
        return values.isEmpty ? nil : values.reduce(0, +)
    }

    /// URL to verification statement/certificate
    public let verificationStatement: URL?

    /// Start of validity period
    public let validityPeriodStart: Date?

    /// End of validity period
    public let validityPeriodEnd: Date?

    /// Third-party verifier name
    public let verifierName: String?

    /// Verification standard used
    public let verificationStandard: String?

    // MARK: - Additional Sustainability Metrics

    /// Water footprint in liters
    public let waterFootprint: Double?

    /// Energy efficiency class (A-G)
    public let energyEfficiencyClass: String?

    /// Circular economy score (0-100)
    public let circularEconomyScore: Double?

    // MARK: - Initialization

    public init(
        pcfCO2eq: Double? = nil,
        pcfReferenceUnitForCalculation: String? = nil,
        pcfCalculationMethod: String? = nil,
        pcfLifeCyclePhase: [LifeCyclePhase]? = nil,
        pcfGeographicalRegion: String? = nil,
        pcfCalculationDate: Date? = nil,
        tcfCO2eq: Double? = nil,
        tcfCalculationMethod: String? = nil,
        tcfTransportDistance: Double? = nil,
        tcfTransportMode: TransportMode? = nil,
        ucfCO2eq: Double? = nil,
        ucfExpectedLifetime: Double? = nil,
        ucfExpectedEnergyConsumption: Double? = nil,
        ucfEnergyCarbonIntensity: Double? = nil,
        eolCO2eq: Double? = nil,
        recyclabilityPercentage: Double? = nil,
        recycledContentPercentage: Double? = nil,
        verificationStatement: URL? = nil,
        validityPeriodStart: Date? = nil,
        validityPeriodEnd: Date? = nil,
        verifierName: String? = nil,
        verificationStandard: String? = nil,
        waterFootprint: Double? = nil,
        energyEfficiencyClass: String? = nil,
        circularEconomyScore: Double? = nil
    ) {
        self.pcfCO2eq = pcfCO2eq
        self.pcfReferenceUnitForCalculation = pcfReferenceUnitForCalculation
        self.pcfCalculationMethod = pcfCalculationMethod
        self.pcfLifeCyclePhase = pcfLifeCyclePhase
        self.pcfGeographicalRegion = pcfGeographicalRegion
        self.pcfCalculationDate = pcfCalculationDate
        self.tcfCO2eq = tcfCO2eq
        self.tcfCalculationMethod = tcfCalculationMethod
        self.tcfTransportDistance = tcfTransportDistance
        self.tcfTransportMode = tcfTransportMode
        self.ucfCO2eq = ucfCO2eq
        self.ucfExpectedLifetime = ucfExpectedLifetime
        self.ucfExpectedEnergyConsumption = ucfExpectedEnergyConsumption
        self.ucfEnergyCarbonIntensity = ucfEnergyCarbonIntensity
        self.eolCO2eq = eolCO2eq
        self.recyclabilityPercentage = recyclabilityPercentage
        self.recycledContentPercentage = recycledContentPercentage
        self.verificationStatement = verificationStatement
        self.validityPeriodStart = validityPeriodStart
        self.validityPeriodEnd = validityPeriodEnd
        self.verifierName = verifierName
        self.verificationStandard = verificationStandard
        self.waterFootprint = waterFootprint
        self.energyEfficiencyClass = energyEfficiencyClass
        self.circularEconomyScore = circularEconomyScore
    }

    // MARK: - Computed Properties

    /// Whether the carbon footprint data is currently valid
    public var isValid: Bool {
        guard let end = validityPeriodEnd else { return true }
        return Date() <= end
    }

    /// Whether the data has been verified by a third party
    public var isVerified: Bool {
        verificationStatement != nil || verifierName != nil
    }

    /// Formatted total CO2 string (e.g., "125.5 kg CO2eq")
    public var formattedTotalCO2: String? {
        guard let total = totalCO2eq else { return nil }
        return formatCO2(total)
    }

    /// Formatted PCF CO2 string
    public var formattedPCF: String? {
        guard let pcf = pcfCO2eq else { return nil }
        return formatCO2(pcf)
    }

    private func formatCO2(_ value: Double) -> String {
        if value >= 1000 {
            return String(format: "%.2f t CO2eq", value / 1000)
        } else {
            return String(format: "%.1f kg CO2eq", value)
        }
    }

    /// Carbon footprint breakdown by phase
    public var breakdown: [(phase: String, value: Double, percentage: Double)] {
        guard let total = totalCO2eq, total > 0 else { return [] }

        var result: [(String, Double, Double)] = []

        if let pcf = pcfCO2eq {
            result.append(("Production", pcf, (pcf / total) * 100))
        }
        if let tcf = tcfCO2eq {
            result.append(("Transport", tcf, (tcf / total) * 100))
        }
        if let ucf = ucfCO2eq {
            result.append(("Use Phase", ucf, (ucf / total) * 100))
        }
        if let eol = eolCO2eq {
            result.append(("End of Life", eol, (eol / total) * 100))
        }

        return result
    }
}

// MARK: - Life Cycle Phase

/// Life cycle phases per ISO 14040/14044 and EN 15804.
public enum LifeCyclePhase: String, Codable, Sendable, CaseIterable {
    /// A1: Raw material supply
    case rawMaterialAcquisition = "A1"

    /// A2: Transport to manufacturer
    case transportToManufacturer = "A2"

    /// A3: Manufacturing
    case manufacturing = "A3"

    /// A1-A3: Product stage (cradle-to-gate)
    case productStage = "A1-A3"

    /// A4: Transport to building site
    case transportToSite = "A4"

    /// A5: Installation
    case installation = "A5"

    /// B1-B7: Use stage
    case usePhase = "B"

    /// B1: Use
    case use = "B1"

    /// B2: Maintenance
    case maintenance = "B2"

    /// B3: Repair
    case repair = "B3"

    /// B4: Replacement
    case replacement = "B4"

    /// B5: Refurbishment
    case refurbishment = "B5"

    /// B6: Operational energy use
    case operationalEnergy = "B6"

    /// B7: Operational water use
    case operationalWater = "B7"

    /// C1-C4: End of life stage
    case endOfLife = "C"

    /// C1: Deconstruction/demolition
    case deconstruction = "C1"

    /// C2: Transport to waste processing
    case transportToWaste = "C2"

    /// C3: Waste processing
    case wasteProcessing = "C3"

    /// C4: Disposal
    case disposal = "C4"

    /// D: Benefits and loads beyond system boundary
    case benefits = "D"

    /// Human-readable display name
    public var displayName: String {
        switch self {
        case .rawMaterialAcquisition: return "Raw Material Supply"
        case .transportToManufacturer: return "Transport to Manufacturer"
        case .manufacturing: return "Manufacturing"
        case .productStage: return "Product Stage (A1-A3)"
        case .transportToSite: return "Transport to Site"
        case .installation: return "Installation"
        case .usePhase: return "Use Phase"
        case .use: return "Use"
        case .maintenance: return "Maintenance"
        case .repair: return "Repair"
        case .replacement: return "Replacement"
        case .refurbishment: return "Refurbishment"
        case .operationalEnergy: return "Operational Energy"
        case .operationalWater: return "Operational Water"
        case .endOfLife: return "End of Life"
        case .deconstruction: return "Deconstruction"
        case .transportToWaste: return "Transport to Waste"
        case .wasteProcessing: return "Waste Processing"
        case .disposal: return "Disposal"
        case .benefits: return "Benefits Beyond System"
        }
    }
}

// MARK: - Transport Mode

/// Mode of transport for carbon footprint calculation.
public enum TransportMode: String, Codable, Sendable, CaseIterable {
    case road
    case rail
    case sea
    case air
    case pipeline
    case multimodal

    /// Human-readable display name
    public var displayName: String {
        switch self {
        case .road: return "Road"
        case .rail: return "Rail"
        case .sea: return "Sea"
        case .air: return "Air"
        case .pipeline: return "Pipeline"
        case .multimodal: return "Multimodal"
        }
    }

    /// SF Symbol icon name
    public var iconName: String {
        switch self {
        case .road: return "truck.box.fill"
        case .rail: return "train.side.front.car"
        case .sea: return "ferry.fill"
        case .air: return "airplane"
        case .pipeline: return "arrow.left.arrow.right"
        case .multimodal: return "shippingbox.fill"
        }
    }

    /// Typical carbon intensity (kg CO2/t-km) for reference
    public var typicalCarbonIntensity: Double {
        switch self {
        case .road: return 0.062
        case .rail: return 0.022
        case .sea: return 0.016
        case .air: return 0.602
        case .pipeline: return 0.025
        case .multimodal: return 0.040
        }
    }
}

// MARK: - IDTA Semantic IDs

extension CarbonFootprint {
    /// IDTA semantic ID for Carbon Footprint submodel
    public static let semanticId = "https://admin-shell.io/idta/CarbonFootprint/ProductCarbonFootprint/0/9"

    /// Alternative semantic ID for general sustainability submodel
    public static let sustainabilitySemanticId = "https://admin-shell.io/idta/Sustainability/1/0/Submodel"
}

// MARK: - Sustainability Rating

/// Utility for rating sustainability based on carbon footprint.
public enum SustainabilityRating: String, CaseIterable {
    case excellent = "A+"
    case veryGood = "A"
    case good = "B"
    case average = "C"
    case belowAverage = "D"
    case poor = "E"
    case veryPoor = "F"

    /// Create rating from CO2 value and product category benchmark
    public static func rating(
        for co2Value: Double,
        benchmark: Double
    ) -> SustainabilityRating {
        let ratio = co2Value / benchmark

        switch ratio {
        case ..<0.5: return .excellent
        case 0.5..<0.75: return .veryGood
        case 0.75..<1.0: return .good
        case 1.0..<1.25: return .average
        case 1.25..<1.5: return .belowAverage
        case 1.5..<2.0: return .poor
        default: return .veryPoor
        }
    }

    /// Color name for display
    public var colorName: String {
        switch self {
        case .excellent, .veryGood: return "green"
        case .good: return "mint"
        case .average: return "yellow"
        case .belowAverage: return "orange"
        case .poor, .veryPoor: return "red"
        }
    }
}

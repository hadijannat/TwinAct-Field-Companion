//
//  DemoData.swift
//  TwinAct Field Companion
//
//  Demo assets and data used for App Review safe mode.
//  This file provides static access to demo data that can be used
//  directly or loaded from bundled JSON files via DemoDataProvider.
//

import Foundation

// MARK: - Demo Data Container

/// Container for static demo data used throughout the app.
/// For dynamic loading from JSON files, use DemoDataProvider.shared instead.
enum DemoData {

    // MARK: - Asset Identifiers

    /// Demo asset AAS ID
    static let assetId = "urn:demo:aas:smartpump001"

    /// Demo asset serial number
    static let serialNumber = "SP500-2025-0042"

    /// Demo asset global asset ID
    static let globalAssetId = "urn:demo:asset:pump:serial:SP500-2025-0042"

    // MARK: - Static Demo Data

    /// Demo digital nameplate - matches demo-nameplate.json
    static let nameplate = DigitalNameplate(
        manufacturerName: "PumpTech Industrial Solutions GmbH",
        manufacturerProductDesignation: "Smart Industrial Pump SP-500",
        manufacturerProductFamily: "Industrial Centrifugal Pumps",
        manufacturerProductType: "SP-500",
        orderCode: "SP500-IND-2025-EU",
        serialNumber: serialNumber,
        batchNumber: "BATCH-2025-Q1-042",
        productionDate: ISO8601DateFormatter().date(from: "2025-01-15T08:30:00Z"),
        countryOfOrigin: "DE",
        yearOfConstruction: 2025,
        hardwareVersion: "HW-3.2",
        firmwareVersion: "FW-5.1.0",
        softwareVersion: "SW-2.8.3",
        manufacturerAddress: Address(
            street: "Industriestrasse 42",
            zipCode: "70469",
            city: "Stuttgart",
            stateCounty: "Baden-Wuerttemberg",
            country: "Germany",
            phone: "+49 711 123 4567",
            email: "support@pumptech-industrial.example"
        ),
        manufacturerLogo: URL(string: "https://images.unsplash.com/photo-1560179707-f14e90ef3623?w=200"),
        productImage: URL(string: "https://images.unsplash.com/photo-1581092160562-40aa08e78837?w=400"),
        markings: [
            Marking(name: "CE", additionalText: "Conformite Europeenne - meets EU safety standards"),
            Marking(name: "ATEX", additionalText: "Zone 2 rated for hazardous environments"),
            Marking(name: "ISO 9001", additionalText: "Quality Management System certified"),
            Marking(name: "ISO 14001", additionalText: "Environmental Management System certified")
        ]
    )

    /// Demo asset model - uses nameplate data
    static let asset = Asset(
        id: assetId,
        name: nameplate.manufacturerProductDesignation ?? "Smart Industrial Pump SP-500",
        assetType: "Instance",
        manufacturer: nameplate.manufacturerName,
        serialNumber: nameplate.serialNumber,
        model: nameplate.manufacturerProductType,
        thumbnailURL: nameplate.productImage,
        aasDescriptor: nil,
        availableSubmodels: [
            .digitalNameplate,
            .handoverDocumentation,
            .maintenanceInstructions,
            .serviceRequest,
            .timeSeriesData,
            .carbonFootprint,
            .technicalData
        ]
    )

    /// Demo carbon footprint - matches demo-carbon-footprint.json
    static let carbonFootprint = CarbonFootprint(
        pcfCO2eq: 285.5,
        pcfReferenceUnitForCalculation: "1 pump unit",
        pcfCalculationMethod: "ISO 14067:2018",
        pcfLifeCyclePhase: [.productStage, .transportToSite],
        pcfGeographicalRegion: "EU-27",
        pcfCalculationDate: ISO8601DateFormatter().date(from: "2024-11-15T00:00:00Z"),
        tcfCO2eq: 18.7,
        tcfCalculationMethod: "EN 16258",
        tcfTransportDistance: 850.0,
        tcfTransportMode: .road,
        ucfCO2eq: 1250.0,
        ucfExpectedLifetime: 15.0,
        ucfExpectedEnergyConsumption: 4380.0,
        ucfEnergyCarbonIntensity: 0.019,
        eolCO2eq: -45.2,
        recyclabilityPercentage: 92,
        recycledContentPercentage: 35,
        verificationStatement: URL(string: "https://example.com/verify/pcf/SP500-2025-0042"),
        validityPeriodStart: ISO8601DateFormatter().date(from: "2025-01-01T00:00:00Z"),
        validityPeriodEnd: ISO8601DateFormatter().date(from: "2027-12-31T23:59:59Z"),
        verifierName: "TUV Rheinland",
        verificationStandard: "ISO 14064-3:2019",
        waterFootprint: 2850,
        energyEfficiencyClass: "A+",
        circularEconomyScore: 78.5
    )

    /// Demo documents - matches demo-documentation.json
    static let documents: [Document] = [
        Document(
            id: "DOC-SP500-OM-001",
            title: [ls("SP-500 Operating Manual")],
            summary: [ls("Complete operating manual including installation, startup, operation, and shutdown procedures for the SP-500 Smart Industrial Pump.")],
            documentClass: .operatingManual,
            documentVersion: "3.2",
            language: ["en", "de"],
            digitalFile: [DigitalFile(
                fileFormat: "application/pdf",
                file: URL(string: "https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf")!,
                fileSize: 2_450_000,
                fileName: "SP500-Operating-Manual-v3.2.pdf"
            )],
            keywords: [ls("operation"), ls("startup"), ls("installation"), ls("commissioning")],
            documentDate: ISO8601DateFormatter().date(from: "2024-06-15T00:00:00Z"),
            organization: "PumpTech Industrial Solutions GmbH"
        ),
        Document(
            id: "DOC-SP500-SI-001",
            title: [ls("Safety Instructions and Hazard Information")],
            summary: [ls("Critical safety information, hazard warnings, PPE requirements, and emergency procedures for SP-500 pump operation and maintenance.")],
            documentClass: .safetyInstructions,
            documentVersion: "2.1",
            language: ["en", "de"],
            digitalFile: [DigitalFile(
                fileFormat: "application/pdf",
                file: URL(string: "https://www.orimi.com/pdf-test.pdf")!,
                fileSize: 1_850_000,
                fileName: "SP500-Safety-Instructions-v2.1.pdf"
            )],
            keywords: [ls("safety"), ls("hazard"), ls("PPE"), ls("emergency")],
            documentDate: ISO8601DateFormatter().date(from: "2024-08-01T00:00:00Z"),
            organization: "PumpTech Industrial Solutions GmbH"
        ),
        Document(
            id: "DOC-SP500-MM-001",
            title: [ls("Maintenance and Service Manual")],
            summary: [ls("Comprehensive maintenance manual with preventive maintenance schedules, troubleshooting guides, and spare parts information for SP-500.")],
            documentClass: .maintenanceInstructions,
            documentVersion: "3.0",
            language: ["en", "de"],
            digitalFile: [DigitalFile(
                fileFormat: "application/pdf",
                file: URL(string: "https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf")!,
                fileSize: 5_200_000,
                fileName: "SP500-Maintenance-Manual-v3.0.pdf"
            )],
            keywords: [ls("maintenance"), ls("service"), ls("spare parts"), ls("troubleshooting")],
            documentDate: ISO8601DateFormatter().date(from: "2024-09-20T00:00:00Z"),
            organization: "PumpTech Industrial Solutions GmbH"
        )
    ]

    /// Demo technical data summary
    static let technicalSummary = TechnicalDataSummary(
        submodelId: "urn:demo:submodel:technicaldata:smartpump001",
        idShort: "TechnicalData",
        properties: [
            TechnicalProperty(name: "Max Pressure", path: "MaxPressure", value: "16", unit: "bar"),
            TechnicalProperty(name: "Max Flow Rate", path: "MaxFlowRate", value: "150", unit: "m3/h"),
            TechnicalProperty(name: "Rated Power", path: "RatedPower", value: "22", unit: "kW"),
            TechnicalProperty(name: "Rated Speed", path: "RatedSpeed", value: "2950", unit: "rpm"),
            TechnicalProperty(name: "Weight", path: "Weight", value: "85", unit: "kg"),
            TechnicalProperty(name: "Noise Level", path: "NoiseLevel", value: "72", unit: "dB(A)"),
            TechnicalProperty(name: "Operating Temperature", path: "OperatingTemperature", value: "-10 to +60", unit: "C"),
            TechnicalProperty(name: "Protection Class", path: "ProtectionClass", value: "IP55", unit: nil)
        ]
    )

    /// Demo handover documentation
    static let handoverDocumentation = HandoverDocumentation(documents: documents)

    // MARK: - Service Requests

    /// Sample service request statuses for demo
    static var serviceRequests: [ServiceRequest] {
        // Try to load from DemoDataProvider, fall back to empty array
        (try? DemoDataProvider.shared.loadServiceRequests()) ?? []
    }

    // MARK: - Helpers

    /// Creates a LangString with English text
    private static func ls(_ text: String) -> LangString {
        LangString(language: "en", text: text)
    }
}

// MARK: - Demo Data Extensions

extension DemoData {

    /// Check if demo data is available
    static var isAvailable: Bool {
        // Verify at least the nameplate can be loaded from JSON
        do {
            _ = try DemoDataProvider.shared.loadDigitalNameplate()
            return true
        } catch {
            return false
        }
    }

    /// Preload all demo data for faster access
    static func preloadAllData() {
        DemoDataProvider.shared.preloadAllData()
    }
}

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
    static let assetId = "urn:hydraflow:aas:cre95-3-2-96516050"

    /// Demo asset serial number
    static let serialNumber = "P25A-96516050-0042"

    /// Demo asset global asset ID
    static let globalAssetId = "urn:hydraflow:asset:pump:serial:P25A-96516050-0042"

    // MARK: - Static Demo Data

    /// Demo digital nameplate - matches demo-nameplate.json
    static let nameplate = DigitalNameplate(
        manufacturerName: "HydraFlow Precision Systems AG",
        manufacturerProductDesignation: "CRE 95-3-2 A-F-A-E-HQQE Multi-Stage Inline Centrifugal Pump",
        manufacturerProductFamily: "CRE Series - High-Pressure Vertical Inline Pumps",
        manufacturerProductType: "CRE 95-3-2",
        orderCode: "CRE95-3-2-A-F-A-E-HQQE-96516050",
        serialNumber: serialNumber,
        batchNumber: "LOT-2025-CRE95-W03",
        productionDate: ISO8601DateFormatter().date(from: "2025-01-15T08:30:00Z"),
        countryOfOrigin: "DK",
        yearOfConstruction: 2025,
        hardwareVersion: "HW-4.2.1",
        firmwareVersion: "FW-7.3.2-MGE",
        softwareVersion: "SW-3.1.0-SMART",
        manufacturerAddress: Address(
            street: "Poul Due Jensens Vej 7",
            zipCode: "8850",
            city: "Bjerringbro",
            stateCounty: "Central Jutland",
            country: "Denmark",
            phone: "+45 87 50 14 00",
            email: "techsupport@hydraflow-precision.example"
        ),
        manufacturerLogo: URL(string: "https://images.unsplash.com/photo-1486406146926-c627a92ad1ab?w=200"),
        productImage: URL(string: "https://images.unsplash.com/photo-1504328345606-18bbc8c9d7d1?w=400"),
        markings: [
            Marking(name: "CE", additionalText: "Conformité Européenne - EU Machinery Directive 2006/42/EC"),
            Marking(name: "ATEX", additionalText: "II 2G Ex eb IIC T4 Gb - Zone 1/2 Gas Environments"),
            Marking(name: "IECEx", additionalText: "IEC 60079-7:2015 - Explosive Atmospheres"),
            Marking(name: "UL Listed", additionalText: "UL 778 / CSA C22.2 No. 108 - Motor-Operated Water Pumps"),
            Marking(name: "ISO 9001:2015", additionalText: "Quality Management System - Design & Manufacturing"),
            Marking(name: "ISO 14001:2015", additionalText: "Environmental Management System"),
            Marking(name: "WRAS", additionalText: "BS 6920-1:2014 - UK Drinking Water Approval"),
            Marking(name: "NSF/ANSI 61", additionalText: "Drinking Water System Components - Health Effects"),
            Marking(name: "ErP Compliant", additionalText: "EU 547/2012 - Energy-related Products Directive")
        ]
    )

    /// Demo asset model - uses nameplate data
    static let asset = Asset(
        id: globalAssetId,
        aasId: assetId,
        globalAssetId: globalAssetId,
        name: nameplate.manufacturerProductDesignation ?? "CRE 95-3-2 Multi-Stage Inline Pump",
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
        pcfReferenceUnitForCalculation: "1 pump unit (CRE 95-3-2)",
        pcfCalculationMethod: "ISO 14067:2018 / EN 15804:2012+A2:2019",
        pcfLifeCyclePhase: [.productStage, .transportToSite],
        pcfGeographicalRegion: "EU-27",
        pcfCalculationDate: ISO8601DateFormatter().date(from: "2024-11-15T00:00:00Z"),
        tcfCO2eq: 18.7,
        tcfCalculationMethod: "EN 16258:2012",
        tcfTransportDistance: 850.0,
        tcfTransportMode: .road,
        ucfCO2eq: 1250.0,
        ucfExpectedLifetime: 15.0,
        ucfExpectedEnergyConsumption: 4380.0,
        ucfEnergyCarbonIntensity: 0.019,
        eolCO2eq: -45.2,
        recyclabilityPercentage: 92,
        recycledContentPercentage: 35,
        verificationStatement: URL(string: "https://example.com/verify/pcf/CRE95-3-2-96516050"),
        validityPeriodStart: ISO8601DateFormatter().date(from: "2025-01-01T00:00:00Z"),
        validityPeriodEnd: ISO8601DateFormatter().date(from: "2027-12-31T23:59:59Z"),
        verifierName: "TÜV Rheinland",
        verificationStandard: "ISO 14064-3:2019",
        waterFootprint: 2850,
        energyEfficiencyClass: "A+",
        circularEconomyScore: 78.5
    )

    /// Demo documents - matches demo-documentation.json
    static let documents: [Document] = [
        Document(
            id: "DOC-CRE95-OM-001",
            title: [ls("CRE 95-3-2 Installation and Operating Instructions")],
            summary: [ls("Complete installation, commissioning, operation, and maintenance instructions for CRE 95-3-2 multi-stage inline pump per ISO/IEC 82079-1.")],
            documentClass: .operatingManual,
            documentVersion: "4.2",
            language: ["en", "de", "da"],
            digitalFile: [DigitalFile(
                fileFormat: "application/pdf",
                file: URL(string: "https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf")!,
                fileSize: 4_850_000,
                fileName: "CRE95-3-2-IO-Manual-v4.2.pdf"
            )],
            keywords: [ls("installation"), ls("commissioning"), ls("operation"), ls("VFD setup")],
            documentDate: ISO8601DateFormatter().date(from: "2024-06-15T00:00:00Z"),
            organization: "HydraFlow Precision Systems AG"
        ),
        Document(
            id: "DOC-CRE95-SI-001",
            title: [ls("Safety Instructions - ATEX Zone 1/2 Applications")],
            summary: [ls("Critical safety information for ATEX II 2G Ex eb IIC T4 Gb certified pump operation including hazard warnings, PPE requirements, and emergency procedures.")],
            documentClass: .safetyInstructions,
            documentVersion: "3.1",
            language: ["en", "de", "da"],
            digitalFile: [DigitalFile(
                fileFormat: "application/pdf",
                file: URL(string: "https://www.orimi.com/pdf-test.pdf")!,
                fileSize: 2_150_000,
                fileName: "CRE95-3-2-ATEX-Safety-v3.1.pdf"
            )],
            keywords: [ls("ATEX"), ls("safety"), ls("hazardous area"), ls("Ex protection")],
            documentDate: ISO8601DateFormatter().date(from: "2024-08-01T00:00:00Z"),
            organization: "HydraFlow Precision Systems AG"
        ),
        Document(
            id: "DOC-CRE95-MM-001",
            title: [ls("Service and Maintenance Manual - Mechanical Seal Replacement")],
            summary: [ls("Detailed maintenance procedures for HQQE mechanical seal replacement, bearing lubrication schedules, and vibration analysis guidelines per ISO 10816-7.")],
            documentClass: .maintenanceInstructions,
            documentVersion: "5.0",
            language: ["en", "de", "da"],
            digitalFile: [DigitalFile(
                fileFormat: "application/pdf",
                file: URL(string: "https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf")!,
                fileSize: 6_200_000,
                fileName: "CRE95-3-2-Service-Manual-v5.0.pdf"
            )],
            keywords: [ls("mechanical seal"), ls("HQQE"), ls("bearing"), ls("vibration analysis")],
            documentDate: ISO8601DateFormatter().date(from: "2024-09-20T00:00:00Z"),
            organization: "HydraFlow Precision Systems AG"
        )
    ]

    /// Demo technical data summary
    static let technicalSummary = TechnicalDataSummary(
        submodelId: "urn:hydraflow:submodel:technicaldata:cre95-3-2-96516050",
        idShort: "TechnicalData",
        properties: [
            TechnicalProperty(name: "Rated Flow (Qn)", path: "RatedFlow", value: "95", unit: "m³/h"),
            TechnicalProperty(name: "Rated Head (Hn)", path: "RatedHead", value: "125", unit: "m"),
            TechnicalProperty(name: "Rated Power (P2)", path: "RatedPower", value: "45", unit: "kW"),
            TechnicalProperty(name: "Rated Speed", path: "RatedSpeed", value: "2950", unit: "rpm"),
            TechnicalProperty(name: "Motor Efficiency", path: "MotorEfficiency", value: "95.8", unit: "%"),
            TechnicalProperty(name: "NPSH Required", path: "NPSHRequired", value: "4.2", unit: "m"),
            TechnicalProperty(name: "Max Working Pressure", path: "MaxWorkingPressure", value: "25", unit: "bar"),
            TechnicalProperty(name: "Fluid Temp Range", path: "FluidTemperature", value: "-30 to +120", unit: "°C"),
            TechnicalProperty(name: "IP Rating", path: "IPRating", value: "IP55", unit: nil),
            TechnicalProperty(name: "ATEX Classification", path: "ATEXClass", value: "II 2G Ex eb IIC T4 Gb", unit: nil),
            TechnicalProperty(name: "Dry Weight", path: "DryWeight", value: "187.5", unit: "kg"),
            TechnicalProperty(name: "Flange Standard", path: "FlangeStandard", value: "EN 1092-1 PN16/PN25", unit: nil)
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

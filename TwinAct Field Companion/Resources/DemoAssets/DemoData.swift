//
//  DemoData.swift
//  TwinAct Field Companion
//
//  Demo assets and data used for App Review safe mode.
//

import Foundation

enum DemoData {
    static let assetId = "urn:twinact:demo:aas:compressor-001"

    static let nameplate = DigitalNameplate(
        manufacturerName: "TwinAct Industries",
        manufacturerProductDesignation: "TwinAct Field Compressor X1",
        manufacturerProductFamily: "Field Compressor",
        manufacturerProductType: "X1",
        orderCode: "TC-X1-2026",
        serialNumber: "TCX1-2026-0007",
        batchNumber: "B-2026-01",
        productionDate: Date(timeIntervalSince1970: 1_735_689_600),
        countryOfOrigin: "DE",
        yearOfConstruction: 2026,
        hardwareVersion: "H1",
        firmwareVersion: "FW-2.3.1",
        softwareVersion: "SW-4.0.0",
        manufacturerAddress: Address(
            street: "42 Industrial Way",
            zipCode: "80331",
            city: "Munich",
            stateCounty: "Bavaria",
            country: "Germany",
            phone: "+49 89 1234 567",
            email: "support@twinact.example"
        ),
        manufacturerLogo: URL(string: "https://images.unsplash.com/photo-1489515217757-5fd1be406fef"),
        productImage: URL(string: "https://images.unsplash.com/photo-1489515217757-5fd1be406fef")
    )

    static let asset = Asset(
        id: assetId,
        name: nameplate.manufacturerProductDesignation ?? "TwinAct Demo Asset",
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

    static let carbonFootprint = CarbonFootprint(
        pcfCO2eq: 125.5,
        pcfReferenceUnitForCalculation: "1 unit",
        pcfCalculationMethod: "ISO 14067",
        tcfCO2eq: 15.2,
        ucfCO2eq: 280.0,
        eolCO2eq: 12.3,
        recyclabilityPercentage: 85,
        recycledContentPercentage: 30,
        verificationStatement: URL(string: "https://example.com/verify"),
        validityPeriodStart: Date(timeIntervalSince1970: 1_725_000_000),
        validityPeriodEnd: Date(timeIntervalSince1970: 1_757_000_000),
        verifierName: "TUV Rheinland",
        verificationStandard: "ISO 14067",
        waterFootprint: 450,
        energyEfficiencyClass: "A+",
        circularEconomyScore: 72
    )

    static let documents: [Document] = [
        Document(
            id: "demo-operating-manual",
            title: [ls("Operating Manual")],
            summary: [ls("Installation, operation, and safety overview for the demo compressor.")],
            documentClass: .operatingManual,
            documentVersion: "1.2",
            language: ["en"],
            digitalFile: [DigitalFile(
                fileFormat: "application/pdf",
                file: URL(string: "https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf")!,
                fileSize: 13_000,
                fileName: "TwinAct-Operating-Manual.pdf"
            )],
            keywords: [ls("safety"), ls("startup"), ls("maintenance")],
            documentDate: Date(timeIntervalSince1970: 1_725_000_000),
            organization: "TwinAct Industries"
        ),
        Document(
            id: "demo-maintenance-guide",
            title: [ls("Maintenance Guide")],
            summary: [ls("Scheduled service intervals and checklists for field technicians.")],
            documentClass: .maintenanceInstructions,
            documentVersion: "3.0",
            language: ["en"],
            digitalFile: [DigitalFile(
                fileFormat: "application/pdf",
                file: URL(string: "https://www.orimi.com/pdf-test.pdf")!,
                fileSize: 2_400_000,
                fileName: "TwinAct-Maintenance-Guide.pdf"
            )],
            keywords: [ls("preventive"), ls("service"), ls("checklist")],
            documentDate: Date(timeIntervalSince1970: 1_730_000_000),
            organization: "TwinAct Industries"
        )
    ]

    static let technicalSummary = TechnicalDataSummary(
        submodelId: "urn:twinact:demo:submodel:technical-data",
        idShort: "TechnicalData",
        properties: [
            TechnicalProperty(name: "Max Pressure", path: "MaxPressure", value: "12 bar", unit: "bar"),
            TechnicalProperty(name: "Flow Rate", path: "FlowRate", value: "110 L/min", unit: "L/min"),
            TechnicalProperty(name: "Noise Level", path: "NoiseLevel", value: "65 dB", unit: "dB"),
            TechnicalProperty(name: "Operating Temp", path: "OperatingTemperature", value: "-10 to 45 C", unit: "C")
        ]
    )

    static let handoverDocumentation = HandoverDocumentation(documents: documents)

    private static func ls(_ text: String) -> LangString {
        LangString(language: "en", text: text)
    }
}

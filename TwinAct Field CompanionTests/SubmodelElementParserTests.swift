//
//  SubmodelElementParserTests.swift
//  TwinAct Field CompanionTests
//
//  Unit tests for SubmodelElementParser - parsing SME types into domain models.
//

import XCTest
@testable import TwinAct_Field_Companion

final class SubmodelElementParserTests: XCTestCase {

    // MARK: - Digital Nameplate Tests

    func testParseDigitalNameplate() throws {
        let submodel = TestDataFactory.createNameplateSubmodel()
        let nameplate = try SubmodelElementParser.parseDigitalNameplate(from: submodel)

        XCTAssertEqual(nameplate.manufacturerName, "Test Manufacturer GmbH")
        XCTAssertEqual(nameplate.serialNumber, "SN-2025-001")
        XCTAssertEqual(nameplate.manufacturerProductDesignation, "Test Product X-500")
        XCTAssertEqual(nameplate.countryOfOrigin, "DE")
        XCTAssertNotNil(nameplate.productionDate)
    }

    func testParseEmptySubmodelAsNameplate() throws {
        let emptySubmodel = Submodel(id: "urn:test:empty", submodelElements: [])
        let nameplate = try SubmodelElementParser.parseDigitalNameplate(from: emptySubmodel)

        XCTAssertNil(nameplate.manufacturerName, "Empty submodel should have nil manufacturer name")
        XCTAssertNil(nameplate.serialNumber, "Empty submodel should have nil serial number")
    }

    func testParseNestedContactInformation() throws {
        let submodel = TestDataFactory.createNestedCollectionSubmodel()
        let nameplate = try SubmodelElementParser.parseDigitalNameplate(from: submodel)

        XCTAssertNotNil(nameplate.manufacturerAddress, "Should parse nested contact information")
        XCTAssertEqual(nameplate.manufacturerAddress?.city, "Stuttgart")
        XCTAssertEqual(nameplate.manufacturerAddress?.phone, "+49 711 123456")
    }

    // MARK: - Handover Documentation Tests

    func testParseHandoverDocumentation() throws {
        let submodel = TestDataFactory.createDocumentationSubmodel()
        let docs = try SubmodelElementParser.parseHandoverDocumentation(from: submodel)

        XCTAssertEqual(docs.documents.count, 2, "Should parse 2 documents")
        XCTAssertEqual(docs.documents[0].id, "DOC-001")
        XCTAssertEqual(docs.documents[0].documentClass, .operatingManual)
        XCTAssertNotNil(docs.documents[0].digitalFile)
    }

    // MARK: - Service Request Tests

    func testParseServiceRequest() throws {
        let submodel = TestDataFactory.createServiceRequestSubmodel()
        let request = try SubmodelElementParser.parseServiceRequest(from: submodel)

        XCTAssertEqual(request.title, "Test Service Request")
        XCTAssertEqual(request.status, .new)
        XCTAssertEqual(request.priority, .high)
        XCTAssertEqual(request.category, .maintenance)
        XCTAssertNotNil(request.requestDate)
    }

    func testParseServiceRequestMissingTitleThrows() {
        let invalidSubmodel = TestDataFactory.createSubmodelWithElements([
            .property(Property(idShort: "Description", valueType: .string, value: "Description only, no title"))
        ])

        XCTAssertThrowsError(try SubmodelElementParser.parseServiceRequest(from: invalidSubmodel)) { error in
            if case SubmodelParserError.missingRequiredElement = error {
                // Expected error type
            } else {
                XCTFail("Expected missingRequiredElement error, got \(error)")
            }
        }
    }

    // MARK: - Carbon Footprint Tests

    func testParseCarbonFootprint() throws {
        let submodel = TestDataFactory.createCarbonFootprintSubmodel()
        let footprint = try SubmodelElementParser.parseCarbonFootprint(from: submodel)

        XCTAssertEqual(footprint.pcfCO2eq, 250.5)
        XCTAssertEqual(footprint.pcfCalculationMethod, "ISO 14067:2018")
        XCTAssertEqual(footprint.recyclabilityPercentage, 85.0)
    }

    // MARK: - Time Series Tests

    func testParseTimeSeriesData() throws {
        let submodel = TestDataFactory.createTimeSeriesSubmodel()
        let timeSeries = try SubmodelElementParser.parseTimeSeriesData(from: submodel)

        XCTAssertGreaterThanOrEqual(timeSeries.records.count, 1, "Should have at least 1 time series record")
        XCTAssertEqual(timeSeries.metadata.name, "SensorReadings")
    }

    // MARK: - Maintenance Instructions Tests

    func testParseMaintenanceInstructions() throws {
        let submodel = TestDataFactory.createMaintenanceSubmodel()
        let maintenance = try SubmodelElementParser.parseMaintenanceInstructions(from: submodel)

        XCTAssertEqual(maintenance.instructions.count, 1)
        XCTAssertEqual(maintenance.instructions[0].maintenanceType, .preventive)
        XCTAssertNotNil(maintenance.instructions[0].steps)
    }

    func testParseMultiLanguageProperty() throws {
        let submodel = TestDataFactory.createMultiLanguageSubmodel()
        let maintenance = try SubmodelElementParser.parseMaintenanceInstructions(from: submodel)

        XCTAssertEqual(maintenance.instructions.count, 1)
        XCTAssertFalse(maintenance.instructions[0].title.isEmpty)

        let englishTitle = maintenance.instructions[0].title.first { $0.language == "en" }?.text
        XCTAssertEqual(englishTitle, "Filter Replacement", "Should extract English title from MLP")
    }

    // MARK: - Date Parsing Tests

    func testDateParsingISO8601WithTimezone() throws {
        let submodel = TestDataFactory.createSubmodelWithElements([
            .property(Property(idShort: "DateOfManufacture", valueType: .string, value: "2025-01-15T08:30:00Z"))
        ])
        let nameplate = try SubmodelElementParser.parseDigitalNameplate(from: submodel)
        XCTAssertNotNil(nameplate.productionDate, "Should parse ISO 8601 with timezone")
    }

    func testDateParsingDateOnly() throws {
        let submodel = TestDataFactory.createSubmodelWithElements([
            .property(Property(idShort: "DateOfManufacture", valueType: .string, value: "2025-01-15"))
        ])
        let nameplate = try SubmodelElementParser.parseDigitalNameplate(from: submodel)
        XCTAssertNotNil(nameplate.productionDate, "Should parse date-only format")
    }

    func testDateParsingGermanFormat() throws {
        let submodel = TestDataFactory.createSubmodelWithElements([
            .property(Property(idShort: "DateOfManufacture", valueType: .string, value: "15.01.2025"))
        ])
        let nameplate = try SubmodelElementParser.parseDigitalNameplate(from: submodel)
        XCTAssertNotNil(nameplate.productionDate, "Should parse German date format")
    }

    func testDateParsingInvalidFormat() throws {
        let submodel = TestDataFactory.createSubmodelWithElements([
            .property(Property(idShort: "DateOfManufacture", valueType: .string, value: "invalid-date"))
        ])
        let nameplate = try SubmodelElementParser.parseDigitalNameplate(from: submodel)
        XCTAssertNil(nameplate.productionDate, "Should NOT parse invalid date format")
    }

    // MARK: - JSON Round-Trip Tests

    func testSubmodelElementJSONRoundTrip() throws {
        let testProperty = Property(
            idShort: "TestProperty",
            valueType: .string,
            value: "test value"
        )
        let element: SubmodelElement = .property(testProperty)

        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys

        let encoded = try encoder.encode(element)
        let decoded = try JSONDecoder().decode(SubmodelElement.self, from: encoded)

        XCTAssertEqual(decoded.idShort, "TestProperty")

        if case .property(let prop) = decoded {
            XCTAssertEqual(prop.value, "test value")
        } else {
            XCTFail("Decoded element should be property type")
        }
    }
}

// MARK: - Test Data Factory

private enum TestDataFactory {

    static func createSubmodelWithElements(_ elements: [SubmodelElement]) -> Submodel {
        Submodel(
            id: "urn:test:submodel",
            idShort: "TestSubmodel",
            submodelElements: elements
        )
    }

    static func createNameplateSubmodel() -> Submodel {
        createSubmodelWithElements([
            .property(Property(idShort: "ManufacturerName", valueType: .string, value: "Test Manufacturer GmbH")),
            .property(Property(idShort: "ManufacturerProductDesignation", valueType: .string, value: "Test Product X-500")),
            .property(Property(idShort: "SerialNumber", valueType: .string, value: "SN-2025-001")),
            .property(Property(idShort: "CountryOfOrigin", valueType: .string, value: "DE")),
            .property(Property(idShort: "DateOfManufacture", valueType: .string, value: "2025-01-15T08:30:00Z")),
            .property(Property(idShort: "YearOfConstruction", valueType: .integer, value: "2025"))
        ])
    }

    static func createDocumentationSubmodel() -> Submodel {
        createSubmodelWithElements([
            .submodelElementCollection(SubmodelElementCollection(
                idShort: "DOC-001",
                value: [
                    .multiLanguageProperty(MultiLanguageProperty(idShort: "DocumentTitle", value: [LangString(language: "en", text: "Operating Manual")])),
                    .property(Property(idShort: "DocumentClassId", valueType: .string, value: "02-01")),
                    .property(Property(idShort: "DocumentVersion", valueType: .string, value: "1.0")),
                    .file(AASFile(idShort: "DigitalFile", contentType: "application/pdf", value: "https://example.com/manual.pdf"))
                ]
            )),
            .submodelElementCollection(SubmodelElementCollection(
                idShort: "DOC-002",
                value: [
                    .multiLanguageProperty(MultiLanguageProperty(idShort: "DocumentTitle", value: [LangString(language: "en", text: "Safety Instructions")])),
                    .property(Property(idShort: "DocumentClassId", valueType: .string, value: "02-02")),
                    .property(Property(idShort: "DocumentVersion", valueType: .string, value: "2.0"))
                ]
            ))
        ])
    }

    static func createServiceRequestSubmodel() -> Submodel {
        createSubmodelWithElements([
            .property(Property(idShort: "Title", valueType: .string, value: "Test Service Request")),
            .property(Property(idShort: "Description", valueType: .string, value: "This is a test service request")),
            .property(Property(idShort: "Status", valueType: .string, value: "New")),
            .property(Property(idShort: "Priority", valueType: .string, value: "High")),
            .property(Property(idShort: "Category", valueType: .string, value: "Maintenance")),
            .property(Property(idShort: "RequestDate", valueType: .string, value: "2025-01-18T10:00:00Z"))
        ])
    }

    static func createCarbonFootprintSubmodel() -> Submodel {
        createSubmodelWithElements([
            .property(Property(idShort: "PCFCO2eq", valueType: .double, value: "250.5")),
            .property(Property(idShort: "PCFCalculationMethod", valueType: .string, value: "ISO 14067:2018")),
            .property(Property(idShort: "PCFReferenceUnitForCalculation", valueType: .string, value: "1 unit")),
            .property(Property(idShort: "RecyclabilityPercentage", valueType: .double, value: "85.0")),
            .property(Property(idShort: "RecycledContentPercentage", valueType: .double, value: "30.0"))
        ])
    }

    static func createTimeSeriesSubmodel() -> Submodel {
        Submodel(
            id: "urn:test:timeseries",
            idShort: "SensorReadings",
            submodelElements: [
                .property(Property(idShort: "Unit", valueType: .string, value: "Celsius")),
                .property(Property(idShort: "SamplingInterval", valueType: .double, value: "60.0")),
                .submodelElementCollection(SubmodelElementCollection(
                    idShort: "Records",
                    value: [
                        .submodelElementCollection(SubmodelElementCollection(
                            idShort: "Record1",
                            value: [
                                .property(Property(idShort: "Timestamp", valueType: .string, value: "2025-01-18T10:00:00Z")),
                                .property(Property(idShort: "Temperature", valueType: .double, value: "25.5")),
                                .property(Property(idShort: "Pressure", valueType: .double, value: "1013.25"))
                            ]
                        ))
                    ]
                ))
            ]
        )
    }

    static func createMaintenanceSubmodel() -> Submodel {
        createSubmodelWithElements([
            .submodelElementCollection(SubmodelElementCollection(
                idShort: "Instruction001",
                value: [
                    .multiLanguageProperty(MultiLanguageProperty(idShort: "Title", value: [LangString(language: "en", text: "Oil Change")])),
                    .property(Property(idShort: "MaintenanceType", valueType: .string, value: "preventive")),
                    .property(Property(idShort: "IntervalValue", valueType: .double, value: "500.0")),
                    .property(Property(idShort: "IntervalUnit", valueType: .string, value: "hours")),
                    .submodelElementCollection(SubmodelElementCollection(
                        idShort: "Steps",
                        value: [
                            .submodelElementCollection(SubmodelElementCollection(
                                idShort: "Step1",
                                value: [
                                    .property(Property(idShort: "StepNumber", valueType: .integer, value: "1")),
                                    .multiLanguageProperty(MultiLanguageProperty(idShort: "Description", value: [LangString(language: "en", text: "Drain old oil")]))
                                ]
                            ))
                        ]
                    ))
                ]
            ))
        ])
    }

    static func createNestedCollectionSubmodel() -> Submodel {
        createSubmodelWithElements([
            .property(Property(idShort: "ManufacturerName", valueType: .string, value: "Nested Test GmbH")),
            .submodelElementCollection(SubmodelElementCollection(
                idShort: "ContactInformation",
                value: [
                    .property(Property(idShort: "CityTown", valueType: .string, value: "Stuttgart")),
                    .property(Property(idShort: "Street", valueType: .string, value: "Teststrasse 42")),
                    .property(Property(idShort: "Zipcode", valueType: .string, value: "70469")),
                    .property(Property(idShort: "Phone", valueType: .string, value: "+49 711 123456"))
                ]
            ))
        ])
    }

    static func createMultiLanguageSubmodel() -> Submodel {
        createSubmodelWithElements([
            .submodelElementCollection(SubmodelElementCollection(
                idShort: "Instruction001",
                value: [
                    .multiLanguageProperty(MultiLanguageProperty(
                        idShort: "Title",
                        value: [
                            LangString(language: "en", text: "Filter Replacement"),
                            LangString(language: "de", text: "Filteraustausch")
                        ]
                    )),
                    .property(Property(idShort: "MaintenanceType", valueType: .string, value: "preventive"))
                ]
            ))
        ])
    }
}

//
//  SubmodelElementParserTests.swift
//  TwinAct Field Companion
//
//  Unit tests for SubmodelElementParser - parsing SME types into domain models.
//  Tests can be run from debug builds via the diagnostics view.
//

import Foundation

#if DEBUG

// MARK: - Submodel Element Parser Tests

/// Test runner for SubmodelElementParser tests.
public enum SubmodelElementParserTests {

    /// Runs all tests and returns a summary of results.
    /// - Returns: Tuple of (passed count, failed count, failure messages)
    @discardableResult
    public static func runAllTests() -> (passed: Int, failed: Int, failures: [String]) {
        var passed = 0
        var failed = 0
        var failures: [String] = []

        func assert(_ condition: Bool, _ message: String, file: String = #file, line: Int = #line) {
            if condition {
                passed += 1
            } else {
                failed += 1
                failures.append("FAILED: \(message) (line \(line))")
            }
        }

        func assertEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String, file: String = #file, line: Int = #line) {
            if actual == expected {
                passed += 1
            } else {
                failed += 1
                failures.append("FAILED: \(message) - Expected '\(expected)', got '\(actual)' (line \(line))")
            }
        }

        func assertNotNil<T>(_ value: T?, _ message: String, file: String = #file, line: Int = #line) {
            if value != nil {
                passed += 1
            } else {
                failed += 1
                failures.append("FAILED: \(message) - Expected non-nil value (line \(line))")
            }
        }

        // ============================================================
        // MARK: - Test: Parse Digital Nameplate
        // ============================================================

        let nameplateSubmodel = createTestNameplateSubmodel()
        do {
            let nameplate = try SubmodelElementParser.parseDigitalNameplate(from: nameplateSubmodel)

            assertEqual(nameplate.manufacturerName, "Test Manufacturer GmbH", "Nameplate manufacturer name")
            assertEqual(nameplate.serialNumber, "SN-2025-001", "Nameplate serial number")
            assertEqual(nameplate.manufacturerProductDesignation, "Test Product X-500", "Nameplate product designation")
            assertEqual(nameplate.countryOfOrigin, "DE", "Nameplate country of origin")
            assertNotNil(nameplate.productionDate, "Nameplate production date should be parsed")
        } catch {
            failed += 1
            failures.append("FAILED: parseDigitalNameplate threw error: \(error.localizedDescription)")
        }

        // ============================================================
        // MARK: - Test: Parse Handover Documentation
        // ============================================================

        let docsSubmodel = createTestDocumentationSubmodel()
        do {
            let docs = try SubmodelElementParser.parseHandoverDocumentation(from: docsSubmodel)

            assertEqual(docs.documents.count, 2, "Should parse 2 documents")
            assertEqual(docs.documents[0].id, "DOC-001", "First document ID")
            assertEqual(docs.documents[0].documentClass, .operatingManual, "First document class")
            assertNotNil(docs.documents[0].digitalFile, "First document should have digital file")
        } catch {
            failed += 1
            failures.append("FAILED: parseHandoverDocumentation threw error: \(error.localizedDescription)")
        }

        // ============================================================
        // MARK: - Test: Parse Service Request
        // ============================================================

        let serviceRequestSubmodel = createTestServiceRequestSubmodel()
        do {
            let request = try SubmodelElementParser.parseServiceRequest(from: serviceRequestSubmodel)

            assertEqual(request.title, "Test Service Request", "Service request title")
            assertEqual(request.status, .new, "Service request status")
            assertEqual(request.priority, .high, "Service request priority")
            assertEqual(request.category, .maintenance, "Service request category")
            assertNotNil(request.requestDate, "Service request date should be set")
        } catch {
            failed += 1
            failures.append("FAILED: parseServiceRequest threw error: \(error.localizedDescription)")
        }

        // ============================================================
        // MARK: - Test: Parse Service Request Missing Title
        // ============================================================

        let invalidServiceRequestSubmodel = createTestSubmodelWithElements([
            .property(Property(idShort: "Description", valueType: .string, value: "Description only, no title"))
        ])

        do {
            _ = try SubmodelElementParser.parseServiceRequest(from: invalidServiceRequestSubmodel)
            failed += 1
            failures.append("FAILED: parseServiceRequest should throw for missing title")
        } catch {
            if case SubmodelParserError.missingRequiredElement = error {
                passed += 1
            } else {
                failed += 1
                failures.append("FAILED: Expected missingRequiredElement error, got \(error)")
            }
        }

        // ============================================================
        // MARK: - Test: Parse Carbon Footprint
        // ============================================================

        let carbonSubmodel = createTestCarbonFootprintSubmodel()
        do {
            let footprint = try SubmodelElementParser.parseCarbonFootprint(from: carbonSubmodel)

            assertEqual(footprint.pcfCO2eq, 250.5, "Carbon footprint PCF CO2eq")
            assertEqual(footprint.pcfCalculationMethod, "ISO 14067:2018", "Carbon footprint calculation method")
            assertEqual(footprint.recyclabilityPercentage, 85.0, "Carbon footprint recyclability")
        } catch {
            failed += 1
            failures.append("FAILED: parseCarbonFootprint threw error: \(error.localizedDescription)")
        }

        // ============================================================
        // MARK: - Test: Parse Time Series Data
        // ============================================================

        let timeSeriesSubmodel = createTestTimeSeriesSubmodel()
        do {
            let timeSeries = try SubmodelElementParser.parseTimeSeriesData(from: timeSeriesSubmodel)

            assert(timeSeries.records.count >= 1, "Should have at least 1 time series record")
            assertEqual(timeSeries.metadata.name, "SensorReadings", "Time series metadata name")
        } catch {
            failed += 1
            failures.append("FAILED: parseTimeSeriesData threw error: \(error.localizedDescription)")
        }

        // ============================================================
        // MARK: - Test: Parse Maintenance Instructions
        // ============================================================

        let maintenanceSubmodel = createTestMaintenanceSubmodel()
        do {
            let maintenance = try SubmodelElementParser.parseMaintenanceInstructions(from: maintenanceSubmodel)

            assertEqual(maintenance.instructions.count, 1, "Should parse 1 maintenance instruction")
            assertEqual(maintenance.instructions[0].maintenanceType, .preventive, "Maintenance type should be preventive")
            assertNotNil(maintenance.instructions[0].steps, "Maintenance should have steps")
        } catch {
            failed += 1
            failures.append("FAILED: parseMaintenanceInstructions threw error: \(error.localizedDescription)")
        }

        // ============================================================
        // MARK: - Test: Parse Empty Submodel
        // ============================================================

        let emptySubmodel = Submodel(id: "urn:test:empty", submodelElements: [])
        do {
            let nameplate = try SubmodelElementParser.parseDigitalNameplate(from: emptySubmodel)
            // Empty submodel should still parse, just with nil values
            assert(nameplate.manufacturerName == nil, "Empty submodel should have nil manufacturer name")
            assert(nameplate.serialNumber == nil, "Empty submodel should have nil serial number")
        } catch {
            failed += 1
            failures.append("FAILED: Empty submodel parsing threw error: \(error.localizedDescription)")
        }

        // ============================================================
        // MARK: - Test: Parse Nested Collections
        // ============================================================

        let nestedSubmodel = createTestNestedCollectionSubmodel()
        do {
            let nameplate = try SubmodelElementParser.parseDigitalNameplate(from: nestedSubmodel)

            // Test that nested ContactInformation collection is parsed correctly
            assertNotNil(nameplate.manufacturerAddress, "Should parse nested contact information")
            assertEqual(nameplate.manufacturerAddress?.city, "Stuttgart", "Should parse nested city")
            assertEqual(nameplate.manufacturerAddress?.phone, "+49 711 123456", "Should parse nested phone")
        } catch {
            failed += 1
            failures.append("FAILED: Nested collection parsing threw error: \(error.localizedDescription)")
        }

        // ============================================================
        // MARK: - Test: Parse MultiLanguageProperty
        // ============================================================

        let mlpSubmodel = createTestMultiLanguageSubmodel()
        do {
            let maintenance = try SubmodelElementParser.parseMaintenanceInstructions(from: mlpSubmodel)

            assertEqual(maintenance.instructions.count, 1, "Should parse 1 instruction")
            assert(!maintenance.instructions[0].title.isEmpty, "Should parse MLP title")

            // Check that English text is extracted
            let englishTitle = maintenance.instructions[0].title.first { $0.language == "en" }?.text
            assertEqual(englishTitle, "Filter Replacement", "Should extract English title from MLP")
        } catch {
            failed += 1
            failures.append("FAILED: MultiLanguageProperty parsing threw error: \(error.localizedDescription)")
        }

        // ============================================================
        // MARK: - Test: Date Parsing Formats
        // ============================================================

        let dateCases = [
            ("2025-01-15T08:30:00Z", true, "ISO 8601 with timezone"),
            ("2025-01-15", true, "Date only"),
            ("15.01.2025", true, "German format"),
            ("invalid-date", false, "Invalid date")
        ]

        for (dateString, shouldParse, description) in dateCases {
            let dateSubmodel = createTestSubmodelWithElements([
                .property(Property(idShort: "DateOfManufacture", valueType: .string, value: dateString))
            ])

            do {
                let nameplate = try SubmodelElementParser.parseDigitalNameplate(from: dateSubmodel)
                if shouldParse {
                    assertNotNil(nameplate.productionDate, "Should parse \(description): \(dateString)")
                } else {
                    assert(nameplate.productionDate == nil, "Should NOT parse \(description): \(dateString)")
                }
            } catch {
                failed += 1
                failures.append("FAILED: Date parsing threw error for \(description): \(error.localizedDescription)")
            }
        }

        // ============================================================
        // MARK: - Test: JSON Round-Trip for SubmodelElement
        // ============================================================

        let testProperty = Property(
            idShort: "TestProperty",
            valueType: .string,
            value: "test value"
        )
        let element: SubmodelElement = .property(testProperty)

        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let decoder = JSONDecoder()

        do {
            let encoded = try encoder.encode(element)
            let decoded = try decoder.decode(SubmodelElement.self, from: encoded)

            assertEqual(decoded.idShort, "TestProperty", "Round-trip should preserve idShort")

            if case .property(let prop) = decoded {
                assertEqual(prop.value, "test value", "Round-trip should preserve value")
            } else {
                failed += 1
                failures.append("FAILED: Decoded element should be property type")
            }
        } catch {
            failed += 1
            failures.append("FAILED: JSON round-trip threw error: \(error.localizedDescription)")
        }

        // Print summary
        print("=== SubmodelElementParser Tests ===")
        print("Passed: \(passed)")
        print("Failed: \(failed)")
        if !failures.isEmpty {
            print("\nFailures:")
            for failure in failures {
                print("  - \(failure)")
            }
        }
        print("===================================")

        return (passed, failed, failures)
    }

    // MARK: - Test Data Factories

    private static func createTestSubmodelWithElements(_ elements: [SubmodelElement]) -> Submodel {
        Submodel(
            id: "urn:test:submodel",
            idShort: "TestSubmodel",
            submodelElements: elements
        )
    }

    private static func createTestNameplateSubmodel() -> Submodel {
        createTestSubmodelWithElements([
            .property(Property(idShort: "ManufacturerName", valueType: .string, value: "Test Manufacturer GmbH")),
            .property(Property(idShort: "ManufacturerProductDesignation", valueType: .string, value: "Test Product X-500")),
            .property(Property(idShort: "SerialNumber", valueType: .string, value: "SN-2025-001")),
            .property(Property(idShort: "CountryOfOrigin", valueType: .string, value: "DE")),
            .property(Property(idShort: "DateOfManufacture", valueType: .string, value: "2025-01-15T08:30:00Z")),
            .property(Property(idShort: "YearOfConstruction", valueType: .integer, value: "2025"))
        ])
    }

    private static func createTestDocumentationSubmodel() -> Submodel {
        createTestSubmodelWithElements([
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

    private static func createTestServiceRequestSubmodel() -> Submodel {
        createTestSubmodelWithElements([
            .property(Property(idShort: "Title", valueType: .string, value: "Test Service Request")),
            .property(Property(idShort: "Description", valueType: .string, value: "This is a test service request")),
            .property(Property(idShort: "Status", valueType: .string, value: "New")),
            .property(Property(idShort: "Priority", valueType: .string, value: "High")),
            .property(Property(idShort: "Category", valueType: .string, value: "Maintenance")),
            .property(Property(idShort: "RequestDate", valueType: .string, value: "2025-01-18T10:00:00Z"))
        ])
    }

    private static func createTestCarbonFootprintSubmodel() -> Submodel {
        createTestSubmodelWithElements([
            .property(Property(idShort: "PCFCO2eq", valueType: .double, value: "250.5")),
            .property(Property(idShort: "PCFCalculationMethod", valueType: .string, value: "ISO 14067:2018")),
            .property(Property(idShort: "PCFReferenceUnitForCalculation", valueType: .string, value: "1 unit")),
            .property(Property(idShort: "RecyclabilityPercentage", valueType: .double, value: "85.0")),
            .property(Property(idShort: "RecycledContentPercentage", valueType: .double, value: "30.0"))
        ])
    }

    private static func createTestTimeSeriesSubmodel() -> Submodel {
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

    private static func createTestMaintenanceSubmodel() -> Submodel {
        createTestSubmodelWithElements([
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

    private static func createTestNestedCollectionSubmodel() -> Submodel {
        createTestSubmodelWithElements([
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

    private static func createTestMultiLanguageSubmodel() -> Submodel {
        createTestSubmodelWithElements([
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

// MARK: - Debug Verification

/// Convenience function to verify SubmodelElementParser works correctly.
/// Call this during app startup in debug builds.
public func verifySubmodelElementParserInDebug() {
    let results = SubmodelElementParserTests.runAllTests()
    if results.failed > 0 {
        assertionFailure("SubmodelElementParser tests failed! \(results.failed) failures. Check console for details.")
    }
}

#endif // DEBUG

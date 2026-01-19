//
//  SubmodelElementParser.swift
//  TwinAct Field Companion
//
//  Parses AAS SubmodelElement trees into typed domain models.
//  Converts raw AAS data structures into app-specific domain models.
//

import Foundation

// MARK: - Parser Errors

/// Errors that can occur during submodel parsing.
public enum SubmodelParserError: Error, LocalizedError {
    case missingRequiredElement(String)
    case invalidElementType(expected: String, actual: String)
    case invalidValue(element: String, value: String?)
    case unsupportedSubmodelType(String)
    case parsingFailed(String)

    public var errorDescription: String? {
        switch self {
        case .missingRequiredElement(let element):
            return "Missing required element: \(element)"
        case .invalidElementType(let expected, let actual):
            return "Invalid element type. Expected \(expected), got \(actual)"
        case .invalidValue(let element, let value):
            return "Invalid value for \(element): \(value ?? "nil")"
        case .unsupportedSubmodelType(let type):
            return "Unsupported submodel type: \(type)"
        case .parsingFailed(let reason):
            return "Parsing failed: \(reason)"
        }
    }
}

// MARK: - Submodel Element Parser

/// Parses AAS SubmodelElement trees into typed domain models.
public struct SubmodelElementParser {

    // MARK: - Digital Nameplate

    /// Parse a Submodel into DigitalNameplate.
    public static func parseDigitalNameplate(from submodel: Submodel) throws -> DigitalNameplate {
        let elements = submodel.submodelElements ?? []

        return DigitalNameplate(
            manufacturerName: getString(from: elements, path: "ManufacturerName"),
            manufacturerProductDesignation: getString(from: elements, path: "ManufacturerProductDesignation"),
            manufacturerProductFamily: getString(from: elements, path: "ManufacturerProductFamily"),
            manufacturerProductType: getString(from: elements, path: "ManufacturerProductType"),
            orderCode: getString(from: elements, path: "OrderCode"),
            serialNumber: getString(from: elements, path: "SerialNumber"),
            batchNumber: getString(from: elements, path: "BatchNumber"),
            productionDate: getDate(from: elements, path: "DateOfManufacture"),
            countryOfOrigin: getString(from: elements, path: "CountryOfOrigin"),
            yearOfConstruction: getInt(from: elements, path: "YearOfConstruction"),
            hardwareVersion: getString(from: elements, path: "HardwareVersion"),
            firmwareVersion: getString(from: elements, path: "FirmwareVersion"),
            softwareVersion: getString(from: elements, path: "SoftwareVersion"),
            manufacturerAddress: parseAddress(from: elements),
            manufacturerLogo: getURL(from: elements, path: "CompanyLogo"),
            productImage: getURL(from: elements, path: "ProductImage"),
            markings: parseMarkings(from: elements)
        )
    }

    private static func parseAddress(from elements: [SubmodelElement]) -> Address? {
        // Try to find ContactInformation collection
        guard let contactInfo = findCollection(in: elements, named: "ContactInformation") else {
            return nil
        }

        let contactElements = contactInfo.value ?? []

        return Address(
            street: getString(from: contactElements, path: "Street"),
            zipCode: getString(from: contactElements, path: "Zipcode") ?? getString(from: contactElements, path: "ZipCode"),
            city: getString(from: contactElements, path: "CityTown") ?? getString(from: contactElements, path: "City"),
            stateCounty: getString(from: contactElements, path: "StateCounty"),
            country: getString(from: contactElements, path: "NationalCode") ?? getString(from: contactElements, path: "Country"),
            phone: getString(from: contactElements, path: "Phone"),
            email: getString(from: contactElements, path: "Email")
        )
    }

    private static func parseMarkings(from elements: [SubmodelElement]) -> [Marking]? {
        guard let markingsCollection = findCollection(in: elements, named: "Markings") else {
            return nil
        }

        var result: [Marking] = []

        for element in markingsCollection.value ?? [] {
            if case .submodelElementCollection(let marking) = element {
                let markingElements = marking.value ?? []
                if let name = getString(from: markingElements, path: "MarkingName") {
                    result.append(Marking(
                        name: name,
                        file: getURL(from: markingElements, path: "MarkingFile"),
                        additionalText: getString(from: markingElements, path: "MarkingAdditionalText")
                    ))
                }
            }
        }

        return result.isEmpty ? nil : result
    }

    // MARK: - Handover Documentation

    /// Parse a Submodel into HandoverDocumentation.
    public static func parseHandoverDocumentation(from submodel: Submodel) throws -> HandoverDocumentation {
        let elements = submodel.submodelElements ?? []
        var documents: [Document] = []

        // Look for Documents collection or iterate through top-level collections
        let documentElements: [SubmodelElement]
        if let docsCollection = findCollection(in: elements, named: "Documents") {
            documentElements = docsCollection.value ?? []
        } else {
            documentElements = elements
        }

        for element in documentElements {
            if case .submodelElementCollection(let docCollection) = element {
                if let document = parseDocument(from: docCollection) {
                    documents.append(document)
                }
            }
        }

        return HandoverDocumentation(documents: documents)
    }

    private static func parseDocument(from collection: SubmodelElementCollection) -> Document? {
        let elements = collection.value ?? []

        let title = getMultiLangString(from: elements, path: "DocumentTitle")
            ?? getMultiLangString(from: elements, path: "Title")
            ?? [LangString(language: "en", text: collection.idShort)]

        let documentClassString = getString(from: elements, path: "DocumentClassId")
            ?? getString(from: elements, path: "DocumentClass")
            ?? "99-99"

        let documentClass = DocumentClass(rawValue: documentClassString) ?? .other

        var digitalFiles: [DigitalFile] = []
        if let filesCollection = findCollection(in: elements, named: "DigitalFile") {
            digitalFiles = parseDigitalFiles(from: filesCollection)
        } else {
            // Check for direct file elements
            for element in elements {
                if case .file(let file) = element {
                    if let fileURL = URL(string: file.value ?? "") {
                        digitalFiles.append(DigitalFile(
                            fileFormat: file.contentType,
                            file: fileURL
                        ))
                    }
                }
            }
        }

        return Document(
            id: collection.idShort,
            title: title,
            summary: getMultiLangString(from: elements, path: "DocumentSummary") ?? getMultiLangString(from: elements, path: "Summary"),
            documentClass: documentClass,
            documentVersion: getString(from: elements, path: "DocumentVersion") ?? getString(from: elements, path: "Version"),
            language: getStringArray(from: elements, path: "Language"),
            digitalFile: digitalFiles.isEmpty ? nil : digitalFiles
        )
    }

    private static func parseDigitalFiles(from collection: SubmodelElementCollection) -> [DigitalFile] {
        var files: [DigitalFile] = []

        for element in collection.value ?? [] {
            if case .file(let file) = element {
                if let urlString = file.value, let fileURL = URL(string: urlString) {
                    files.append(DigitalFile(
                        fileFormat: file.contentType,
                        file: fileURL,
                        fileName: file.idShort
                    ))
                }
            } else if case .submodelElementCollection(let fileCollection) = element {
                let fileElements = fileCollection.value ?? []
                if let urlString = getString(from: fileElements, path: "File") ?? getString(from: fileElements, path: "FileURL"),
                   let fileURL = URL(string: urlString) {
                    files.append(DigitalFile(
                        previewFile: getURL(from: fileElements, path: "PreviewFile"),
                        fileFormat: getString(from: fileElements, path: "MimeType") ?? getString(from: fileElements, path: "ContentType") ?? "application/octet-stream",
                        file: fileURL
                    ))
                }
            }
        }

        return files
    }

    // MARK: - Maintenance Instructions

    /// Parse a Submodel into MaintenanceInstructions.
    public static func parseMaintenanceInstructions(from submodel: Submodel) throws -> MaintenanceInstructions {
        let elements = submodel.submodelElements ?? []
        var instructions: [MaintenanceInstruction] = []

        for element in elements {
            if case .submodelElementCollection(let collection) = element {
                if let instruction = parseMaintenanceInstruction(from: collection) {
                    instructions.append(instruction)
                }
            }
        }

        return MaintenanceInstructions(instructions: instructions)
    }

    private static func parseMaintenanceInstruction(from collection: SubmodelElementCollection) -> MaintenanceInstruction? {
        let elements = collection.value ?? []

        let title = getMultiLangString(from: elements, path: "Title")
            ?? getMultiLangString(from: elements, path: "Name")
            ?? [LangString(language: "en", text: collection.idShort)]

        let maintenanceTypeString = getString(from: elements, path: "MaintenanceType") ?? "preventive"
        let maintenanceType = MaintenanceType(rawValue: maintenanceTypeString.lowercased()) ?? .preventive

        var steps: [MaintenanceStep] = []
        if let stepsCollection = findCollection(in: elements, named: "Steps") ?? findCollection(in: elements, named: "Procedure") {
            steps = parseMaintenanceSteps(from: stepsCollection)
        }

        return MaintenanceInstruction(
            id: collection.idShort,
            title: title,
            description: getMultiLangString(from: elements, path: "Description"),
            maintenanceType: maintenanceType,
            intervalValue: getDouble(from: elements, path: "IntervalValue") ?? getDouble(from: elements, path: "Interval"),
            intervalUnit: getString(from: elements, path: "IntervalUnit") ?? getString(from: elements, path: "Unit"),
            steps: steps.isEmpty ? nil : steps,
            requiredTools: getStringArray(from: elements, path: "RequiredTools"),
            requiredParts: getStringArray(from: elements, path: "RequiredParts") ?? getStringArray(from: elements, path: "SpareParts"),
            safetyInstructions: getMultiLangString(from: elements, path: "SafetyInstructions"),
            estimatedDuration: getInt(from: elements, path: "EstimatedDuration") ?? getInt(from: elements, path: "Duration"),
            skillLevel: parseSkillLevel(from: elements)
        )
    }

    private static func parseMaintenanceSteps(from collection: SubmodelElementCollection) -> [MaintenanceStep] {
        var steps: [MaintenanceStep] = []
        var stepNumber = 1

        for element in collection.value ?? [] {
            if case .submodelElementCollection(let stepCollection) = element {
                let stepElements = stepCollection.value ?? []

                let description = getMultiLangString(from: stepElements, path: "Description")
                    ?? getMultiLangString(from: stepElements, path: "Text")
                    ?? [LangString(language: "en", text: stepCollection.idShort)]

                steps.append(MaintenanceStep(
                    stepNumber: getInt(from: stepElements, path: "StepNumber") ?? stepNumber,
                    description: description,
                    image: getURL(from: stepElements, path: "Image"),
                    video: getURL(from: stepElements, path: "Video"),
                    warnings: getMultiLangString(from: stepElements, path: "Warning") ?? getMultiLangString(from: stepElements, path: "Warnings")
                ))
                stepNumber += 1
            } else if case .multiLanguageProperty(let mlp) = element {
                steps.append(MaintenanceStep(
                    stepNumber: stepNumber,
                    description: mlp.value ?? [LangString(language: "en", text: mlp.idShort)]
                ))
                stepNumber += 1
            }
        }

        return steps
    }

    private static func parseSkillLevel(from elements: [SubmodelElement]) -> SkillLevel? {
        guard let levelString = getString(from: elements, path: "SkillLevel")?.lowercased() else {
            return nil
        }
        return SkillLevel(rawValue: levelString)
    }

    // MARK: - Service Request

    /// Parse a Submodel into ServiceRequest.
    public static func parseServiceRequest(from submodel: Submodel) throws -> ServiceRequest {
        let elements = submodel.submodelElements ?? []

        guard let title = getString(from: elements, path: "Title") ?? getString(from: elements, path: "Subject") else {
            throw SubmodelParserError.missingRequiredElement("Title")
        }

        let description = getString(from: elements, path: "Description") ?? getString(from: elements, path: "Details") ?? ""

        let categoryString = getString(from: elements, path: "Category") ?? "Other"
        let category = ServiceRequestCategory(rawValue: categoryString) ?? .other

        let statusString = getString(from: elements, path: "Status") ?? "New"
        let status = ServiceRequestStatus(rawValue: statusString) ?? .new

        let priorityString = getString(from: elements, path: "Priority") ?? "Normal"
        let priority = ServiceRequestPriority(rawValue: priorityString) ?? .normal

        var notes: [ServiceNote] = []
        if let notesCollection = findCollection(in: elements, named: "Notes") {
            notes = parseServiceNotes(from: notesCollection)
        }

        return ServiceRequest(
            id: getString(from: elements, path: "RequestId") ?? submodel.idShort ?? UUID().uuidString,
            status: status,
            priority: priority,
            category: category,
            title: title,
            description: description,
            requestDate: getDate(from: elements, path: "RequestDate") ?? Date(),
            requesterName: getString(from: elements, path: "RequesterName"),
            requesterEmail: getString(from: elements, path: "RequesterEmail"),
            requesterPhone: getString(from: elements, path: "RequesterPhone"),
            attachments: getURLArray(from: elements, path: "Attachments"),
            notes: notes.isEmpty ? nil : notes,
            assetId: getString(from: elements, path: "AssetId"),
            location: getString(from: elements, path: "Location"),
            scheduledDate: getDate(from: elements, path: "ScheduledDate"),
            completedDate: getDate(from: elements, path: "CompletedDate"),
            assignedTo: getString(from: elements, path: "AssignedTo")
        )
    }

    private static func parseServiceNotes(from collection: SubmodelElementCollection) -> [ServiceNote] {
        var notes: [ServiceNote] = []

        for element in collection.value ?? [] {
            if case .submodelElementCollection(let noteCollection) = element {
                let noteElements = noteCollection.value ?? []
                if let text = getString(from: noteElements, path: "Text") {
                    notes.append(ServiceNote(
                        timestamp: getDate(from: noteElements, path: "Timestamp") ?? Date(),
                        author: getString(from: noteElements, path: "Author") ?? "Unknown",
                        text: text
                    ))
                }
            }
        }

        return notes
    }

    // MARK: - Time Series Data

    /// Parse a Submodel into TimeSeriesData.
    public static func parseTimeSeriesData(from submodel: Submodel) throws -> TimeSeriesData {
        let elements = submodel.submodelElements ?? []

        // Parse metadata
        let metadata = TimeSeriesMetadata(
            name: submodel.idShort ?? "TimeSeries",
            description: submodel.description,
            startTime: getDate(from: elements, path: "StartTime"),
            endTime: getDate(from: elements, path: "EndTime"),
            samplingInterval: getDouble(from: elements, path: "SamplingInterval"),
            segments: parseTimeSeriesSegments(from: elements),
            unit: getString(from: elements, path: "Unit"),
            properties: parseTimeSeriesProperties(from: elements),
            source: getString(from: elements, path: "Source")
        )

        // Parse records
        var records: [TimeSeriesRecord] = []
        var recordElements: [SubmodelElement] = []

        if let recordsCollection = findCollection(in: elements, named: "Records")
            ?? findCollection(in: elements, named: "Data") {
            recordElements = recordsCollection.value ?? []
        } else if let recordsList = findList(in: elements, named: "Records") {
            recordElements = recordsList.value ?? []
        }

        for element in recordElements {
            if case .submodelElementCollection(let recordCollection) = element {
                if let record = parseTimeSeriesRecord(from: recordCollection) {
                    records.append(record)
                }
            }
        }

        return TimeSeriesData(records: records, metadata: metadata)
    }

    private static func parseTimeSeriesRecord(from collection: SubmodelElementCollection) -> TimeSeriesRecord? {
        let elements = collection.value ?? []

        guard let timestamp = getDate(from: elements, path: "Timestamp") ?? getDate(from: elements, path: "Time") else {
            return nil
        }

        var values: [String: Double] = [:]
        for element in elements {
            if case .property(let prop) = element {
                if prop.idShort != "Timestamp" && prop.idShort != "Time" {
                    if let doubleValue = Double(prop.value ?? "") {
                        values[prop.idShort] = doubleValue
                    }
                }
            }
        }

        return TimeSeriesRecord(timestamp: timestamp, values: values)
    }

    private static func parseTimeSeriesSegments(from elements: [SubmodelElement]) -> [TimeSeriesSegment]? {
        guard let segmentsCollection = findCollection(in: elements, named: "Segments") else {
            return nil
        }

        var segments: [TimeSeriesSegment] = []
        for element in segmentsCollection.value ?? [] {
            if case .submodelElementCollection(let segmentCollection) = element {
                let segmentElements = segmentCollection.value ?? []
                segments.append(TimeSeriesSegment(
                    name: segmentCollection.idShort,
                    description: segmentCollection.description,
                    state: getString(from: segmentElements, path: "State"),
                    duration: getDouble(from: segmentElements, path: "Duration"),
                    startTime: getDate(from: segmentElements, path: "StartTime"),
                    endTime: getDate(from: segmentElements, path: "EndTime")
                ))
            }
        }

        return segments.isEmpty ? nil : segments
    }

    private static func parseTimeSeriesProperties(from elements: [SubmodelElement]) -> [TimeSeriesProperty]? {
        guard let propsCollection = findCollection(in: elements, named: "Properties")
            ?? findCollection(in: elements, named: "Variables") else {
            return nil
        }

        var properties: [TimeSeriesProperty] = []
        for element in propsCollection.value ?? [] {
            if case .submodelElementCollection(let propCollection) = element {
                let propElements = propCollection.value ?? []
                properties.append(TimeSeriesProperty(
                    name: propCollection.idShort,
                    description: propCollection.description,
                    unit: getString(from: propElements, path: "Unit"),
                    dataType: getString(from: propElements, path: "DataType"),
                    minValue: getDouble(from: propElements, path: "MinValue"),
                    maxValue: getDouble(from: propElements, path: "MaxValue")
                ))
            }
        }

        return properties.isEmpty ? nil : properties
    }

    // MARK: - Carbon Footprint

    /// Parse a Submodel into CarbonFootprint.
    public static func parseCarbonFootprint(from submodel: Submodel) throws -> CarbonFootprint {
        let elements = submodel.submodelElements ?? []

        // Parse life cycle phases
        var lifeCyclePhases: [LifeCyclePhase]?
        if let phasesString = getString(from: elements, path: "PCFLifeCyclePhase") {
            lifeCyclePhases = phasesString.split(separator: ",")
                .compactMap { LifeCyclePhase(rawValue: String($0).trimmingCharacters(in: .whitespaces)) }
        }

        // Parse transport mode
        var transportMode: TransportMode?
        if let modeString = getString(from: elements, path: "TCFTransportMode")?.lowercased() {
            transportMode = TransportMode(rawValue: modeString)
        }

        return CarbonFootprint(
            pcfCO2eq: getDouble(from: elements, path: "PCFCO2eq") ?? getDouble(from: elements, path: "PCFCarbonFootprint"),
            pcfReferenceUnitForCalculation: getString(from: elements, path: "PCFReferenceUnitForCalculation"),
            pcfCalculationMethod: getString(from: elements, path: "PCFCalculationMethod"),
            pcfLifeCyclePhase: lifeCyclePhases,
            pcfGeographicalRegion: getString(from: elements, path: "PCFGeographicalRegion"),
            pcfCalculationDate: getDate(from: elements, path: "PCFCalculationDate"),
            tcfCO2eq: getDouble(from: elements, path: "TCFCO2eq"),
            tcfCalculationMethod: getString(from: elements, path: "TCFCalculationMethod"),
            tcfTransportDistance: getDouble(from: elements, path: "TCFTransportDistance"),
            tcfTransportMode: transportMode,
            ucfCO2eq: getDouble(from: elements, path: "UCFCO2eq"),
            ucfExpectedLifetime: getDouble(from: elements, path: "UCFExpectedLifetime"),
            ucfExpectedEnergyConsumption: getDouble(from: elements, path: "UCFExpectedEnergyConsumption"),
            ucfEnergyCarbonIntensity: getDouble(from: elements, path: "UCFEnergyCarbonIntensity"),
            eolCO2eq: getDouble(from: elements, path: "EOLCO2eq"),
            recyclabilityPercentage: getDouble(from: elements, path: "RecyclabilityPercentage"),
            recycledContentPercentage: getDouble(from: elements, path: "RecycledContentPercentage"),
            verificationStatement: getURL(from: elements, path: "VerificationStatement"),
            validityPeriodStart: getDate(from: elements, path: "ValidityPeriodStart"),
            validityPeriodEnd: getDate(from: elements, path: "ValidityPeriodEnd"),
            verifierName: getString(from: elements, path: "VerifierName"),
            verificationStandard: getString(from: elements, path: "VerificationStandard"),
            waterFootprint: getDouble(from: elements, path: "WaterFootprint"),
            energyEfficiencyClass: getString(from: elements, path: "EnergyEfficiencyClass"),
            circularEconomyScore: getDouble(from: elements, path: "CircularEconomyScore")
        )
    }

    // MARK: - Helper Methods

    /// Find element by idShort in array.
    private static func findElement(in elements: [SubmodelElement], named idShort: String) -> SubmodelElement? {
        elements.first { $0.idShort == idShort }
    }

    /// Find collection by idShort.
    private static func findCollection(in elements: [SubmodelElement], named idShort: String) -> SubmodelElementCollection? {
        if let element = findElement(in: elements, named: idShort),
           case .submodelElementCollection(let collection) = element {
            return collection
        }
        return nil
    }

    /// Find list by idShort.
    private static func findList(in elements: [SubmodelElement], named idShort: String) -> SubmodelElementList? {
        if let element = findElement(in: elements, named: idShort),
           case .submodelElementList(let list) = element {
            return list
        }
        return nil
    }

    /// Get string value from property.
    private static func getString(from elements: [SubmodelElement], path: String) -> String? {
        guard let element = findElement(in: elements, named: path) else { return nil }

        switch element {
        case .property(let prop):
            return prop.value
        case .multiLanguageProperty(let mlp):
            return mlp.value?.englishText
        default:
            return nil
        }
    }

    /// Get multi-language strings from property.
    private static func getMultiLangString(from elements: [SubmodelElement], path: String) -> [LangString]? {
        guard let element = findElement(in: elements, named: path) else { return nil }

        switch element {
        case .multiLanguageProperty(let mlp):
            return mlp.value
        case .property(let prop):
            if let value = prop.value {
                return [LangString(language: "en", text: value)]
            }
            return nil
        default:
            return nil
        }
    }

    /// Get integer value from property.
    private static func getInt(from elements: [SubmodelElement], path: String) -> Int? {
        guard let stringValue = getString(from: elements, path: path) else { return nil }
        return Int(stringValue)
    }

    /// Get double value from property.
    private static func getDouble(from elements: [SubmodelElement], path: String) -> Double? {
        guard let stringValue = getString(from: elements, path: path) else { return nil }
        return Double(stringValue)
    }

    /// Get date value from property.
    private static func getDate(from elements: [SubmodelElement], path: String) -> Date? {
        guard let stringValue = getString(from: elements, path: path) else { return nil }

        // Try ISO 8601 format first
        let isoFormatter = ISO8601DateFormatter()
        if let date = isoFormatter.date(from: stringValue) {
            return date
        }

        // Try date-only format
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        if let date = dateFormatter.date(from: stringValue) {
            return date
        }

        // Try various other formats
        let formats = ["yyyy-MM-dd'T'HH:mm:ss", "dd.MM.yyyy", "MM/dd/yyyy"]
        for format in formats {
            dateFormatter.dateFormat = format
            if let date = dateFormatter.date(from: stringValue) {
                return date
            }
        }

        return nil
    }

    /// Get URL value from file element.
    private static func getURL(from elements: [SubmodelElement], path: String) -> URL? {
        guard let element = findElement(in: elements, named: path) else { return nil }

        switch element {
        case .file(let file):
            return file.value.flatMap { URL(string: $0) }
        case .property(let prop):
            return prop.value.flatMap { URL(string: $0) }
        default:
            return nil
        }
    }

    /// Get string array from list or collection.
    private static func getStringArray(from elements: [SubmodelElement], path: String) -> [String]? {
        guard let element = findElement(in: elements, named: path) else { return nil }

        switch element {
        case .submodelElementList(let list):
            return list.value?.compactMap { item in
                if case .property(let prop) = item {
                    return prop.value
                }
                return nil
            }
        case .submodelElementCollection(let collection):
            return collection.value?.compactMap { item in
                if case .property(let prop) = item {
                    return prop.value
                }
                return nil
            }
        case .property(let prop):
            // Single value, return as array
            return prop.value.map { [$0] }
        default:
            return nil
        }
    }

    /// Get URL array from list or collection.
    private static func getURLArray(from elements: [SubmodelElement], path: String) -> [URL]? {
        guard let element = findElement(in: elements, named: path) else { return nil }

        switch element {
        case .submodelElementList(let list):
            return list.value?.compactMap { item in
                if case .file(let file) = item {
                    return file.value.flatMap { URL(string: $0) }
                }
                return nil
            }
        case .submodelElementCollection(let collection):
            return collection.value?.compactMap { item in
                if case .file(let file) = item {
                    return file.value.flatMap { URL(string: $0) }
                }
                return nil
            }
        default:
            return nil
        }
    }
}

// MARK: - Convenience Extensions

extension Submodel {
    /// Parse this submodel into a DigitalNameplate if applicable.
    public func asDigitalNameplate() throws -> DigitalNameplate {
        try SubmodelElementParser.parseDigitalNameplate(from: self)
    }

    /// Parse this submodel into HandoverDocumentation if applicable.
    public func asHandoverDocumentation() throws -> HandoverDocumentation {
        try SubmodelElementParser.parseHandoverDocumentation(from: self)
    }

    /// Parse this submodel into MaintenanceInstructions if applicable.
    public func asMaintenanceInstructions() throws -> MaintenanceInstructions {
        try SubmodelElementParser.parseMaintenanceInstructions(from: self)
    }

    /// Parse this submodel into ServiceRequest if applicable.
    public func asServiceRequest() throws -> ServiceRequest {
        try SubmodelElementParser.parseServiceRequest(from: self)
    }

    /// Parse this submodel into TimeSeriesData if applicable.
    public func asTimeSeriesData() throws -> TimeSeriesData {
        try SubmodelElementParser.parseTimeSeriesData(from: self)
    }

    /// Parse this submodel into CarbonFootprint if applicable.
    public func asCarbonFootprint() throws -> CarbonFootprint {
        try SubmodelElementParser.parseCarbonFootprint(from: self)
    }
}

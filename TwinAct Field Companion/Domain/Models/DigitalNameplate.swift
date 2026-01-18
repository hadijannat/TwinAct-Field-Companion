//
//  DigitalNameplate.swift
//  TwinAct Field Companion
//
//  Digital Nameplate domain model per IDTA 02006-2-0.
//  Contains manufacturer and product identification data.
//  READ ONLY - This submodel cannot be modified by the app.
//

import Foundation

// MARK: - Digital Nameplate

/// Digital Nameplate per IDTA 02006-2-0
/// Contains manufacturer and product identification data.
/// This is a read-only submodel.
public struct DigitalNameplate: Codable, Sendable, Hashable {

    // MARK: - Manufacturer Information

    /// Legally valid designation of the natural or judicial person which is directly
    /// responsible for the design, production, packaging and labeling of a product
    public let manufacturerName: String?

    /// Short description of the product, product group or function
    public let manufacturerProductDesignation: String?

    /// Second level of a 3-level device hierarchy
    public let manufacturerProductFamily: String?

    /// Characteristic to differentiate products from product families
    public let manufacturerProductType: String?

    /// Unique product identifier of the manufacturer for the product type
    public let orderCode: String?

    // MARK: - Identification

    /// Unique combination of numbers and letters used to identify the device
    public let serialNumber: String?

    /// Unique combination of numbers and letters used to identify a batch/lot
    public let batchNumber: String?

    /// Date from which the production and / or development process is completed
    public let productionDate: Date?

    /// Country where the product was manufactured (ISO 3166-1)
    public let countryOfOrigin: String?

    // MARK: - Technical Data

    /// Year as completion date of object
    public let yearOfConstruction: Int?

    /// Version of the hardware supplied with the device
    public let hardwareVersion: String?

    /// Version of the firmware supplied with the device
    public let firmwareVersion: String?

    /// Version of the software used by the device
    public let softwareVersion: String?

    // MARK: - Contact

    /// Address of manufacturer (street, city, zip, country, etc.)
    public let manufacturerAddress: Address?

    /// URL to manufacturer logo image
    public let manufacturerLogo: URL?

    /// URL to product image
    public let productImage: URL?

    // MARK: - Marking/Certifications

    /// Compliance markings and certifications
    public let markings: [Marking]?

    // MARK: - Initialization

    public init(
        manufacturerName: String? = nil,
        manufacturerProductDesignation: String? = nil,
        manufacturerProductFamily: String? = nil,
        manufacturerProductType: String? = nil,
        orderCode: String? = nil,
        serialNumber: String? = nil,
        batchNumber: String? = nil,
        productionDate: Date? = nil,
        countryOfOrigin: String? = nil,
        yearOfConstruction: Int? = nil,
        hardwareVersion: String? = nil,
        firmwareVersion: String? = nil,
        softwareVersion: String? = nil,
        manufacturerAddress: Address? = nil,
        manufacturerLogo: URL? = nil,
        productImage: URL? = nil,
        markings: [Marking]? = nil
    ) {
        self.manufacturerName = manufacturerName
        self.manufacturerProductDesignation = manufacturerProductDesignation
        self.manufacturerProductFamily = manufacturerProductFamily
        self.manufacturerProductType = manufacturerProductType
        self.orderCode = orderCode
        self.serialNumber = serialNumber
        self.batchNumber = batchNumber
        self.productionDate = productionDate
        self.countryOfOrigin = countryOfOrigin
        self.yearOfConstruction = yearOfConstruction
        self.hardwareVersion = hardwareVersion
        self.firmwareVersion = firmwareVersion
        self.softwareVersion = softwareVersion
        self.manufacturerAddress = manufacturerAddress
        self.manufacturerLogo = manufacturerLogo
        self.productImage = productImage
        self.markings = markings
    }
}

// MARK: - Address

/// Physical address for manufacturer contact information.
public struct Address: Codable, Sendable, Hashable {
    /// Street name and house number
    public let street: String?

    /// Postal/ZIP code
    public let zipCode: String?

    /// City name
    public let city: String?

    /// State, province, or county
    public let stateCounty: String?

    /// Country name or ISO 3166-1 code
    public let country: String?

    /// Phone number
    public let phone: String?

    /// Email address
    public let email: String?

    public init(
        street: String? = nil,
        zipCode: String? = nil,
        city: String? = nil,
        stateCounty: String? = nil,
        country: String? = nil,
        phone: String? = nil,
        email: String? = nil
    ) {
        self.street = street
        self.zipCode = zipCode
        self.city = city
        self.stateCounty = stateCounty
        self.country = country
        self.phone = phone
        self.email = email
    }

    /// Formatted multi-line address string.
    public var formattedAddress: String {
        var lines: [String] = []

        if let street = street {
            lines.append(street)
        }

        var cityLine = ""
        if let zipCode = zipCode {
            cityLine += zipCode
        }
        if let city = city {
            if !cityLine.isEmpty { cityLine += " " }
            cityLine += city
        }
        if !cityLine.isEmpty {
            lines.append(cityLine)
        }

        if let stateCounty = stateCounty {
            lines.append(stateCounty)
        }
        if let country = country {
            lines.append(country)
        }

        return lines.joined(separator: "\n")
    }
}

// MARK: - Marking

/// Compliance marking or certification.
public struct Marking: Codable, Sendable, Hashable {
    /// Name of the marking (e.g., "CE", "UL", "FCC")
    public let name: String

    /// URL to marking image/logo
    public let file: URL?

    /// Additional text or description for the marking
    public let additionalText: String?

    public init(
        name: String,
        file: URL? = nil,
        additionalText: String? = nil
    ) {
        self.name = name
        self.file = file
        self.additionalText = additionalText
    }
}

// MARK: - IDTA Semantic IDs

extension DigitalNameplate {
    /// IDTA semantic ID for Digital Nameplate submodel
    public static let semanticId = "https://admin-shell.io/zvei/nameplate/2/0/Nameplate"

    /// Alternative semantic ID (version 1.0)
    public static let semanticIdV1 = "https://admin-shell.io/zvei/nameplate/1/0/Nameplate"
}

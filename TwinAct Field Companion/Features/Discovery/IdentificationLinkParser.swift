//
//  IdentificationLinkParser.swift
//  TwinAct Field Companion
//
//  Parses IEC 61406 identification links from QR codes.
//  Supports various manufacturer link formats and Digital Product Passport URLs.
//

import Foundation
import os.log

// MARK: - Identification Link Types

/// Supported identification link patterns per IEC 61406 and common manufacturer formats.
public enum IdentificationLinkType: String, CaseIterable, Sendable {
    /// Standard manufacturer identification link (https://id.manufacturer.com/...)
    case manufacturerLink

    /// URN-based identifier (urn:eclass:..., urn:irdi:...)
    case urnNid

    /// Digital Nameplate URL format (https://www.manufacturer.com/digital-nameplate/...)
    case digitalNameplate

    /// Direct AAS link (https://aas.server.com/shells/...)
    case aasDirectLink

    /// DIN SPEC 91406 compliant link
    case dinSpec91406

    /// GS1 Digital Link (https://id.gs1.org/01/...)
    case gs1DigitalLink

    /// ECLASS identification
    case eclassId

    /// Unknown or custom format
    case unknown

    /// Human-readable display name
    public var displayName: String {
        switch self {
        case .manufacturerLink: return "Manufacturer ID"
        case .urnNid: return "URN Identifier"
        case .digitalNameplate: return "Digital Nameplate"
        case .aasDirectLink: return "AAS Direct Link"
        case .dinSpec91406: return "DIN SPEC 91406"
        case .gs1DigitalLink: return "GS1 Digital Link"
        case .eclassId: return "ECLASS ID"
        case .unknown: return "Unknown Format"
        }
    }
}

// MARK: - Asset Identification Link

/// Parsed identification link from QR code containing asset identifiers.
public struct AssetIdentificationLink: Sendable, Hashable, Identifiable {

    public var id: String { originalString }

    /// Original URL/string from QR code
    public let originalURL: URL?

    /// Original string value (for non-URL formats)
    public let originalString: String

    /// Detected link type
    public let linkType: IdentificationLinkType

    /// Manufacturer name if extractable
    public let manufacturer: String?

    /// Product family/type if extractable
    public let productFamily: String?

    /// Serial number if extractable
    public let serialNumber: String?

    /// Part/article number if extractable
    public let partNumber: String?

    /// Batch/lot number if extractable
    public let batchNumber: String?

    /// Extracted AAS identifier (if direct link)
    public let aasId: String?

    /// Global asset ID
    public let globalAssetId: String?

    /// All extracted specific asset identifiers
    public let specificAssetIds: [SpecificAssetId]

    /// Timestamp when parsed
    public let parsedAt: Date

    /// Confidence level of parsing (0.0 - 1.0)
    public let confidence: Double

    // MARK: - Initialization

    public init(
        originalURL: URL?,
        originalString: String,
        linkType: IdentificationLinkType,
        manufacturer: String? = nil,
        productFamily: String? = nil,
        serialNumber: String? = nil,
        partNumber: String? = nil,
        batchNumber: String? = nil,
        aasId: String? = nil,
        globalAssetId: String? = nil,
        specificAssetIds: [SpecificAssetId] = [],
        confidence: Double = 1.0
    ) {
        self.originalURL = originalURL
        self.originalString = originalString
        self.linkType = linkType
        self.manufacturer = manufacturer
        self.productFamily = productFamily
        self.serialNumber = serialNumber
        self.partNumber = partNumber
        self.batchNumber = batchNumber
        self.aasId = aasId
        self.globalAssetId = globalAssetId
        self.specificAssetIds = specificAssetIds
        self.parsedAt = Date()
        self.confidence = confidence
    }

    // MARK: - Lookup Query

    /// Asset IDs suitable for AAS Discovery Service lookup.
    public var lookupQuery: [SpecificAssetId] {
        // Return explicit specific asset IDs if available
        if !specificAssetIds.isEmpty {
            return specificAssetIds
        }

        // Build from extracted identifiers
        var ids: [SpecificAssetId] = []

        // Priority 1: Serial number (most unique)
        if let serial = serialNumber {
            ids.append(SpecificAssetId(name: "serialNumber", value: serial))
        }

        // Priority 2: Part number
        if let part = partNumber {
            ids.append(SpecificAssetId(name: "partNumber", value: part))
            ids.append(SpecificAssetId(name: "manufacturerPartId", value: part))
        }

        // Priority 3: Batch number
        if let batch = batchNumber {
            ids.append(SpecificAssetId(name: "batchId", value: batch))
        }

        // Priority 4: Global asset ID
        if let globalId = globalAssetId {
            ids.append(SpecificAssetId(name: "globalAssetId", value: globalId))
        }

        // Fallback: use the original URL as global asset ID
        if ids.isEmpty, let url = originalURL {
            ids.append(SpecificAssetId(name: "globalAssetId", value: url.absoluteString))
        }

        return ids
    }

    /// Whether this link has enough information for AAS lookup.
    public var canLookup: Bool {
        !lookupQuery.isEmpty || aasId != nil
    }

    /// Display summary for UI.
    public var displaySummary: String {
        if let serial = serialNumber, let mfr = manufacturer {
            return "\(mfr): \(serial)"
        }
        if let serial = serialNumber {
            return "S/N: \(serial)"
        }
        if let part = partNumber {
            return "P/N: \(part)"
        }
        if let aas = aasId {
            return "AAS: \(aas.prefix(20))..."
        }
        return linkType.displayName
    }
}

// MARK: - Identification Link Parser

/// Parses IEC 61406 and common identification link formats from QR codes.
public struct IdentificationLinkParser {

    private static let logger = Logger(
        subsystem: AppConfiguration.AppInfo.bundleIdentifier,
        category: "IdentificationLinkParser"
    )

    // MARK: - Known Patterns

    /// Known manufacturer ID URL patterns
    private static let manufacturerPatterns: [(host: String, manufacturer: String)] = [
        ("id.siemens.com", "Siemens"),
        ("id.bosch.com", "Bosch"),
        ("id.festo.com", "Festo"),
        ("id.phoenix-contact.com", "Phoenix Contact"),
        ("id.sick.com", "SICK"),
        ("id.wago.com", "WAGO"),
        ("id.endress.com", "Endress+Hauser"),
        ("id.abb.com", "ABB"),
        ("id.schneider-electric.com", "Schneider Electric"),
        ("id.rockwellautomation.com", "Rockwell Automation"),
        ("id.beckhoff.com", "Beckhoff"),
        ("id.lenze.com", "Lenze"),
        ("id.sew-eurodrive.com", "SEW-EURODRIVE"),
        ("id.danfoss.com", "Danfoss"),
        ("id.murrelektronik.com", "Murrelektronik"),
        ("id.turck.com", "Turck"),
        ("id.ifm.com", "ifm electronic"),
        ("id.pilz.com", "Pilz"),
        ("id.balluff.com", "Balluff"),
        ("id.pepperl-fuchs.com", "Pepperl+Fuchs")
    ]

    /// GS1 Application Identifier meanings
    private static let gs1ApplicationIdentifiers: [String: String] = [
        "01": "gtin",
        "10": "batchNumber",
        "21": "serialNumber",
        "22": "consumerProductVariant",
        "235": "thirdPartyControlledSerialNumber",
        "240": "additionalProductIdentification",
        "241": "customerPartNumber",
        "250": "secondarySerialNumber",
        "251": "referenceToSourceEntity",
        "30": "variableCount",
        "310": "productNetWeightKg",
        "8003": "grai",
        "8004": "giai"
    ]

    // MARK: - Public API

    /// Parse a scanned QR code string into an identification link.
    /// - Parameter code: The scanned QR code content
    /// - Returns: Parsed identification link, or nil if unparseable
    public static func parse(_ code: String) -> AssetIdentificationLink? {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            logger.debug("Empty QR code content")
            return nil
        }

        // Try URN parsing first so we don't treat URNs as generic URLs.
        if trimmed.lowercased().hasPrefix("urn:") {
            return parseURN(trimmed)
        }

        // Try URL-based parsing
        if let url = URL(string: trimmed), url.scheme != nil {
            return parseURL(url, originalString: trimmed)
        }

        // Try to detect if it's a known identifier format
        return parseRawIdentifier(trimmed)
    }

    /// Parse multiple QR codes (for multi-code assets).
    /// - Parameter codes: Array of scanned QR codes
    /// - Returns: Combined identification link
    public static func parseCombined(_ codes: [String]) -> AssetIdentificationLink? {
        let links = codes.compactMap { parse($0) }

        guard !links.isEmpty else { return nil }
        guard links.count > 1 else { return links.first }

        // Combine information from multiple QR codes
        return combineLinks(links)
    }

    // MARK: - URL Parsing

    private static func parseURL(_ url: URL, originalString: String) -> AssetIdentificationLink? {
        let host = url.host?.lowercased() ?? ""
        let path = url.path

        // Check for GS1 Digital Link
        if host.contains("id.gs1.org") || host.contains("gs1") {
            return parseGS1DigitalLink(url, originalString: originalString)
        }

        // Check for AAS direct link
        if path.contains("/shells/") || path.contains("/aas/") {
            return parseAASDirectLink(url, originalString: originalString)
        }

        // Check for digital nameplate pattern
        if path.lowercased().contains("nameplate") || path.lowercased().contains("digital-twin") {
            return parseDigitalNameplateLink(url, originalString: originalString)
        }

        // Check for known manufacturer patterns
        if let manufacturerLink = parseManufacturerLink(url, originalString: originalString) {
            return manufacturerLink
        }

        // Check for DIN SPEC 91406 pattern
        if isDINSpec91406(url) {
            return parseDINSpec91406Link(url, originalString: originalString)
        }

        // Generic URL parsing - extract what we can
        return parseGenericURL(url, originalString: originalString)
    }

    private static func parseGS1DigitalLink(_ url: URL, originalString: String) -> AssetIdentificationLink {
        logger.debug("Parsing GS1 Digital Link: \(url.absoluteString)")

        let path = url.path
        var extractedIds: [String: String] = [:]

        // Parse path segments for AI codes
        // Format: /01/gtin/21/serial etc.
        let segments = path.split(separator: "/").map { String($0) }
        var i = 0
        while i < segments.count - 1 {
            let ai = segments[i]
            let value = segments[i + 1]

            if let idName = gs1ApplicationIdentifiers[ai] {
                extractedIds[idName] = value
            }
            i += 2
        }

        // Also parse query parameters
        for (key, value) in url.queryParameters {
            if let idName = gs1ApplicationIdentifiers[key] {
                extractedIds[idName] = value
            }
        }

        let specificAssetIds = extractedIds.map { SpecificAssetId(name: $0.key, value: $0.value) }

        return AssetIdentificationLink(
            originalURL: url,
            originalString: originalString,
            linkType: .gs1DigitalLink,
            serialNumber: extractedIds["serialNumber"],
            partNumber: extractedIds["gtin"],
            batchNumber: extractedIds["batchNumber"],
            globalAssetId: url.absoluteString,
            specificAssetIds: specificAssetIds,
            confidence: 0.9
        )
    }

    private static func parseAASDirectLink(_ url: URL, originalString: String) -> AssetIdentificationLink {
        logger.debug("Parsing AAS Direct Link: \(url.absoluteString)")

        let path = url.path
        var aasId: String?

        // Extract AAS ID from path
        // Format: /shells/{base64url-encoded-id} or /aas/{id}
        if let range = path.range(of: "/shells/") {
            let remainder = String(path[range.upperBound...])
            aasId = remainder.split(separator: "/").first.map { String($0) }
            // Decode base64url if needed
            if let encoded = aasId {
                aasId = decodeAASIdentifier(encoded)
            }
        } else if let range = path.range(of: "/aas/") {
            let remainder = String(path[range.upperBound...])
            aasId = remainder.split(separator: "/").first.map { String($0) }
        }

        return AssetIdentificationLink(
            originalURL: url,
            originalString: originalString,
            linkType: .aasDirectLink,
            aasId: aasId,
            globalAssetId: aasId ?? url.absoluteString,
            specificAssetIds: [],
            confidence: 0.95
        )
    }

    private static func parseDigitalNameplateLink(_ url: URL, originalString: String) -> AssetIdentificationLink {
        logger.debug("Parsing Digital Nameplate Link: \(url.absoluteString)")

        let host = url.host ?? ""
        let path = url.path
        let query = url.queryParameters

        // Extract manufacturer from host
        let manufacturer = extractManufacturerFromHost(host)

        // Extract identifiers from path and query
        var serialNumber = query["serial"] ?? query["sn"] ?? query["serialNumber"]
        var partNumber = query["part"] ?? query["pn"] ?? query["partNumber"] ?? query["article"]
        let productFamily = query["family"] ?? query["product"]

        // Try to extract from path segments
        let segments = path.split(separator: "/").map { String($0) }
        for (index, segment) in segments.enumerated() {
            if segment.lowercased() == "sn" || segment.lowercased() == "serial" {
                if index + 1 < segments.count {
                    serialNumber = serialNumber ?? segments[index + 1]
                }
            }
            if segment.lowercased() == "pn" || segment.lowercased() == "part" {
                if index + 1 < segments.count {
                    partNumber = partNumber ?? segments[index + 1]
                }
            }
        }

        var specificAssetIds: [SpecificAssetId] = []
        if let sn = serialNumber {
            specificAssetIds.append(SpecificAssetId(name: "serialNumber", value: sn))
        }
        if let pn = partNumber {
            specificAssetIds.append(SpecificAssetId(name: "partNumber", value: pn))
        }

        return AssetIdentificationLink(
            originalURL: url,
            originalString: originalString,
            linkType: .digitalNameplate,
            manufacturer: manufacturer,
            productFamily: productFamily,
            serialNumber: serialNumber,
            partNumber: partNumber,
            globalAssetId: url.absoluteString,
            specificAssetIds: specificAssetIds,
            confidence: 0.85
        )
    }

    private static func parseManufacturerLink(_ url: URL, originalString: String) -> AssetIdentificationLink? {
        let host = url.host?.lowercased() ?? ""

        // Check known manufacturer patterns
        for (pattern, manufacturer) in manufacturerPatterns {
            if host.contains(pattern) {
                return parseKnownManufacturerLink(url, manufacturer: manufacturer, originalString: originalString)
            }
        }

        // Check for generic "id." prefix
        if host.hasPrefix("id.") {
            guard let manufacturer = extractManufacturerFromHost(host) else {
                return nil
            }
            return parseKnownManufacturerLink(url, manufacturer: manufacturer, originalString: originalString)
        }

        return nil
    }

    private static func parseKnownManufacturerLink(_ url: URL, manufacturer: String, originalString: String) -> AssetIdentificationLink {
        logger.debug("Parsing manufacturer link for \(manufacturer): \(url.absoluteString)")

        let path = url.path
        let query = url.queryParameters

        // Common manufacturer URL patterns:
        // /product/{family}/{serial}
        // /device/{type}/{serial}
        // /{serial}
        // ?serial=xxx&part=yyy

        let segments = path.split(separator: "/").map { String($0) }
            .filter { !$0.isEmpty }

        var serialNumber: String?
        var partNumber: String?
        var productFamily: String?

        // Extract from query parameters first (most reliable)
        serialNumber = query["serial"] ?? query["sn"] ?? query["serialNumber"] ?? query["SerialNumber"]
        partNumber = query["part"] ?? query["pn"] ?? query["partNumber"] ?? query["article"] ?? query["orderCode"]
        productFamily = query["family"] ?? query["product"] ?? query["type"]

        // Extract from path if not in query
        if segments.count >= 1 {
            // Last segment is often serial number
            if serialNumber == nil && looksLikeSerialNumber(segments.last ?? "") {
                serialNumber = segments.last
            }

            // Second to last might be product family
            if segments.count >= 2 {
                productFamily = productFamily ?? segments[segments.count - 2]
            }
        }

        var specificAssetIds: [SpecificAssetId] = []
        if let sn = serialNumber {
            specificAssetIds.append(SpecificAssetId(name: "serialNumber", value: sn))
        }
        if let pn = partNumber {
            specificAssetIds.append(SpecificAssetId(name: "partNumber", value: pn))
            specificAssetIds.append(SpecificAssetId(name: "manufacturerPartId", value: pn))
        }

        // Use URL as global asset ID (per IEC 61406)
        specificAssetIds.append(SpecificAssetId(name: "globalAssetId", value: url.absoluteString))

        return AssetIdentificationLink(
            originalURL: url,
            originalString: originalString,
            linkType: .manufacturerLink,
            manufacturer: manufacturer,
            productFamily: productFamily,
            serialNumber: serialNumber,
            partNumber: partNumber,
            globalAssetId: url.absoluteString,
            specificAssetIds: specificAssetIds,
            confidence: 0.9
        )
    }

    private static func parseDINSpec91406Link(_ url: URL, originalString: String) -> AssetIdentificationLink {
        logger.debug("Parsing DIN SPEC 91406 Link: \(url.absoluteString)")

        // DIN SPEC 91406 defines URL structure for machine-readable identification
        // Typically: https://id.company.com/product/serial

        let manufacturer = extractManufacturerFromHost(url.host ?? "")
        let segments = url.path.split(separator: "/").map { String($0) }

        var serialNumber: String?
        var productFamily: String?

        if !segments.isEmpty {
            serialNumber = segments.last
            if segments.count >= 2 {
                productFamily = segments[segments.count - 2]
            }
        }

        var specificAssetIds: [SpecificAssetId] = []
        if let sn = serialNumber {
            specificAssetIds.append(SpecificAssetId(name: "serialNumber", value: sn))
        }
        specificAssetIds.append(SpecificAssetId(name: "globalAssetId", value: url.absoluteString))

        return AssetIdentificationLink(
            originalURL: url,
            originalString: originalString,
            linkType: .dinSpec91406,
            manufacturer: manufacturer,
            productFamily: productFamily,
            serialNumber: serialNumber,
            globalAssetId: url.absoluteString,
            specificAssetIds: specificAssetIds,
            confidence: 0.8
        )
    }

    private static func parseGenericURL(_ url: URL, originalString: String) -> AssetIdentificationLink {
        logger.debug("Parsing generic URL: \(url.absoluteString)")

        let manufacturer = extractManufacturerFromHost(url.host ?? "")
        let query = url.queryParameters
        let segments = url.path.split(separator: "/").map { String($0) }

        // Try to extract any identifiers
        var serialNumber = query["serial"] ?? query["sn"] ?? query["id"]
        let partNumber = query["part"] ?? query["pn"] ?? query["article"]

        // Check last path segment
        if serialNumber == nil, let last = segments.last, looksLikeSerialNumber(last) {
            serialNumber = last
        }

        var specificAssetIds: [SpecificAssetId] = []
        if let sn = serialNumber {
            specificAssetIds.append(SpecificAssetId(name: "serialNumber", value: sn))
        }
        if let pn = partNumber {
            specificAssetIds.append(SpecificAssetId(name: "partNumber", value: pn))
        }
        specificAssetIds.append(SpecificAssetId(name: "globalAssetId", value: url.absoluteString))

        return AssetIdentificationLink(
            originalURL: url,
            originalString: originalString,
            linkType: .unknown,
            manufacturer: manufacturer,
            serialNumber: serialNumber,
            partNumber: partNumber,
            globalAssetId: url.absoluteString,
            specificAssetIds: specificAssetIds,
            confidence: 0.5
        )
    }

    // MARK: - URN Parsing

    private static func parseURN(_ urn: String) -> AssetIdentificationLink? {
        logger.debug("Parsing URN: \(urn)")

        // URN format: urn:nid:nss
        // Examples: urn:eclass:0173-1#01-AAA001#001
        //          urn:irdi:0112/2///61360_4#AAA001#001

        let components = urn.split(separator: ":").map { String($0) }
        guard components.count >= 3, components[0].lowercased() == "urn" else {
            return nil
        }

        let nid = components[1].lowercased()
        let nss = components[2...].joined(separator: ":")

        var linkType: IdentificationLinkType = .urnNid
        var specificAssetIds: [SpecificAssetId] = []

        // Handle specific URN namespaces
        switch nid {
        case "eclass":
            linkType = .eclassId
            specificAssetIds.append(SpecificAssetId(name: "eclassId", value: nss))
        case "irdi":
            specificAssetIds.append(SpecificAssetId(name: "irdi", value: nss))
        default:
            specificAssetIds.append(SpecificAssetId(name: "urn", value: urn))
        }

        specificAssetIds.append(SpecificAssetId(name: "globalAssetId", value: urn))

        return AssetIdentificationLink(
            originalURL: nil,
            originalString: urn,
            linkType: linkType,
            globalAssetId: urn,
            specificAssetIds: specificAssetIds,
            confidence: 0.85
        )
    }

    // MARK: - Raw Identifier Parsing

    private static func parseRawIdentifier(_ identifier: String) -> AssetIdentificationLink? {
        logger.debug("Parsing raw identifier: \(identifier)")

        // Check if it looks like a serial number
        if looksLikeSerialNumber(identifier) {
            return AssetIdentificationLink(
                originalURL: nil,
                originalString: identifier,
                linkType: .unknown,
                serialNumber: identifier,
                specificAssetIds: [SpecificAssetId(name: "serialNumber", value: identifier)],
                confidence: 0.6
            )
        }

        // Check for ECLASS pattern without URN prefix
        if identifier.contains("0173-1#") || identifier.contains("61360") {
            return AssetIdentificationLink(
                originalURL: nil,
                originalString: identifier,
                linkType: .eclassId,
                specificAssetIds: [
                    SpecificAssetId(name: "eclassId", value: identifier),
                    SpecificAssetId(name: "globalAssetId", value: identifier)
                ],
                confidence: 0.7
            )
        }

        // Generic - use as-is
        return AssetIdentificationLink(
            originalURL: nil,
            originalString: identifier,
            linkType: .unknown,
            globalAssetId: identifier,
            specificAssetIds: [SpecificAssetId(name: "globalAssetId", value: identifier)],
            confidence: 0.3
        )
    }

    // MARK: - Helpers

    private static func extractManufacturerFromHost(_ host: String) -> String? {
        // Remove common prefixes and suffixes
        var name = host
            .replacingOccurrences(of: "id.", with: "")
            .replacingOccurrences(of: "www.", with: "")
            .replacingOccurrences(of: ".com", with: "")
            .replacingOccurrences(of: ".de", with: "")
            .replacingOccurrences(of: ".io", with: "")
            .replacingOccurrences(of: ".org", with: "")

        // Capitalize first letter
        if !name.isEmpty {
            name = name.prefix(1).uppercased() + name.dropFirst()
        }

        return name.isEmpty ? nil : name
    }

    private static func looksLikeSerialNumber(_ string: String) -> Bool {
        // Serial numbers typically:
        // - Are 5-30 characters
        // - Contain alphanumeric characters
        // - May have dashes or dots
        // - Don't have spaces

        let length = string.count
        guard length >= 5 && length <= 30 else { return false }
        guard !string.contains(" ") else { return false }

        let alphanumeric = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._"))
        return string.unicodeScalars.allSatisfy { alphanumeric.contains($0) }
    }

    private static func isDINSpec91406(_ url: URL) -> Bool {
        let host = url.host?.lowercased() ?? ""
        return host.hasPrefix("id.") && url.path.count > 1
    }

    private static func decodeAASIdentifier(_ encoded: String) -> String {
        // Try base64url decoding
        var base64 = encoded
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        // Pad if needed
        let remainder = base64.count % 4
        if remainder > 0 {
            base64 += String(repeating: "=", count: 4 - remainder)
        }

        if let data = Data(base64Encoded: base64),
           let decoded = String(data: data, encoding: .utf8) {
            return decoded
        }

        // Return original if decoding fails
        return encoded
    }

    private static func combineLinks(_ links: [AssetIdentificationLink]) -> AssetIdentificationLink {
        // Combine information from multiple links
        var combinedIds: [SpecificAssetId] = []
        var serialNumber: String?
        var partNumber: String?
        var batchNumber: String?
        var manufacturer: String?
        var productFamily: String?
        var aasId: String?
        var globalAssetId: String?

        for link in links {
            combinedIds.append(contentsOf: link.specificAssetIds)
            serialNumber = serialNumber ?? link.serialNumber
            partNumber = partNumber ?? link.partNumber
            batchNumber = batchNumber ?? link.batchNumber
            manufacturer = manufacturer ?? link.manufacturer
            productFamily = productFamily ?? link.productFamily
            aasId = aasId ?? link.aasId
            globalAssetId = globalAssetId ?? link.globalAssetId
        }

        // Deduplicate specific asset IDs
        var seen = Set<String>()
        combinedIds = combinedIds.filter { id in
            let key = "\(id.name):\(id.value)"
            if seen.contains(key) { return false }
            seen.insert(key)
            return true
        }

        guard let primaryLink = links.first else {
            return AssetIdentificationLink(
                originalURL: nil,
                originalString: "",
                linkType: .unknown,
                confidence: 0.0
            )
        }

        return AssetIdentificationLink(
            originalURL: primaryLink.originalURL,
            originalString: links.map { $0.originalString }.joined(separator: "; "),
            linkType: primaryLink.linkType,
            manufacturer: manufacturer,
            productFamily: productFamily,
            serialNumber: serialNumber,
            partNumber: partNumber,
            batchNumber: batchNumber,
            aasId: aasId,
            globalAssetId: globalAssetId,
            specificAssetIds: combinedIds,
            confidence: min(1.0, primaryLink.confidence + 0.1)
        )
    }
}

// MARK: - URL Extension

extension URL {
    /// Parse query parameters into dictionary.
    var queryParameters: [String: String] {
        guard let components = URLComponents(url: self, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            return [:]
        }

        var params: [String: String] = [:]
        for item in queryItems {
            if let value = item.value {
                params[item.name] = value
            }
        }
        return params
    }
}

//
//  DataTypes.swift
//  TwinAct Field Companion
//
//  XSD data type definitions and value conversion utilities for AAS API v3.
//

import Foundation

// MARK: - XSD Data Types

/// XSD data types as defined in the AAS metamodel.
public enum DataTypeDefXsd: String, Codable, Sendable, CaseIterable {
    // String types
    case string = "xs:string"
    case anyURI = "xs:anyURI"
    case base64Binary = "xs:base64Binary"
    case hexBinary = "xs:hexBinary"

    // Numeric types - Integer
    case integer = "xs:integer"
    case int = "xs:int"
    case long = "xs:long"
    case short = "xs:short"
    case byte = "xs:byte"
    case nonNegativeInteger = "xs:nonNegativeInteger"
    case positiveInteger = "xs:positiveInteger"
    case nonPositiveInteger = "xs:nonPositiveInteger"
    case negativeInteger = "xs:negativeInteger"
    case unsignedLong = "xs:unsignedLong"
    case unsignedInt = "xs:unsignedInt"
    case unsignedShort = "xs:unsignedShort"
    case unsignedByte = "xs:unsignedByte"

    // Numeric types - Decimal/Float
    case decimal = "xs:decimal"
    case double = "xs:double"
    case float = "xs:float"

    // Boolean
    case boolean = "xs:boolean"

    // Date/Time types
    case dateTime = "xs:dateTime"
    case date = "xs:date"
    case time = "xs:time"
    case gYear = "xs:gYear"
    case gMonth = "xs:gMonth"
    case gDay = "xs:gDay"
    case gYearMonth = "xs:gYearMonth"
    case gMonthDay = "xs:gMonthDay"
    case duration = "xs:duration"
    case dayTimeDuration = "xs:dayTimeDuration"
    case yearMonthDuration = "xs:yearMonthDuration"

    /// Human-readable display name for the type.
    public var displayName: String {
        switch self {
        case .string: return "String"
        case .anyURI: return "URI"
        case .base64Binary: return "Base64 Binary"
        case .hexBinary: return "Hex Binary"
        case .integer: return "Integer"
        case .int: return "Int (32-bit)"
        case .long: return "Long (64-bit)"
        case .short: return "Short (16-bit)"
        case .byte: return "Byte (8-bit)"
        case .nonNegativeInteger: return "Non-Negative Integer"
        case .positiveInteger: return "Positive Integer"
        case .nonPositiveInteger: return "Non-Positive Integer"
        case .negativeInteger: return "Negative Integer"
        case .unsignedLong: return "Unsigned Long"
        case .unsignedInt: return "Unsigned Int"
        case .unsignedShort: return "Unsigned Short"
        case .unsignedByte: return "Unsigned Byte"
        case .decimal: return "Decimal"
        case .double: return "Double"
        case .float: return "Float"
        case .boolean: return "Boolean"
        case .dateTime: return "Date/Time"
        case .date: return "Date"
        case .time: return "Time"
        case .gYear: return "Year"
        case .gMonth: return "Month"
        case .gDay: return "Day"
        case .gYearMonth: return "Year/Month"
        case .gMonthDay: return "Month/Day"
        case .duration: return "Duration"
        case .dayTimeDuration: return "Day/Time Duration"
        case .yearMonthDuration: return "Year/Month Duration"
        }
    }

    /// Whether this type represents a numeric value.
    public var isNumeric: Bool {
        switch self {
        case .integer, .int, .long, .short, .byte,
             .nonNegativeInteger, .positiveInteger, .nonPositiveInteger, .negativeInteger,
             .unsignedLong, .unsignedInt, .unsignedShort, .unsignedByte,
             .decimal, .double, .float:
            return true
        default:
            return false
        }
    }

    /// Whether this type represents a date/time value.
    public var isDateTime: Bool {
        switch self {
        case .dateTime, .date, .time, .gYear, .gMonth, .gDay,
             .gYearMonth, .gMonthDay, .duration, .dayTimeDuration, .yearMonthDuration:
            return true
        default:
            return false
        }
    }
}

// MARK: - Value Conversion

/// Utilities for converting AAS property values.
public enum AASValueConverter {
    /// Convert a string value to the appropriate Swift type based on XSD type.
    public static func convert(_ stringValue: String?, to type: DataTypeDefXsd) -> Any? {
        guard let value = stringValue, !value.isEmpty else {
            return nil
        }

        switch type {
        case .string, .anyURI:
            return value

        case .base64Binary:
            return Data(base64Encoded: value)

        case .hexBinary:
            return Data(hexString: value)

        case .integer, .int, .long, .short, .byte,
             .nonNegativeInteger, .positiveInteger, .nonPositiveInteger, .negativeInteger:
            return Int(value)

        case .unsignedLong, .unsignedInt, .unsignedShort, .unsignedByte:
            return UInt(value)

        case .decimal, .double:
            return Double(value)

        case .float:
            return Float(value)

        case .boolean:
            return value.lowercased() == "true" || value == "1"

        case .dateTime:
            return ISO8601DateFormatter().date(from: value)

        case .date:
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter.date(from: value)

        case .time:
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss"
            return formatter.date(from: value)

        case .gYear:
            return Int(value)

        case .gMonth, .gDay, .gYearMonth, .gMonthDay:
            return value // Keep as string for complex date components

        case .duration, .dayTimeDuration, .yearMonthDuration:
            return parseDuration(value)
        }
    }

    /// Convert a Swift value to a string for AAS property storage.
    public static func toString(_ value: Any, type: DataTypeDefXsd) -> String {
        switch value {
        case let string as String:
            return string

        case let data as Data:
            if type == .base64Binary {
                return data.base64EncodedString()
            } else if type == .hexBinary {
                return data.hexString
            }
            return data.base64EncodedString()

        case let int as Int:
            return String(int)

        case let uint as UInt:
            return String(uint)

        case let double as Double:
            return String(double)

        case let float as Float:
            return String(float)

        case let bool as Bool:
            return bool ? "true" : "false"

        case let date as Date:
            if type == .dateTime {
                return ISO8601DateFormatter().string(from: date)
            } else if type == .date {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                return formatter.string(from: date)
            } else if type == .time {
                let formatter = DateFormatter()
                formatter.dateFormat = "HH:mm:ss"
                return formatter.string(from: date)
            }
            return ISO8601DateFormatter().string(from: date)

        case let timeInterval as TimeInterval:
            return formatDuration(timeInterval)

        default:
            return String(describing: value)
        }
    }

    // MARK: - Duration Parsing

    /// Parse ISO 8601 duration string to TimeInterval.
    private static func parseDuration(_ value: String) -> TimeInterval? {
        // Simple parser for ISO 8601 duration format: P[n]Y[n]M[n]DT[n]H[n]M[n]S
        guard value.hasPrefix("P") else { return nil }

        let remaining = String(value.dropFirst())
        var seconds: TimeInterval = 0

        // Check for time component
        let parts = remaining.split(separator: "T", maxSplits: 1)
        let datePart = String(parts[0])
        let timePart = parts.count > 1 ? String(parts[1]) : ""

        // Parse date components
        seconds += parseComponent(from: datePart, suffix: "Y") * 365.25 * 24 * 3600
        seconds += parseComponent(from: datePart, suffix: "M") * 30 * 24 * 3600
        seconds += parseComponent(from: datePart, suffix: "D") * 24 * 3600

        // Parse time components
        seconds += parseComponent(from: timePart, suffix: "H") * 3600
        seconds += parseComponent(from: timePart, suffix: "M") * 60
        seconds += parseComponent(from: timePart, suffix: "S")

        return seconds
    }

    private static func parseComponent(from string: String, suffix: String) -> TimeInterval {
        guard let range = string.range(of: "[0-9.]+\(suffix)", options: .regularExpression) else {
            return 0
        }
        let match = String(string[range])
        let numberString = String(match.dropLast())
        return TimeInterval(numberString) ?? 0
    }

    /// Format TimeInterval as ISO 8601 duration string.
    private static func formatDuration(_ interval: TimeInterval) -> String {
        var remaining = interval
        var result = "P"

        let days = Int(remaining / (24 * 3600))
        remaining -= TimeInterval(days) * 24 * 3600
        if days > 0 { result += "\(days)D" }

        let hours = Int(remaining / 3600)
        remaining -= TimeInterval(hours) * 3600
        let minutes = Int(remaining / 60)
        remaining -= TimeInterval(minutes) * 60
        let seconds = remaining

        if hours > 0 || minutes > 0 || seconds > 0 {
            result += "T"
            if hours > 0 { result += "\(hours)H" }
            if minutes > 0 { result += "\(minutes)M" }
            if seconds > 0 { result += "\(Int(seconds))S" }
        }

        return result == "P" ? "PT0S" : result
    }
}

// MARK: - Data Extensions

extension Data {
    /// Initialize from hex string.
    init?(hexString: String) {
        let hex = hexString.replacingOccurrences(of: " ", with: "")
        guard hex.count % 2 == 0 else { return nil }

        var data = Data()
        var index = hex.startIndex
        while index < hex.endIndex {
            let nextIndex = hex.index(index, offsetBy: 2)
            let byteString = String(hex[index..<nextIndex])
            guard let byte = UInt8(byteString, radix: 16) else { return nil }
            data.append(byte)
            index = nextIndex
        }
        self = data
    }

    /// Convert to hex string.
    var hexString: String {
        map { String(format: "%02x", $0) }.joined()
    }
}

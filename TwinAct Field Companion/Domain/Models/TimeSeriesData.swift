//
//  TimeSeriesData.swift
//  TwinAct Field Companion
//
//  Time Series Data domain model per IDTA 02008.
//  Sensor and measurement data.
//  READ ONLY - This submodel cannot be modified by the app.
//

import Foundation

// MARK: - Time Series Data

/// Time Series Data per IDTA 02008
/// Contains sensor and measurement data records.
/// This is a read-only submodel.
public struct TimeSeriesData: Codable, Sendable, Hashable {
    /// Time series data records
    public let records: [TimeSeriesRecord]

    /// Metadata about the time series
    public let metadata: TimeSeriesMetadata

    public init(records: [TimeSeriesRecord], metadata: TimeSeriesMetadata) {
        self.records = records
        self.metadata = metadata
    }

    /// Get records within a time range
    public func records(from startDate: Date, to endDate: Date) -> [TimeSeriesRecord] {
        records.filter { $0.timestamp >= startDate && $0.timestamp <= endDate }
    }

    /// Get the latest record
    public var latestRecord: TimeSeriesRecord? {
        records.max(by: { $0.timestamp < $1.timestamp })
    }

    /// Get values for a specific property across all records
    public func values(for property: String) -> [(Date, Double)] {
        records.compactMap { record in
            guard let value = record.values[property] else { return nil }
            return (record.timestamp, value)
        }
    }

    /// Calculate statistics for a property
    public func statistics(for property: String) -> TimeSeriesStatistics? {
        let propertyValues = records.compactMap { $0.values[property] }
        guard !propertyValues.isEmpty else { return nil }

        let sum = propertyValues.reduce(0, +)
        let mean = sum / Double(propertyValues.count)
        let sortedValues = propertyValues.sorted()
        let min = sortedValues.first ?? 0
        let max = sortedValues.last ?? 0
        let median = sortedValues[sortedValues.count / 2]

        // Calculate standard deviation
        let squaredDiffs = propertyValues.map { pow($0 - mean, 2) }
        let variance = squaredDiffs.reduce(0, +) / Double(propertyValues.count)
        let stdDev = sqrt(variance)

        return TimeSeriesStatistics(
            count: propertyValues.count,
            min: min,
            max: max,
            mean: mean,
            median: median,
            standardDeviation: stdDev
        )
    }
}

// MARK: - Time Series Record

/// A single time series data record.
public struct TimeSeriesRecord: Codable, Sendable, Hashable {
    /// Timestamp of the record
    public let timestamp: Date

    /// Values keyed by property name
    public let values: [String: Double]

    /// Quality indicator (if available)
    public let quality: DataQuality?

    public init(
        timestamp: Date,
        values: [String: Double],
        quality: DataQuality? = nil
    ) {
        self.timestamp = timestamp
        self.values = values
        self.quality = quality
    }

    /// Get a formatted timestamp string
    public var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter.string(from: timestamp)
    }
}

// MARK: - Time Series Metadata

/// Metadata describing a time series.
public struct TimeSeriesMetadata: Codable, Sendable, Hashable {
    /// Name of the time series
    public let name: String

    /// Description in multiple languages
    public let description: [LangString]?

    /// Start time of the series
    public let startTime: Date?

    /// End time of the series
    public let endTime: Date?

    /// Sampling interval in seconds
    public let samplingInterval: Double?

    /// Segments within the time series
    public let segments: [TimeSeriesSegment]?

    /// Unit of measurement for values
    public let unit: String?

    /// Properties/variables recorded in this time series
    public let properties: [TimeSeriesProperty]?

    /// Source of the data (e.g., sensor ID)
    public let source: String?

    public init(
        name: String,
        description: [LangString]? = nil,
        startTime: Date? = nil,
        endTime: Date? = nil,
        samplingInterval: Double? = nil,
        segments: [TimeSeriesSegment]? = nil,
        unit: String? = nil,
        properties: [TimeSeriesProperty]? = nil,
        source: String? = nil
    ) {
        self.name = name
        self.description = description
        self.startTime = startTime
        self.endTime = endTime
        self.samplingInterval = samplingInterval
        self.segments = segments
        self.unit = unit
        self.properties = properties
        self.source = source
    }

    /// Duration of the time series
    public var duration: TimeInterval? {
        guard let start = startTime, let end = endTime else { return nil }
        return end.timeIntervalSince(start)
    }

    /// Formatted duration string
    public var formattedDuration: String? {
        guard let duration = duration else { return nil }

        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.day, .hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: duration)
    }

    /// Formatted sampling rate string
    public var formattedSamplingRate: String? {
        guard let interval = samplingInterval, interval > 0 else { return nil }

        if interval < 1 {
            return "\(Int(1.0 / interval)) Hz"
        } else if interval < 60 {
            return "Every \(Int(interval)) sec"
        } else if interval < 3600 {
            return "Every \(Int(interval / 60)) min"
        } else {
            return "Every \(Int(interval / 3600)) hr"
        }
    }
}

// MARK: - Time Series Segment

/// A segment or phase within a time series.
public struct TimeSeriesSegment: Codable, Sendable, Hashable {
    /// Segment name
    public let name: String

    /// Segment description
    public let description: [LangString]?

    /// Machine/process state during this segment
    public let state: String?

    /// Duration of the segment in seconds
    public let duration: Double?

    /// Start time of the segment
    public let startTime: Date?

    /// End time of the segment
    public let endTime: Date?

    public init(
        name: String,
        description: [LangString]? = nil,
        state: String? = nil,
        duration: Double? = nil,
        startTime: Date? = nil,
        endTime: Date? = nil
    ) {
        self.name = name
        self.description = description
        self.state = state
        self.duration = duration
        self.startTime = startTime
        self.endTime = endTime
    }
}

// MARK: - Time Series Property

/// Description of a property/variable in the time series.
public struct TimeSeriesProperty: Codable, Sendable, Hashable {
    /// Property name/identifier
    public let name: String

    /// Property description
    public let description: [LangString]?

    /// Unit of measurement
    public let unit: String?

    /// Data type
    public let dataType: String?

    /// Minimum expected value
    public let minValue: Double?

    /// Maximum expected value
    public let maxValue: Double?

    public init(
        name: String,
        description: [LangString]? = nil,
        unit: String? = nil,
        dataType: String? = nil,
        minValue: Double? = nil,
        maxValue: Double? = nil
    ) {
        self.name = name
        self.description = description
        self.unit = unit
        self.dataType = dataType
        self.minValue = minValue
        self.maxValue = maxValue
    }
}

// MARK: - Data Quality

/// Quality indicator for time series data.
public enum DataQuality: String, Codable, Sendable, CaseIterable {
    case good
    case uncertain
    case bad
    case missing

    /// Human-readable display name
    public var displayName: String {
        switch self {
        case .good: return "Good"
        case .uncertain: return "Uncertain"
        case .bad: return "Bad"
        case .missing: return "Missing"
        }
    }

    /// SF Symbol icon name
    public var iconName: String {
        switch self {
        case .good: return "checkmark.circle.fill"
        case .uncertain: return "questionmark.circle.fill"
        case .bad: return "xmark.circle.fill"
        case .missing: return "minus.circle.fill"
        }
    }
}

// MARK: - Time Series Statistics

/// Calculated statistics for a time series property.
public struct TimeSeriesStatistics: Codable, Sendable, Hashable {
    /// Number of data points
    public let count: Int

    /// Minimum value
    public let min: Double

    /// Maximum value
    public let max: Double

    /// Mean/average value
    public let mean: Double

    /// Median value
    public let median: Double

    /// Standard deviation
    public let standardDeviation: Double

    /// Range (max - min)
    public var range: Double {
        max - min
    }
}

// MARK: - IDTA Semantic IDs

extension TimeSeriesData {
    /// IDTA semantic ID for Time Series Data submodel
    public static let semanticId = "https://admin-shell.io/idta/TimeSeries/1/1/Submodel"

    /// Alternative semantic ID (version 1.0)
    public static let semanticIdV1 = "https://admin-shell.io/idta/TimeSeries/1/0/Submodel"
}

//
//  MaintenanceInstructions.swift
//  TwinAct Field Companion
//
//  Maintenance Instructions domain model per IDTA 02018.
//  Maintenance procedures and schedules.
//  READ ONLY - This submodel cannot be modified by the app.
//

import Foundation

// MARK: - Maintenance Instructions

/// Maintenance Instructions per IDTA 02018
/// Contains maintenance procedures and schedules.
/// This is a read-only submodel.
public struct MaintenanceInstructions: Codable, Sendable, Hashable {
    /// Collection of maintenance instructions
    public let instructions: [MaintenanceInstruction]

    public init(instructions: [MaintenanceInstruction] = []) {
        self.instructions = instructions
    }

    /// Get instructions filtered by type
    public func instructions(ofType type: MaintenanceType) -> [MaintenanceInstruction] {
        instructions.filter { $0.maintenanceType == type }
    }

    /// Get overdue maintenance instructions based on last performed date
    public func overdueInstructions(lastPerformed: [String: Date]) -> [MaintenanceInstruction] {
        let now = Date()
        return instructions.filter { instruction in
            guard let lastDate = lastPerformed[instruction.id],
                  let interval = instruction.intervalInSeconds else {
                return false
            }
            return now.timeIntervalSince(lastDate) > interval
        }
    }
}

// MARK: - Maintenance Instruction

/// A single maintenance instruction with steps and requirements.
public struct MaintenanceInstruction: Codable, Sendable, Hashable, Identifiable {
    /// Unique instruction identifier
    public let id: String

    /// Title of the maintenance instruction
    public let title: [LangString]

    /// Detailed description
    public let description: [LangString]?

    /// Type of maintenance
    public let maintenanceType: MaintenanceType

    /// Interval value (numeric)
    public let intervalValue: Double?

    /// Interval unit (hours, days, cycles, etc.)
    public let intervalUnit: String?

    /// Step-by-step instructions
    public let steps: [MaintenanceStep]?

    /// Required tools for this maintenance
    public let requiredTools: [String]?

    /// Required spare parts
    public let requiredParts: [String]?

    /// Safety instructions to follow
    public let safetyInstructions: [LangString]?

    /// Estimated duration in minutes
    public let estimatedDuration: Int?

    /// Required skill level
    public let skillLevel: SkillLevel?

    /// Applicable conditions (temperature, pressure, etc.)
    public let conditions: [MaintenanceCondition]?

    public init(
        id: String,
        title: [LangString],
        description: [LangString]? = nil,
        maintenanceType: MaintenanceType,
        intervalValue: Double? = nil,
        intervalUnit: String? = nil,
        steps: [MaintenanceStep]? = nil,
        requiredTools: [String]? = nil,
        requiredParts: [String]? = nil,
        safetyInstructions: [LangString]? = nil,
        estimatedDuration: Int? = nil,
        skillLevel: SkillLevel? = nil,
        conditions: [MaintenanceCondition]? = nil
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.maintenanceType = maintenanceType
        self.intervalValue = intervalValue
        self.intervalUnit = intervalUnit
        self.steps = steps
        self.requiredTools = requiredTools
        self.requiredParts = requiredParts
        self.safetyInstructions = safetyInstructions
        self.estimatedDuration = estimatedDuration
        self.skillLevel = skillLevel
        self.conditions = conditions
    }

    /// Get title for a specific language
    public func title(for languageCode: String) -> String? {
        title.text(for: languageCode)
    }

    /// Get description for a specific language
    public func description(for languageCode: String) -> String? {
        description?.text(for: languageCode)
    }

    /// Calculate interval in seconds for comparison
    public var intervalInSeconds: TimeInterval? {
        guard let value = intervalValue, let unit = intervalUnit?.lowercased() else {
            return nil
        }

        switch unit {
        case "seconds", "s":
            return value
        case "minutes", "min":
            return value * 60
        case "hours", "h":
            return value * 3600
        case "days", "d":
            return value * 86400
        case "weeks", "w":
            return value * 604800
        case "months", "m":
            return value * 2592000  // 30 days
        case "years", "y":
            return value * 31536000  // 365 days
        case "cycles":
            return nil  // Cycles cannot be converted to time
        default:
            return nil
        }
    }

    /// Formatted interval string (e.g., "Every 500 hours")
    public var formattedInterval: String? {
        guard let value = intervalValue, let unit = intervalUnit else {
            return nil
        }
        return "Every \(Int(value)) \(unit)"
    }
}

// MARK: - Maintenance Type

/// Type of maintenance activity.
public enum MaintenanceType: String, Codable, Sendable, CaseIterable {
    /// Scheduled preventive maintenance
    case preventive

    /// Repair after failure
    case corrective

    /// Based on predicted failure
    case predictive

    /// Based on measured conditions
    case conditionBased

    /// Human-readable display name
    public var displayName: String {
        switch self {
        case .preventive: return "Preventive"
        case .corrective: return "Corrective"
        case .predictive: return "Predictive"
        case .conditionBased: return "Condition-Based"
        }
    }

    /// SF Symbol icon name
    public var iconName: String {
        switch self {
        case .preventive: return "calendar.badge.clock"
        case .corrective: return "wrench.fill"
        case .predictive: return "chart.line.uptrend.xyaxis"
        case .conditionBased: return "gauge.with.dots.needle.33percent"
        }
    }
}

// MARK: - Maintenance Step

/// A single step in a maintenance procedure.
public struct MaintenanceStep: Codable, Sendable, Hashable {
    /// Step number in sequence
    public let stepNumber: Int

    /// Step description
    public let description: [LangString]

    /// URL to step image
    public let image: URL?

    /// URL to step video
    public let video: URL?

    /// Warning messages for this step
    public let warnings: [LangString]?

    /// Expected duration for this step in minutes
    public let duration: Int?

    /// Whether this step is critical/mandatory
    public let isCritical: Bool?

    /// Verification/checkpoint description
    public let verification: [LangString]?

    public init(
        stepNumber: Int,
        description: [LangString],
        image: URL? = nil,
        video: URL? = nil,
        warnings: [LangString]? = nil,
        duration: Int? = nil,
        isCritical: Bool? = nil,
        verification: [LangString]? = nil
    ) {
        self.stepNumber = stepNumber
        self.description = description
        self.image = image
        self.video = video
        self.warnings = warnings
        self.duration = duration
        self.isCritical = isCritical
        self.verification = verification
    }

    /// Get description for a specific language
    public func description(for languageCode: String) -> String? {
        description.text(for: languageCode)
    }

    /// Get warnings for a specific language
    public func warnings(for languageCode: String) -> [String] {
        warnings?.compactMap { $0.text } ?? []
    }
}

// MARK: - Skill Level

/// Required skill level for maintenance tasks.
public enum SkillLevel: String, Codable, Sendable, CaseIterable {
    case basic
    case intermediate
    case advanced
    case specialist

    /// Human-readable display name
    public var displayName: String {
        switch self {
        case .basic: return "Basic"
        case .intermediate: return "Intermediate"
        case .advanced: return "Advanced"
        case .specialist: return "Specialist"
        }
    }
}

// MARK: - Maintenance Condition

/// Condition that must be met before or during maintenance.
public struct MaintenanceCondition: Codable, Sendable, Hashable {
    /// Condition name/parameter
    public let name: String

    /// Required value or range
    public let value: String

    /// Unit of measurement
    public let unit: String?

    public init(name: String, value: String, unit: String? = nil) {
        self.name = name
        self.value = value
        self.unit = unit
    }
}

// MARK: - IDTA Semantic IDs

extension MaintenanceInstructions {
    /// IDTA semantic ID for Maintenance submodel
    public static let semanticId = "https://admin-shell.io/idta/Maintenance/1/0/Submodel"
}

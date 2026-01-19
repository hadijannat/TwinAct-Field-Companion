//
//  AROverlayViewModel.swift
//  TwinAct Field Companion
//
//  View model for AR overlay data and state management.
//  Handles creation and management of AR overlay entities.
//

import SwiftUI
import RealityKit
import Combine

// MARK: - AR Overlay

/// Represents an AR overlay in the scene.
public struct AROverlay: Identifiable {
    public let id: UUID
    public let type: AROverlayType
    public let position: SIMD3<Float>
    public let entity: RealityKit.Entity?

    /// Title for the overlay
    public var title: String {
        switch type {
        case .sensorValue(let propertyName, _, _):
            return propertyName
        case .maintenanceStep(let stepNumber, _):
            return "Step \(stepNumber)"
        case .warning:
            return "Warning"
        case .information(let title, _):
            return title
        }
    }

    /// Detail text for the overlay
    public var detailText: String {
        switch type {
        case .sensorValue(_, let value, let unit):
            return "\(value) \(unit)"
        case .maintenanceStep(_, let description):
            return description
        case .warning(let message):
            return message
        case .information(_, let details):
            return details
        }
    }

    /// Icon name for the overlay type
    public var iconName: String {
        switch type {
        case .sensorValue:
            return "gauge.with.needle.fill"
        case .maintenanceStep:
            return "checklist"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .information:
            return "info.circle.fill"
        }
    }

    /// Status color for the overlay
    public var statusColor: Color {
        switch type {
        case .sensorValue(_, _, _):
            return .blue
        case .maintenanceStep:
            return .orange
        case .warning:
            return .red
        case .information:
            return .green
        }
    }

    /// Warning message if applicable
    public var warning: String? {
        switch type {
        case .warning(let message):
            return message
        default:
            return nil
        }
    }

    public init(
        id: UUID = UUID(),
        type: AROverlayType,
        position: SIMD3<Float>,
        entity: RealityKit.Entity? = nil
    ) {
        self.id = id
        self.type = type
        self.position = position
        self.entity = entity
    }
}

// MARK: - AR Overlay Type

/// Types of AR overlays that can be displayed.
public enum AROverlayType: Equatable {
    /// Sensor value display
    case sensorValue(propertyName: String, value: String, unit: String)

    /// Maintenance procedure step
    case maintenanceStep(stepNumber: Int, description: String)

    /// Warning indicator
    case warning(message: String)

    /// General information
    case information(title: String, details: String)
}

// MARK: - AR Overlay View Model

/// View model managing AR overlay state and creation.
@MainActor
public final class AROverlayViewModel: ObservableObject {
    // MARK: - Published Properties

    /// All active overlays in the scene
    @Published public var overlays: [AROverlay] = []

    /// Currently selected overlay
    @Published public var selectedOverlay: AROverlay?

    /// Whether labels are visible
    @Published public var showLabels = true

    /// Whether in placement mode
    @Published public var isPlacementMode = false

    /// Current maintenance step being displayed
    @Published public var currentMaintenanceStep: Int?

    /// Total maintenance steps available
    @Published public var totalMaintenanceSteps: Int?

    // MARK: - Private Properties

    private let asset: Asset
    private let timeSeriesData: TimeSeriesData?
    private let maintenanceInstructions: MaintenanceInstructions?
    private var sessionManager: ARSessionManager?
    private var overlayEntities: [UUID: RealityKit.Entity] = [:]
    private var mainAnchor: AnchorEntity?

    // MARK: - Initialization

    /// Initialize the view model.
    /// - Parameters:
    ///   - asset: The asset to create overlays for
    ///   - timeSeriesData: Optional time series data for sensor overlays
    ///   - maintenanceInstructions: Optional maintenance instructions for procedure overlays
    public init(
        asset: Asset,
        timeSeriesData: TimeSeriesData? = nil,
        maintenanceInstructions: MaintenanceInstructions? = nil
    ) {
        self.asset = asset
        self.timeSeriesData = timeSeriesData
        self.maintenanceInstructions = maintenanceInstructions

        if let instructions = maintenanceInstructions {
            self.totalMaintenanceSteps = instructions.instructions.first?.steps?.count
            if totalMaintenanceSteps != nil && totalMaintenanceSteps! > 0 {
                self.currentMaintenanceStep = 1
            }
        }
    }

    // MARK: - Session Management

    /// Attach to an AR session manager.
    /// - Parameter sessionManager: The session manager to attach to
    public func attachToSession(_ sessionManager: ARSessionManager) {
        self.sessionManager = sessionManager
    }

    // MARK: - Overlay Management

    /// Place overlays on an anchor.
    /// - Parameter anchor: The anchor to place overlays on
    public func placeOverlays(on anchor: AnchorEntity) {
        mainAnchor = anchor

        if let data = timeSeriesData {
            let sensorOverlays = createSensorOverlays(from: data)
            addOverlaysToScene(sensorOverlays, on: anchor)
        }

        if maintenanceInstructions != nil,
           let step = currentMaintenanceStep {
            let procedureOverlays = createMaintenanceOverlays(for: step)
            addOverlaysToScene(procedureOverlays, on: anchor)
        }
    }

    /// Place a single overlay at a position.
    /// - Parameter position: The world position for the overlay
    public func placeOverlay(at position: SIMD3<Float>) {
        guard let sessionManager = sessionManager else { return }

        let anchor = sessionManager.addAnchor(at: position)
        if let anchor = anchor {
            placeOverlays(on: anchor)
        }

        isPlacementMode = false
    }

    /// Clear all overlays from the scene.
    public func clearOverlays() {
        for (_, entity) in overlayEntities {
            entity.removeFromParent()
        }
        overlayEntities.removeAll()
        overlays.removeAll()
        mainAnchor = nil
    }

    /// Toggle label visibility.
    public func toggleLabels() {
        showLabels.toggle()

        for (_, entity) in overlayEntities {
            entity.isEnabled = showLabels
        }
    }

    /// Select an overlay at a screen position.
    /// - Parameters:
    ///   - point: The screen point
    ///   - arView: The AR view for hit testing
    public func selectOverlay(at point: CGPoint, in arView: ARView) {
        let results = arView.hitTest(point)

        for result in results {
            if let entityId = overlayEntities.first(where: { $0.value === result.entity || $0.value.children.contains(result.entity) })?.key {
                selectedOverlay = overlays.first { $0.id == entityId }
                return
            }
        }

        // Tapped empty space
        selectedOverlay = nil
    }

    // MARK: - Maintenance Step Navigation

    /// Move to the previous maintenance step.
    public func previousMaintenanceStep() {
        guard let current = currentMaintenanceStep, current > 1 else { return }
        currentMaintenanceStep = current - 1
        updateMaintenanceOverlays()
    }

    /// Move to the next maintenance step.
    public func nextMaintenanceStep() {
        guard let current = currentMaintenanceStep,
              let total = totalMaintenanceSteps,
              current < total else { return }
        currentMaintenanceStep = current + 1
        updateMaintenanceOverlays()
    }

    private func updateMaintenanceOverlays() {
        guard let anchor = mainAnchor,
              let step = currentMaintenanceStep else { return }

        // Remove old procedure overlays
        let procedureOverlayIds = overlays.filter {
            if case .maintenanceStep = $0.type { return true }
            return false
        }.map { $0.id }

        for id in procedureOverlayIds {
            if let entity = overlayEntities.removeValue(forKey: id) {
                entity.removeFromParent()
            }
        }
        overlays.removeAll { procedureOverlayIds.contains($0.id) }

        // Add new procedure overlays
        let newOverlays = createMaintenanceOverlays(for: step)
        addOverlaysToScene(newOverlays, on: anchor)
    }

    // MARK: - Overlay Creation

    /// Create sensor value overlays from time series data.
    /// - Parameter data: The time series data
    /// - Returns: Array of AR overlays
    public func createSensorOverlays(from data: TimeSeriesData) -> [AROverlay] {
        guard let latestRecord = data.latestRecord else { return [] }

        var overlays: [AROverlay] = []
        var offset: Float = 0

        for (propertyName, value) in latestRecord.values {
            let property = data.metadata.properties?.first { $0.name == propertyName }
            let unit = property?.unit ?? data.metadata.unit ?? ""
            let formattedValue = formatValue(value, decimals: 2)

            // Check if value is out of range
            var overlayType: AROverlayType = .sensorValue(
                propertyName: propertyName,
                value: formattedValue,
                unit: unit
            )

            if let minValue = property?.minValue, value < minValue {
                overlayType = .warning(message: "\(propertyName) below minimum: \(formattedValue) \(unit)")
            } else if let maxValue = property?.maxValue, value > maxValue {
                overlayType = .warning(message: "\(propertyName) above maximum: \(formattedValue) \(unit)")
            }

            let position = SIMD3<Float>(0, 0.1 + offset, 0)
            let overlay = AROverlay(type: overlayType, position: position)
            overlays.append(overlay)
            offset += 0.08
        }

        return overlays
    }

    /// Create maintenance procedure overlays for a specific step.
    /// - Parameter stepNumber: The step number to display
    /// - Returns: Array of AR overlays
    public func createMaintenanceOverlays(for stepNumber: Int) -> [AROverlay] {
        guard let instructions = maintenanceInstructions,
              let instruction = instructions.instructions.first,
              let steps = instruction.steps else {
            return []
        }

        var overlays: [AROverlay] = []

        // Get the current step
        guard stepNumber > 0 && stepNumber <= steps.count else { return [] }
        let step = steps[stepNumber - 1]

        let description = step.description(for: "en") ?? "Step \(stepNumber)"

        let overlay = AROverlay(
            type: .maintenanceStep(stepNumber: stepNumber, description: description),
            position: SIMD3<Float>(0, 0.15, 0)
        )
        overlays.append(overlay)

        // Add warning overlay if step has warnings
        if let warnings = step.warnings, !warnings.isEmpty {
            let warningText = warnings.compactMap { $0.text }.joined(separator: "; ")
            let warningOverlay = AROverlay(
                type: .warning(message: warningText),
                position: SIMD3<Float>(0, 0.25, 0)
            )
            overlays.append(warningOverlay)
        }

        return overlays
    }

    // MARK: - Entity Creation

    private func addOverlaysToScene(_ newOverlays: [AROverlay], on anchor: AnchorEntity) {
        for overlay in newOverlays {
            let entity = createEntity(for: overlay)
            entity.position = overlay.position

            anchor.addChild(entity)
            overlayEntities[overlay.id] = entity

            overlays.append(AROverlay(
                id: overlay.id,
                type: overlay.type,
                position: overlay.position,
                entity: entity
            ))
        }
    }

    private func createEntity(for overlay: AROverlay) -> RealityKit.Entity {
        switch overlay.type {
        case .sensorValue(let propertyName, let value, let unit):
            return ARSensorOverlay.createEntity(
                propertyName: propertyName,
                value: value,
                unit: unit
            )

        case .maintenanceStep(let stepNumber, let description):
            return ARProcedureOverlay.createStepEntity(
                stepNumber: stepNumber,
                description: description,
                isCurrentStep: true
            )

        case .warning(let message):
            return ARSensorOverlay.createWarningEntity(message: message)

        case .information(let title, let details):
            return ARSensorOverlay.createInfoEntity(title: title, details: details)
        }
    }

    // MARK: - Helpers

    private func formatValue(_ value: Double, decimals: Int) -> String {
        return String(format: "%.\(decimals)f", value)
    }
}

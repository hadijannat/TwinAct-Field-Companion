//
//  ARSensorOverlay.swift
//  TwinAct Field Companion
//
//  Creates 3D sensor value overlay entities for AR display.
//  Supports floating labels, value cards, and warning indicators.
//

import RealityKit
import UIKit

// MARK: - AR Sensor Overlay

/// Factory for creating sensor value overlay entities.
public struct ARSensorOverlay {

    // MARK: - Text Entity Creation

    /// Create a text-based sensor value entity.
    /// - Parameters:
    ///   - propertyName: The sensor property name
    ///   - value: The current value as a string
    ///   - unit: The unit of measurement
    ///   - color: The text color (default: system blue)
    /// - Returns: A configured Entity
    public static func createEntity(
        propertyName: String,
        value: String,
        unit: String,
        color: UIColor = .systemBlue
    ) -> RealityKit.Entity {
        let container = RealityKit.Entity()

        // Create background card
        let cardEntity = createCardBackground(
            width: 0.12,
            height: 0.04,
            color: UIColor.white.withAlphaComponent(0.9)
        )
        container.addChild(cardEntity)

        // Create text mesh for the label
        let labelText = "\(propertyName)"
        let labelMesh = MeshResource.generateText(
            labelText,
            extrusionDepth: 0.001,
            font: .systemFont(ofSize: 0.008, weight: .medium),
            containerFrame: .zero,
            alignment: .center,
            lineBreakMode: .byTruncatingTail
        )
        let labelMaterial = SimpleMaterial(color: .darkGray, isMetallic: false)
        let labelEntity = ModelEntity(mesh: labelMesh, materials: [labelMaterial])
        labelEntity.position = SIMD3<Float>(-0.05, 0.008, 0.001)
        container.addChild(labelEntity)

        // Create text mesh for the value
        let valueText = "\(value) \(unit)"
        let valueMesh = MeshResource.generateText(
            valueText,
            extrusionDepth: 0.001,
            font: .systemFont(ofSize: 0.012, weight: .bold),
            containerFrame: .zero,
            alignment: .center,
            lineBreakMode: .byTruncatingTail
        )
        let valueMaterial = SimpleMaterial(color: color, isMetallic: false)
        let valueEntity = ModelEntity(mesh: valueMesh, materials: [valueMaterial])
        valueEntity.position = SIMD3<Float>(-0.05, -0.008, 0.001)
        container.addChild(valueEntity)

        // Add billboard component to always face camera
        addBillboardBehavior(to: container)

        return container
    }

    /// Create a value card with status indicator.
    /// - Parameters:
    ///   - name: The property name
    ///   - value: The numeric value
    ///   - unit: The unit of measurement
    ///   - normalRange: Optional range for normal values (determines status color)
    /// - Returns: A configured Entity
    public static func createValueCard(
        name: String,
        value: Double,
        unit: String,
        normalRange: ClosedRange<Double>? = nil
    ) -> RealityKit.Entity {
        let isNormal = normalRange?.contains(value) ?? true
        let statusColor: UIColor = isNormal ? .systemGreen : .systemRed

        let container = RealityKit.Entity()

        // Create larger background card
        let cardEntity = createCardBackground(
            width: 0.15,
            height: 0.06,
            color: UIColor.white.withAlphaComponent(0.95)
        )
        container.addChild(cardEntity)

        // Status indicator circle
        let statusMesh = MeshResource.generateSphere(radius: 0.004)
        let statusMaterial = SimpleMaterial(color: statusColor, isMetallic: false)
        let statusEntity = ModelEntity(mesh: statusMesh, materials: [statusMaterial])
        statusEntity.position = SIMD3<Float>(-0.06, 0.015, 0.002)
        container.addChild(statusEntity)

        // Property name label
        let nameMesh = MeshResource.generateText(
            name,
            extrusionDepth: 0.001,
            font: .systemFont(ofSize: 0.008, weight: .medium),
            containerFrame: .zero,
            alignment: .left,
            lineBreakMode: .byTruncatingTail
        )
        let nameMaterial = SimpleMaterial(color: .darkGray, isMetallic: false)
        let nameEntity = ModelEntity(mesh: nameMesh, materials: [nameMaterial])
        nameEntity.position = SIMD3<Float>(-0.05, 0.012, 0.002)
        container.addChild(nameEntity)

        // Value display
        let formattedValue = String(format: "%.2f", value)
        let valueText = "\(formattedValue) \(unit)"
        let valueMesh = MeshResource.generateText(
            valueText,
            extrusionDepth: 0.001,
            font: .systemFont(ofSize: 0.014, weight: .bold),
            containerFrame: .zero,
            alignment: .left,
            lineBreakMode: .byTruncatingTail
        )
        let valueMaterial = SimpleMaterial(color: statusColor, isMetallic: false)
        let valueEntity = ModelEntity(mesh: valueMesh, materials: [valueMaterial])
        valueEntity.position = SIMD3<Float>(-0.06, -0.008, 0.002)
        container.addChild(valueEntity)

        // Range indicator (if provided)
        if let range = normalRange {
            let rangeText = "Range: \(String(format: "%.1f", range.lowerBound)) - \(String(format: "%.1f", range.upperBound))"
            let rangeMesh = MeshResource.generateText(
                rangeText,
                extrusionDepth: 0.0005,
                font: .systemFont(ofSize: 0.005, weight: .regular),
                containerFrame: .zero,
                alignment: .left,
                lineBreakMode: .byTruncatingTail
            )
            let rangeMaterial = SimpleMaterial(color: .gray, isMetallic: false)
            let rangeEntity = ModelEntity(mesh: rangeMesh, materials: [rangeMaterial])
            rangeEntity.position = SIMD3<Float>(-0.06, -0.022, 0.002)
            container.addChild(rangeEntity)
        }

        addBillboardBehavior(to: container)

        return container
    }

    /// Create a warning indicator entity.
    /// - Parameter message: The warning message
    /// - Returns: A configured Entity
    public static func createWarningEntity(message: String) -> RealityKit.Entity {
        let container = RealityKit.Entity()

        // Warning background (red-tinted)
        let cardEntity = createCardBackground(
            width: 0.14,
            height: 0.045,
            color: UIColor.systemRed.withAlphaComponent(0.15)
        )
        container.addChild(cardEntity)

        // Warning border
        let borderEntity = createCardBorder(
            width: 0.14,
            height: 0.045,
            color: UIColor.systemRed
        )
        container.addChild(borderEntity)

        // Warning icon (triangle with exclamation)
        let iconMesh = MeshResource.generateBox(size: 0.008)
        let iconMaterial = SimpleMaterial(color: UIColor.systemOrange, isMetallic: false)
        let iconEntity = ModelEntity(mesh: iconMesh, materials: [iconMaterial])
        iconEntity.position = SIMD3<Float>(-0.06, 0, 0.002)
        container.addChild(iconEntity)

        // Warning text
        let truncatedMessage = String(message.prefix(30))
        let textMesh = MeshResource.generateText(
            truncatedMessage,
            extrusionDepth: 0.001,
            font: .systemFont(ofSize: 0.007, weight: .semibold),
            containerFrame: .zero,
            alignment: .left,
            lineBreakMode: .byTruncatingTail
        )
        let textMaterial = SimpleMaterial(color: UIColor.systemRed, isMetallic: false)
        let textEntity = ModelEntity(mesh: textMesh, materials: [textMaterial])
        textEntity.position = SIMD3<Float>(-0.05, -0.003, 0.002)
        container.addChild(textEntity)

        addBillboardBehavior(to: container)

        return container
    }

    /// Create an information entity.
    /// - Parameters:
    ///   - title: The information title
    ///   - details: The detail text
    /// - Returns: A configured Entity
    public static func createInfoEntity(title: String, details: String) -> RealityKit.Entity {
        let container = RealityKit.Entity()

        // Info background
        let cardEntity = createCardBackground(
            width: 0.14,
            height: 0.05,
            color: UIColor.systemBlue.withAlphaComponent(0.1)
        )
        container.addChild(cardEntity)

        // Info icon
        let iconMesh = MeshResource.generateSphere(radius: 0.004)
        let iconMaterial = SimpleMaterial(color: .systemBlue, isMetallic: false)
        let iconEntity = ModelEntity(mesh: iconMesh, materials: [iconMaterial])
        iconEntity.position = SIMD3<Float>(-0.06, 0.012, 0.002)
        container.addChild(iconEntity)

        // Title
        let titleMesh = MeshResource.generateText(
            title,
            extrusionDepth: 0.001,
            font: .systemFont(ofSize: 0.008, weight: .bold),
            containerFrame: .zero,
            alignment: .left,
            lineBreakMode: .byTruncatingTail
        )
        let titleMaterial = SimpleMaterial(color: .systemBlue, isMetallic: false)
        let titleEntity = ModelEntity(mesh: titleMesh, materials: [titleMaterial])
        titleEntity.position = SIMD3<Float>(-0.05, 0.01, 0.002)
        container.addChild(titleEntity)

        // Details
        let truncatedDetails = String(details.prefix(40))
        let detailsMesh = MeshResource.generateText(
            truncatedDetails,
            extrusionDepth: 0.001,
            font: .systemFont(ofSize: 0.006, weight: .regular),
            containerFrame: .zero,
            alignment: .left,
            lineBreakMode: .byTruncatingTail
        )
        let detailsMaterial = SimpleMaterial(color: .darkGray, isMetallic: false)
        let detailsEntity = ModelEntity(mesh: detailsMesh, materials: [detailsMaterial])
        detailsEntity.position = SIMD3<Float>(-0.06, -0.008, 0.002)
        container.addChild(detailsEntity)

        addBillboardBehavior(to: container)

        return container
    }

    // MARK: - Helper Methods

    /// Create a card background entity.
    private static func createCardBackground(
        width: Float,
        height: Float,
        color: UIColor
    ) -> RealityKit.Entity {
        let mesh = MeshResource.generatePlane(width: width, depth: height, cornerRadius: 0.005)
        var material = SimpleMaterial()
        material.color = .init(tint: color)
        let entity = ModelEntity(mesh: mesh, materials: [material])
        entity.transform.rotation = simd_quatf(angle: -.pi / 2, axis: SIMD3<Float>(1, 0, 0))
        return entity
    }

    /// Create a card border entity.
    private static func createCardBorder(
        width: Float,
        height: Float,
        color: UIColor
    ) -> RealityKit.Entity {
        // Create a thin box as border
        let thickness: Float = 0.002
        let container = RealityKit.Entity()

        // Top border
        let topMesh = MeshResource.generateBox(size: SIMD3<Float>(width, thickness, 0.001))
        let topEntity = ModelEntity(mesh: topMesh, materials: [SimpleMaterial(color: color, isMetallic: false)])
        topEntity.position = SIMD3<Float>(0, height / 2, 0.001)
        container.addChild(topEntity)

        // Bottom border
        let bottomEntity = ModelEntity(mesh: topMesh, materials: [SimpleMaterial(color: color, isMetallic: false)])
        bottomEntity.position = SIMD3<Float>(0, -height / 2, 0.001)
        container.addChild(bottomEntity)

        // Left border
        let sideMesh = MeshResource.generateBox(size: SIMD3<Float>(thickness, height, 0.001))
        let leftEntity = ModelEntity(mesh: sideMesh, materials: [SimpleMaterial(color: color, isMetallic: false)])
        leftEntity.position = SIMD3<Float>(-width / 2, 0, 0.001)
        container.addChild(leftEntity)

        // Right border
        let rightEntity = ModelEntity(mesh: sideMesh, materials: [SimpleMaterial(color: color, isMetallic: false)])
        rightEntity.position = SIMD3<Float>(width / 2, 0, 0.001)
        container.addChild(rightEntity)

        return container
    }

    /// Add billboard behavior to make entity always face the camera.
    private static func addBillboardBehavior(to entity: RealityKit.Entity) {
        // RealityKit 2+ supports BillboardComponent
        // For older versions, this needs to be handled via session updates
        #if swift(>=5.5)
        if #available(iOS 15.0, *) {
            entity.components.set(BillboardComponent())
        }
        #endif
    }
}

// MARK: - Gauge Overlay

extension ARSensorOverlay {
    /// Create a circular gauge entity for a value.
    /// - Parameters:
    ///   - name: The gauge label
    ///   - value: The current value
    ///   - minValue: The minimum value
    ///   - maxValue: The maximum value
    ///   - unit: The unit of measurement
    /// - Returns: A configured Entity
    public static func createGaugeEntity(
        name: String,
        value: Double,
        minValue: Double,
        maxValue: Double,
        unit: String
    ) -> RealityKit.Entity {
        let container = RealityKit.Entity()

        // Background circle
        let bgMesh = MeshResource.generatePlane(width: 0.08, depth: 0.08, cornerRadius: 0.04)
        var bgMaterial = SimpleMaterial()
        bgMaterial.color = .init(tint: UIColor.white.withAlphaComponent(0.9))
        let bgEntity = ModelEntity(mesh: bgMesh, materials: [bgMaterial])
        bgEntity.transform.rotation = simd_quatf(angle: -.pi / 2, axis: SIMD3<Float>(1, 0, 0))
        container.addChild(bgEntity)

        // Calculate percentage
        let percentage = (value - minValue) / (maxValue - minValue)
        let clampedPercentage = max(0, min(1, percentage))

        // Progress indicator (simplified as arc approximation)
        let progressColor: UIColor
        if clampedPercentage < 0.3 {
            progressColor = .systemRed
        } else if clampedPercentage < 0.7 {
            progressColor = .systemOrange
        } else {
            progressColor = .systemGreen
        }

        // Inner progress ring (simplified)
        let ringMesh = MeshResource.generatePlane(
            width: Float(0.06 * clampedPercentage),
            depth: 0.01,
            cornerRadius: 0.005
        )
        var ringMaterial = SimpleMaterial()
        ringMaterial.color = .init(tint: progressColor)
        let ringEntity = ModelEntity(mesh: ringMesh, materials: [ringMaterial])
        ringEntity.transform.rotation = simd_quatf(angle: -.pi / 2, axis: SIMD3<Float>(1, 0, 0))
        ringEntity.position = SIMD3<Float>(0, -0.015, 0.001)
        container.addChild(ringEntity)

        // Value text
        let formattedValue = String(format: "%.1f", value)
        let valueMesh = MeshResource.generateText(
            formattedValue,
            extrusionDepth: 0.001,
            font: .systemFont(ofSize: 0.015, weight: .bold),
            containerFrame: .zero,
            alignment: .center,
            lineBreakMode: .byTruncatingTail
        )
        let valueMaterial = SimpleMaterial(color: progressColor, isMetallic: false)
        let valueEntity = ModelEntity(mesh: valueMesh, materials: [valueMaterial])
        valueEntity.position = SIMD3<Float>(-0.02, 0.005, 0.002)
        container.addChild(valueEntity)

        // Unit text
        let unitMesh = MeshResource.generateText(
            unit,
            extrusionDepth: 0.0005,
            font: .systemFont(ofSize: 0.006, weight: .regular),
            containerFrame: .zero,
            alignment: .center,
            lineBreakMode: .byTruncatingTail
        )
        let unitMaterial = SimpleMaterial(color: .gray, isMetallic: false)
        let unitEntity = ModelEntity(mesh: unitMesh, materials: [unitMaterial])
        unitEntity.position = SIMD3<Float>(-0.01, -0.005, 0.002)
        container.addChild(unitEntity)

        // Name label
        let nameMesh = MeshResource.generateText(
            name,
            extrusionDepth: 0.0005,
            font: .systemFont(ofSize: 0.005, weight: .medium),
            containerFrame: .zero,
            alignment: .center,
            lineBreakMode: .byTruncatingTail
        )
        let nameMaterial = SimpleMaterial(color: .darkGray, isMetallic: false)
        let nameEntity = ModelEntity(mesh: nameMesh, materials: [nameMaterial])
        nameEntity.position = SIMD3<Float>(-0.02, 0.028, 0.002)
        container.addChild(nameEntity)

        addBillboardBehavior(to: container)

        return container
    }
}

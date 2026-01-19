//
//  ARProcedureOverlay.swift
//  TwinAct Field Companion
//
//  Creates 3D maintenance procedure overlay entities for AR display.
//  Supports step indicators, directional arrows, and highlight boxes.
//

import RealityKit
import UIKit

// MARK: - AR Procedure Overlay

/// Factory for creating maintenance procedure overlay entities.
public struct ARProcedureOverlay {

    // MARK: - Step Entity Creation

    /// Create a maintenance step indicator entity.
    /// - Parameters:
    ///   - stepNumber: The step number
    ///   - description: The step description text
    ///   - isCurrentStep: Whether this is the currently active step
    /// - Returns: A configured Entity
    public static func createStepEntity(
        stepNumber: Int,
        description: String,
        isCurrentStep: Bool
    ) -> Entity {
        let container = Entity()

        let primaryColor: UIColor = isCurrentStep ? .systemOrange : .systemGray
        let backgroundColor: UIColor = isCurrentStep
            ? UIColor.systemOrange.withAlphaComponent(0.15)
            : UIColor.systemGray.withAlphaComponent(0.1)

        // Background card
        let cardEntity = createStepCard(
            width: 0.18,
            height: 0.06,
            color: backgroundColor,
            borderColor: primaryColor
        )
        container.addChild(cardEntity)

        // Step number circle
        let circleEntity = createStepNumberCircle(
            number: stepNumber,
            color: primaryColor,
            isActive: isCurrentStep
        )
        circleEntity.position = SIMD3<Float>(-0.07, 0.015, 0.003)
        container.addChild(circleEntity)

        // Step label
        if let labelMesh = try? MeshResource.generateText(
            "Step \(stepNumber)",
            extrusionDepth: 0.001,
            font: .systemFont(ofSize: 0.007, weight: .semibold),
            containerFrame: .zero,
            alignment: .left,
            lineBreakMode: .byTruncatingTail
        ) {
            let labelMaterial = SimpleMaterial(color: primaryColor, isMetallic: false)
            let labelEntity = ModelEntity(mesh: labelMesh, materials: [labelMaterial])
            labelEntity.position = SIMD3<Float>(-0.055, 0.012, 0.003)
            container.addChild(labelEntity)
        }

        // Description text (truncated to fit)
        let truncatedDescription = String(description.prefix(50))
        if let descMesh = try? MeshResource.generateText(
            truncatedDescription,
            extrusionDepth: 0.001,
            font: .systemFont(ofSize: 0.006, weight: .regular),
            containerFrame: .zero,
            alignment: .left,
            lineBreakMode: .byTruncatingTail
        ) {
            let descMaterial = SimpleMaterial(color: .darkGray, isMetallic: false)
            let descEntity = ModelEntity(mesh: descMesh, materials: [descMaterial])
            descEntity.position = SIMD3<Float>(-0.08, -0.008, 0.003)
            container.addChild(descEntity)
        }

        // Current step indicator (pulsing effect via larger highlight)
        if isCurrentStep {
            let highlightEntity = createPulseIndicator(color: primaryColor)
            highlightEntity.position = SIMD3<Float>(-0.07, 0.015, 0.001)
            container.addChild(highlightEntity)
        }

        // Add billboard behavior
        addBillboardBehavior(to: container)

        return container
    }

    /// Create a directional arrow entity.
    /// - Parameters:
    ///   - from: Starting position
    ///   - to: Ending position
    ///   - color: Arrow color
    /// - Returns: A configured Entity
    public static func createArrow(
        from startPosition: SIMD3<Float>,
        to endPosition: SIMD3<Float>,
        color: UIColor = .systemYellow
    ) -> Entity {
        let container = Entity()

        // Calculate direction and length
        let direction = endPosition - startPosition
        let length = simd_length(direction)
        let normalizedDirection = simd_normalize(direction)

        // Create arrow shaft
        let shaftLength = length - 0.02 // Leave room for arrowhead
        let shaftMesh = MeshResource.generateBox(size: SIMD3<Float>(0.003, 0.003, shaftLength))
        let shaftMaterial = SimpleMaterial(color: color, isMetallic: false)
        let shaftEntity = ModelEntity(mesh: shaftMesh, materials: [shaftMaterial])

        // Position shaft at midpoint
        let midpoint = startPosition + normalizedDirection * (shaftLength / 2)
        shaftEntity.position = midpoint

        // Rotate to point in direction
        let rotation = simd_quatf(from: SIMD3<Float>(0, 0, 1), to: normalizedDirection)
        shaftEntity.transform.rotation = rotation

        container.addChild(shaftEntity)

        // Create arrowhead (cone approximation using cylinder)
        let arrowheadMesh = MeshResource.generateCone(height: 0.02, radius: 0.008)
        let arrowheadMaterial = SimpleMaterial(color: color, isMetallic: false)
        let arrowheadEntity = ModelEntity(mesh: arrowheadMesh, materials: [arrowheadMaterial])

        // Position arrowhead at end
        arrowheadEntity.position = endPosition - normalizedDirection * 0.01
        arrowheadEntity.transform.rotation = rotation

        container.addChild(arrowheadEntity)

        return container
    }

    /// Create a highlight box for drawing attention to an area.
    /// - Parameters:
    ///   - center: The center position of the box
    ///   - size: The dimensions of the box
    ///   - color: The highlight color
    /// - Returns: A configured Entity
    public static func createHighlightBox(
        center: SIMD3<Float>,
        size: SIMD3<Float>,
        color: UIColor = .systemYellow
    ) -> Entity {
        let container = Entity()
        container.position = center

        // Semi-transparent fill
        let fillMesh = MeshResource.generateBox(size: size)
        var fillMaterial = SimpleMaterial()
        fillMaterial.color = .init(tint: color.withAlphaComponent(0.2))
        let fillEntity = ModelEntity(mesh: fillMesh, materials: [fillMaterial])
        container.addChild(fillEntity)

        // Wireframe edges (simplified as corner markers)
        let edgeColor = color.withAlphaComponent(0.8)
        let edgeMaterial = SimpleMaterial(color: edgeColor, isMetallic: false)
        let cornerSize: Float = 0.005

        // Add corner markers at each corner
        let halfSize = size / 2
        let corners: [SIMD3<Float>] = [
            SIMD3<Float>(-halfSize.x, -halfSize.y, -halfSize.z),
            SIMD3<Float>(-halfSize.x, -halfSize.y, halfSize.z),
            SIMD3<Float>(-halfSize.x, halfSize.y, -halfSize.z),
            SIMD3<Float>(-halfSize.x, halfSize.y, halfSize.z),
            SIMD3<Float>(halfSize.x, -halfSize.y, -halfSize.z),
            SIMD3<Float>(halfSize.x, -halfSize.y, halfSize.z),
            SIMD3<Float>(halfSize.x, halfSize.y, -halfSize.z),
            SIMD3<Float>(halfSize.x, halfSize.y, halfSize.z)
        ]

        let cornerMesh = MeshResource.generateSphere(radius: cornerSize)
        for corner in corners {
            let cornerEntity = ModelEntity(mesh: cornerMesh, materials: [edgeMaterial])
            cornerEntity.position = corner
            container.addChild(cornerEntity)
        }

        return container
    }

    /// Create a checklist item entity.
    /// - Parameters:
    ///   - text: The checklist item text
    ///   - isCompleted: Whether the item is completed
    /// - Returns: A configured Entity
    public static func createChecklistItem(
        text: String,
        isCompleted: Bool
    ) -> Entity {
        let container = Entity()

        // Checkbox
        let checkboxColor: UIColor = isCompleted ? .systemGreen : .systemGray
        let checkboxMesh = MeshResource.generateBox(size: SIMD3<Float>(0.008, 0.008, 0.001))
        let checkboxMaterial = SimpleMaterial(color: checkboxColor, isMetallic: false)
        let checkboxEntity = ModelEntity(mesh: checkboxMesh, materials: [checkboxMaterial])
        checkboxEntity.position = SIMD3<Float>(-0.06, 0, 0.001)
        container.addChild(checkboxEntity)

        // Checkmark (if completed)
        if isCompleted {
            let checkMesh = MeshResource.generateBox(size: SIMD3<Float>(0.004, 0.004, 0.002))
            let checkMaterial = SimpleMaterial(color: .white, isMetallic: false)
            let checkEntity = ModelEntity(mesh: checkMesh, materials: [checkMaterial])
            checkEntity.position = SIMD3<Float>(-0.06, 0, 0.002)
            container.addChild(checkEntity)
        }

        // Text
        let textColor: UIColor = isCompleted ? .systemGreen : .darkGray
        let truncatedText = String(text.prefix(35))
        if let textMesh = try? MeshResource.generateText(
            truncatedText,
            extrusionDepth: 0.001,
            font: .systemFont(ofSize: 0.007, weight: isCompleted ? .regular : .medium),
            containerFrame: .zero,
            alignment: .left,
            lineBreakMode: .byTruncatingTail
        ) {
            let textMaterial = SimpleMaterial(color: textColor, isMetallic: false)
            let textEntity = ModelEntity(mesh: textMesh, materials: [textMaterial])
            textEntity.position = SIMD3<Float>(-0.05, -0.003, 0.001)

            // Strike-through effect for completed items (simplified)
            if isCompleted {
                textEntity.transform.scale = SIMD3<Float>(1, 0.9, 1)
            }

            container.addChild(textEntity)
        }

        addBillboardBehavior(to: container)

        return container
    }

    /// Create a procedure checklist with multiple items.
    /// - Parameters:
    ///   - items: Array of (text, isCompleted) tuples
    ///   - title: Optional title for the checklist
    /// - Returns: A configured Entity
    public static func createChecklist(
        items: [(text: String, isCompleted: Bool)],
        title: String? = nil
    ) -> Entity {
        let container = Entity()
        var yOffset: Float = 0

        // Title
        if let title = title {
            if let titleMesh = try? MeshResource.generateText(
                title,
                extrusionDepth: 0.001,
                font: .systemFont(ofSize: 0.01, weight: .bold),
                containerFrame: .zero,
                alignment: .left,
                lineBreakMode: .byTruncatingTail
            ) {
                let titleMaterial = SimpleMaterial(color: .systemOrange, isMetallic: false)
                let titleEntity = ModelEntity(mesh: titleMesh, materials: [titleMaterial])
                titleEntity.position = SIMD3<Float>(-0.06, yOffset, 0.001)
                container.addChild(titleEntity)
                yOffset -= 0.02
            }
        }

        // Items
        for (text, isCompleted) in items {
            let itemEntity = createChecklistItem(text: text, isCompleted: isCompleted)
            itemEntity.position = SIMD3<Float>(0, yOffset, 0)
            container.addChild(itemEntity)
            yOffset -= 0.015
        }

        // Background
        let bgHeight = abs(yOffset) + 0.02
        let bgMesh = MeshResource.generatePlane(width: 0.14, depth: bgHeight, cornerRadius: 0.005)
        var bgMaterial = SimpleMaterial()
        bgMaterial.color = .init(tint: UIColor.white.withAlphaComponent(0.9))
        let bgEntity = ModelEntity(mesh: bgMesh, materials: [bgMaterial])
        bgEntity.transform.rotation = simd_quatf(angle: -.pi / 2, axis: SIMD3<Float>(1, 0, 0))
        bgEntity.position = SIMD3<Float>(0, yOffset / 2, -0.001)
        container.addChild(bgEntity)

        addBillboardBehavior(to: container)

        return container
    }

    // MARK: - Tool Indicator

    /// Create a required tool indicator.
    /// - Parameters:
    ///   - toolName: The name of the required tool
    ///   - isAvailable: Whether the tool is available/ready
    /// - Returns: A configured Entity
    public static func createToolIndicator(
        toolName: String,
        isAvailable: Bool
    ) -> Entity {
        let container = Entity()

        let statusColor: UIColor = isAvailable ? .systemGreen : .systemRed
        let iconColor: UIColor = .systemBlue

        // Background
        let bgMesh = MeshResource.generatePlane(width: 0.1, depth: 0.025, cornerRadius: 0.003)
        var bgMaterial = SimpleMaterial()
        bgMaterial.color = .init(tint: UIColor.white.withAlphaComponent(0.9))
        let bgEntity = ModelEntity(mesh: bgMesh, materials: [bgMaterial])
        bgEntity.transform.rotation = simd_quatf(angle: -.pi / 2, axis: SIMD3<Float>(1, 0, 0))
        container.addChild(bgEntity)

        // Tool icon (wrench)
        let iconMesh = MeshResource.generateBox(size: SIMD3<Float>(0.006, 0.006, 0.001))
        let iconMaterial = SimpleMaterial(color: iconColor, isMetallic: false)
        let iconEntity = ModelEntity(mesh: iconMesh, materials: [iconMaterial])
        iconEntity.position = SIMD3<Float>(-0.04, 0, 0.002)
        container.addChild(iconEntity)

        // Tool name
        let truncatedName = String(toolName.prefix(15))
        if let nameMesh = try? MeshResource.generateText(
            truncatedName,
            extrusionDepth: 0.001,
            font: .systemFont(ofSize: 0.006, weight: .medium),
            containerFrame: .zero,
            alignment: .left,
            lineBreakMode: .byTruncatingTail
        ) {
            let nameMaterial = SimpleMaterial(color: .darkGray, isMetallic: false)
            let nameEntity = ModelEntity(mesh: nameMesh, materials: [nameMaterial])
            nameEntity.position = SIMD3<Float>(-0.03, -0.002, 0.002)
            container.addChild(nameEntity)
        }

        // Status indicator
        let statusMesh = MeshResource.generateSphere(radius: 0.003)
        let statusMaterial = SimpleMaterial(color: statusColor, isMetallic: false)
        let statusEntity = ModelEntity(mesh: statusMesh, materials: [statusMaterial])
        statusEntity.position = SIMD3<Float>(0.04, 0, 0.002)
        container.addChild(statusEntity)

        addBillboardBehavior(to: container)

        return container
    }

    // MARK: - Helper Methods

    /// Create a step card background with border.
    private static func createStepCard(
        width: Float,
        height: Float,
        color: UIColor,
        borderColor: UIColor
    ) -> Entity {
        let container = Entity()

        // Background
        let bgMesh = MeshResource.generatePlane(width: width, depth: height, cornerRadius: 0.008)
        var bgMaterial = SimpleMaterial()
        bgMaterial.color = .init(tint: color)
        let bgEntity = ModelEntity(mesh: bgMesh, materials: [bgMaterial])
        bgEntity.transform.rotation = simd_quatf(angle: -.pi / 2, axis: SIMD3<Float>(1, 0, 0))
        container.addChild(bgEntity)

        // Left accent bar
        let accentMesh = MeshResource.generateBox(size: SIMD3<Float>(0.004, height - 0.01, 0.001))
        let accentMaterial = SimpleMaterial(color: borderColor, isMetallic: false)
        let accentEntity = ModelEntity(mesh: accentMesh, materials: [accentMaterial])
        accentEntity.position = SIMD3<Float>(-width / 2 + 0.005, 0, 0.002)
        container.addChild(accentEntity)

        return container
    }

    /// Create a step number circle.
    private static func createStepNumberCircle(
        number: Int,
        color: UIColor,
        isActive: Bool
    ) -> Entity {
        let container = Entity()

        // Circle background
        let circleMesh = MeshResource.generatePlane(width: 0.018, depth: 0.018, cornerRadius: 0.009)
        var circleMaterial = SimpleMaterial()
        circleMaterial.color = .init(tint: isActive ? color : color.withAlphaComponent(0.3))
        let circleEntity = ModelEntity(mesh: circleMesh, materials: [circleMaterial])
        circleEntity.transform.rotation = simd_quatf(angle: -.pi / 2, axis: SIMD3<Float>(1, 0, 0))
        container.addChild(circleEntity)

        // Number text
        if let numberMesh = try? MeshResource.generateText(
            "\(number)",
            extrusionDepth: 0.001,
            font: .systemFont(ofSize: 0.01, weight: .bold),
            containerFrame: .zero,
            alignment: .center,
            lineBreakMode: .byTruncatingTail
        ) {
            let numberMaterial = SimpleMaterial(color: .white, isMetallic: false)
            let numberEntity = ModelEntity(mesh: numberMesh, materials: [numberMaterial])
            numberEntity.position = SIMD3<Float>(-0.003, -0.004, 0.002)
            container.addChild(numberEntity)
        }

        return container
    }

    /// Create a pulse indicator for the current step.
    private static func createPulseIndicator(color: UIColor) -> Entity {
        let mesh = MeshResource.generatePlane(width: 0.025, depth: 0.025, cornerRadius: 0.0125)
        var material = SimpleMaterial()
        material.color = .init(tint: color.withAlphaComponent(0.3))
        let entity = ModelEntity(mesh: mesh, materials: [material])
        entity.transform.rotation = simd_quatf(angle: -.pi / 2, axis: SIMD3<Float>(1, 0, 0))
        return entity
    }

    /// Add billboard behavior to make entity always face the camera.
    private static func addBillboardBehavior(to entity: Entity) {
        #if swift(>=5.5)
        if #available(iOS 15.0, *) {
            entity.components.set(BillboardComponent())
        }
        #endif
    }
}

// MARK: - Cone Mesh Extension

extension MeshResource {
    /// Generate a cone mesh (approximation for arrowheads).
    static func generateCone(height: Float, radius: Float) -> MeshResource {
        // Approximate cone with a thin cylinder
        return MeshResource.generateCylinder(height: height, radius: radius)
    }
}

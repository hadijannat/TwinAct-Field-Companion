//
//  ARSessionManager.swift
//  TwinAct Field Companion
//
//  Manages ARKit session lifecycle for AR overlays.
//  Handles tracking state, plane detection, and session control.
//

import ARKit
import RealityKit
import Combine

// MARK: - AR Mode

/// Operating modes for AR session.
public enum ARMode: String, CaseIterable, Sendable {
    /// Display sensor values overlaid on physical asset
    case sensorOverlay

    /// Display maintenance procedure steps in AR
    case maintenanceProcedure

    /// General asset inspection mode
    case assetInspection

    /// Human-readable display name
    public var displayName: String {
        switch self {
        case .sensorOverlay: return "Sensor Overlay"
        case .maintenanceProcedure: return "Maintenance Procedure"
        case .assetInspection: return "Asset Inspection"
        }
    }

    /// SF Symbol icon name
    public var iconName: String {
        switch self {
        case .sensorOverlay: return "sensor.fill"
        case .maintenanceProcedure: return "wrench.and.screwdriver"
        case .assetInspection: return "eye.fill"
        }
    }
}

// MARK: - AR Error

/// Errors that can occur during AR sessions.
public enum ARError: Error, LocalizedError {
    case cameraAccessDenied
    case deviceNotSupported
    case worldTrackingNotSupported
    case sessionFailed(Error)
    case anchorCreationFailed

    public var errorDescription: String? {
        switch self {
        case .cameraAccessDenied:
            return "Camera access is required for AR features. Please enable camera access in Settings."
        case .deviceNotSupported:
            return "This device does not support AR features."
        case .worldTrackingNotSupported:
            return "World tracking is not supported on this device."
        case .sessionFailed(let error):
            return "AR session failed: \(error.localizedDescription)"
        case .anchorCreationFailed:
            return "Failed to create AR anchor at the specified location."
        }
    }
}

// MARK: - AR Session Manager

/// Manages ARKit session lifecycle and state.
@MainActor
public final class ARSessionManager: NSObject, ObservableObject {
    // MARK: - Published Properties

    /// Whether the AR session is currently running
    @Published public var isSessionRunning = false

    /// Current camera tracking state
    @Published public var trackingState: ARCamera.TrackingState = .notAvailable

    /// Detected horizontal and vertical planes
    @Published public var detectedPlanes: [UUID: ARPlaneAnchor] = [:]

    /// Current AR error, if any
    @Published public var error: ARError?

    /// Current AR mode
    @Published public var currentMode: ARMode = .assetInspection

    /// Whether plane visualization is enabled
    @Published public var showPlaneVisualization = false

    // MARK: - AR View

    /// The RealityKit AR view
    public let arView: ARView

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()
    private var planeEntities: [UUID: ModelEntity] = [:]

    // MARK: - Initialization

    public override init() {
        self.arView = ARView(frame: .zero)
        super.init()
        setupARView()
    }

    private func setupARView() {
        arView.session.delegate = self
        arView.environment.sceneUnderstanding.options = []

        // Configure rendering options
        arView.renderOptions = [
            .disablePersonOcclusion,
            .disableDepthOfField,
            .disableMotionBlur
        ]
    }

    // MARK: - Session Control

    /// Start the AR session with specified mode.
    /// - Parameter mode: The AR operating mode
    public func startSession(mode: ARMode) {
        guard ARWorldTrackingConfiguration.isSupported else {
            error = .worldTrackingNotSupported
            return
        }

        currentMode = mode

        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        configuration.environmentTexturing = .automatic

        // Enable scene reconstruction on supported devices
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            configuration.sceneReconstruction = .mesh
        }

        // Enable frame semantics for people occlusion on supported devices
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.personSegmentationWithDepth) {
            configuration.frameSemantics.insert(.personSegmentationWithDepth)
        }

        arView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        isSessionRunning = true
        error = nil
    }

    /// Pause the AR session.
    public func pauseSession() {
        arView.session.pause()
        isSessionRunning = false
    }

    /// Resume the AR session with current configuration.
    public func resumeSession() {
        guard let configuration = arView.session.configuration else {
            startSession(mode: currentMode)
            return
        }

        arView.session.run(configuration)
        isSessionRunning = true
    }

    /// Reset the AR session, clearing all anchors and tracking.
    public func resetSession() {
        guard let configuration = arView.session.configuration else {
            startSession(mode: currentMode)
            return
        }

        // Clear existing entities
        arView.scene.anchors.removeAll()
        detectedPlanes.removeAll()
        planeEntities.removeAll()

        arView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        error = nil
    }

    // MARK: - Anchor Management

    /// Add an anchor at a specific world position.
    /// - Parameter position: The 3D world position for the anchor
    /// - Returns: The created anchor entity, or nil if creation failed
    @discardableResult
    public func addAnchor(at position: SIMD3<Float>) -> AnchorEntity? {
        let anchor = AnchorEntity(world: position)
        arView.scene.addAnchor(anchor)
        return anchor
    }

    /// Add an anchor at the center of the screen using raycasting.
    /// - Returns: The created anchor entity, or nil if no surface was found
    @discardableResult
    public func addAnchorAtCenter() -> AnchorEntity? {
        let center = CGPoint(x: arView.bounds.midX, y: arView.bounds.midY)

        guard let raycastResult = arView.raycast(
            from: center,
            allowing: .estimatedPlane,
            alignment: .any
        ).first else {
            return nil
        }

        let anchor = AnchorEntity(raycastResult: raycastResult)
        arView.scene.addAnchor(anchor)
        return anchor
    }

    /// Add an anchor at a screen point using raycasting.
    /// - Parameter point: The screen point to raycast from
    /// - Returns: The created anchor entity, or nil if no surface was found
    @discardableResult
    public func addAnchor(at point: CGPoint) -> AnchorEntity? {
        guard let raycastResult = arView.raycast(
            from: point,
            allowing: .estimatedPlane,
            alignment: .any
        ).first else {
            return nil
        }

        let anchor = AnchorEntity(raycastResult: raycastResult)
        arView.scene.addAnchor(anchor)
        return anchor
    }

    /// Remove all entities from a specific anchor.
    /// - Parameter anchor: The anchor to clear
    public func clearAnchor(_ anchor: AnchorEntity) {
        anchor.children.removeAll()
    }

    /// Remove an anchor from the scene.
    /// - Parameter anchor: The anchor to remove
    public func removeAnchor(_ anchor: AnchorEntity) {
        arView.scene.removeAnchor(anchor)
    }

    // MARK: - Plane Visualization

    /// Toggle plane visualization on/off.
    public func togglePlaneVisualization() {
        showPlaneVisualization.toggle()

        if showPlaneVisualization {
            for (id, planeAnchor) in detectedPlanes {
                addPlaneVisualization(for: planeAnchor, id: id)
            }
        } else {
            removePlaneVisualizations()
        }
    }

    private func addPlaneVisualization(for planeAnchor: ARPlaneAnchor, id: UUID) {
        let extent = planeAnchor.planeExtent
        let width = extent.width
        let height = extent.height

        let mesh = MeshResource.generatePlane(width: width, depth: height)
        let material = SimpleMaterial(
            color: UIColor.systemBlue.withAlphaComponent(0.3),
            isMetallic: false
        )

        let planeEntity = ModelEntity(mesh: mesh, materials: [material])
        planeEntity.position = SIMD3<Float>(
            planeAnchor.center.x,
            0,
            planeAnchor.center.z
        )

        let anchor = AnchorEntity(anchor: planeAnchor)
        anchor.addChild(planeEntity)
        arView.scene.addAnchor(anchor)

        planeEntities[id] = planeEntity
    }

    private func removePlaneVisualizations() {
        for (id, entity) in planeEntities {
            entity.removeFromParent()
            planeEntities.removeValue(forKey: id)
        }
    }

    // MARK: - Hit Testing

    /// Perform a raycast from a screen point.
    /// - Parameter point: The screen point to raycast from
    /// - Returns: The world position if a surface was hit, nil otherwise
    public func raycast(from point: CGPoint) -> SIMD3<Float>? {
        guard let result = arView.raycast(
            from: point,
            allowing: .estimatedPlane,
            alignment: .any
        ).first else {
            return nil
        }

        return result.worldTransform.translation
    }

    /// Get the current camera position.
    public var cameraPosition: SIMD3<Float>? {
        arView.session.currentFrame?.camera.transform.translation
    }

    /// Get the current camera transform.
    public var cameraTransform: simd_float4x4? {
        arView.session.currentFrame?.camera.transform
    }
}

// MARK: - ARSessionDelegate

extension ARSessionManager: ARSessionDelegate {
    public nonisolated func session(_ session: ARSession, didUpdate frame: ARFrame) {
        Task { @MainActor in
            self.trackingState = frame.camera.trackingState
        }
    }

    public nonisolated func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        Task { @MainActor in
            for anchor in anchors {
                if let planeAnchor = anchor as? ARPlaneAnchor {
                    self.detectedPlanes[planeAnchor.identifier] = planeAnchor

                    if self.showPlaneVisualization {
                        self.addPlaneVisualization(for: planeAnchor, id: planeAnchor.identifier)
                    }
                }
            }
        }
    }

    public nonisolated func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        Task { @MainActor in
            for anchor in anchors {
                if let planeAnchor = anchor as? ARPlaneAnchor {
                    self.detectedPlanes[planeAnchor.identifier] = planeAnchor

                    // Update plane visualization if enabled
                    if self.showPlaneVisualization,
                       let entity = self.planeEntities[planeAnchor.identifier] {
                        let extent = planeAnchor.planeExtent
                        entity.model?.mesh = MeshResource.generatePlane(
                            width: extent.width,
                            depth: extent.height
                        )
                        entity.position = SIMD3<Float>(
                            planeAnchor.center.x,
                            0,
                            planeAnchor.center.z
                        )
                    }
                }
            }
        }
    }

    public nonisolated func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
        Task { @MainActor in
            for anchor in anchors {
                if let planeAnchor = anchor as? ARPlaneAnchor {
                    self.detectedPlanes.removeValue(forKey: planeAnchor.identifier)

                    if let entity = self.planeEntities.removeValue(forKey: planeAnchor.identifier) {
                        entity.removeFromParent()
                    }
                }
            }
        }
    }

    public nonisolated func session(_ session: ARSession, didFailWithError error: Error) {
        Task { @MainActor in
            self.error = .sessionFailed(error)
            self.isSessionRunning = false
        }
    }

    public nonisolated func sessionWasInterrupted(_ session: ARSession) {
        Task { @MainActor in
            self.isSessionRunning = false
        }
    }

    public nonisolated func sessionInterruptionEnded(_ session: ARSession) {
        Task { @MainActor in
            self.resumeSession()
        }
    }
}

// MARK: - Transform Extensions

extension simd_float4x4 {
    /// Extract the translation component from a transform matrix.
    var translation: SIMD3<Float> {
        SIMD3<Float>(columns.3.x, columns.3.y, columns.3.z)
    }
}

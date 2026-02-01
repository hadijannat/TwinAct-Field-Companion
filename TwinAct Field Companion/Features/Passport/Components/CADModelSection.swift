//
//  CADModelSection.swift
//  TwinAct Field Companion
//
//  Section view for displaying 3D CAD models from AASX packages.
//  Supports QuickLook for USDZ, SceneKit for OBJ/STL, and informational
//  display for unsupported formats like STEP/IGES.
//

import SwiftUI
import SceneKit
import QuickLook

// MARK: - CAD Model Section

/// Section displaying 3D CAD models extracted from AASX packages.
public struct CADModelSection: View {

    // MARK: - Properties

    let assetId: String
    @State private var cadFiles: [AASXCADFile] = []
    @State private var selectedFile: AASXCADFile?
    @State private var isExpanded: Bool = true
    @State private var quickLookURL: URL?

    // MARK: - Body

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerView

            if isExpanded && !cadFiles.isEmpty {
                Divider()
                    .padding(.horizontal)

                contentView
                    .padding()
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .animation(.easeInOut(duration: 0.2), value: isExpanded)
        .onAppear {
            loadCADFiles()
        }
        .quickLookPreview($quickLookURL)
        .sheet(item: $selectedFile) { file in
            CADModelViewer(file: file)
        }
    }

    // MARK: - Header View

    private var headerView: some View {
        Button {
            withAnimation {
                isExpanded.toggle()
            }
        } label: {
            HStack {
                Image(systemName: "cube.fill")
                    .font(.title3)
                    .foregroundColor(.purple)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text("3D Models")
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text("\(cadFiles.count) model\(cadFiles.count == 1 ? "" : "s") available")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
        }
        .buttonStyle(.plain)
    }

    // MARK: - Content View

    private var contentView: some View {
        VStack(spacing: 12) {
            ForEach(cadFiles) { file in
                CADFileRow(file: file) {
                    handleFileTap(file)
                }

                if file.id != cadFiles.last?.id {
                    Divider()
                }
            }
        }
    }

    // MARK: - Private Methods

    private func loadCADFiles() {
        cadFiles = AASXContentStore.shared.cadFiles(for: assetId)
    }

    private func handleFileTap(_ file: AASXCADFile) {
        switch file.format {
        case .usdz:
            // Use QuickLook for USDZ (best AR experience)
            quickLookURL = file.url

        case .obj, .stl, .gltf, .glb:
            // Use SceneKit viewer for these formats
            selectedFile = file

        case .step, .iges, .fbx, .unknown:
            // Show info sheet for unsupported formats
            selectedFile = file
        }
    }
}

// MARK: - CAD File Row

/// Row displaying a single CAD file with format info and action.
private struct CADFileRow: View {
    let file: AASXCADFile
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Format icon
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(formatColor.opacity(0.15))
                        .frame(width: 44, height: 44)

                    Image(systemName: file.format.icon)
                        .font(.title3)
                        .foregroundColor(formatColor)
                }

                // File info
                VStack(alignment: .leading, spacing: 4) {
                    Text(file.filename)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        // Format badge
                        Text(file.format.displayName)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(formatColor.opacity(0.1))
                            .foregroundColor(formatColor)
                            .cornerRadius(4)

                        // Support indicator
                        if file.format.isNativelySupported {
                            Label("Viewable", systemImage: "eye.fill")
                                .font(.caption2)
                                .foregroundColor(.green)
                        } else {
                            Label("Export only", systemImage: "square.and.arrow.up")
                                .font(.caption2)
                                .foregroundColor(.orange)
                        }

                        // File size
                        if let size = file.formattedFileSize {
                            Text(size)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Spacer()

                // Action indicator
                Image(systemName: file.format.isNativelySupported ? "arkit" : "info.circle")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var formatColor: Color {
        switch file.format {
        case .usdz: return .purple
        case .obj, .stl: return .blue
        case .gltf, .glb: return .teal
        case .fbx: return .orange
        case .step, .iges: return .gray
        case .unknown: return .secondary
        }
    }
}

// MARK: - CAD Model Viewer

/// Full-screen viewer for CAD models using SceneKit or info display.
private struct CADModelViewer: View {
    let file: AASXCADFile
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if file.format.isNativelySupported {
                    SceneKitModelView(url: file.url, format: file.format)
                } else {
                    unsupportedFormatView
                }
            }
            .navigationTitle(file.filename)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(item: file.url) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
    }

    private var unsupportedFormatView: some View {
        VStack(spacing: 24) {
            Image(systemName: file.format.icon)
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            VStack(spacing: 8) {
                Text("\(file.format.displayName) Format")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("This 3D model format cannot be viewed directly on iOS.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: 12) {
                CADInfoRow(label: "Filename", value: file.filename)
                CADInfoRow(label: "Format", value: file.format.displayName)
                if let size = file.formattedFileSize {
                    CADInfoRow(label: "Size", value: size)
                }
            }
            .padding()
            .background(Color(.tertiarySystemBackground))
            .cornerRadius(12)

            VStack(spacing: 12) {
                Text("Options")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                ShareLink(item: file.url) {
                    Label("Export to External App", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Text("Open in a CAD viewer app like Shapr3D, Onshape, or Fusion 360")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
    }
}

// MARK: - CAD Info Row

private struct CADInfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
    }
}

// MARK: - SceneKit Model View

/// SceneKit-based 3D model viewer with camera controls.
private struct SceneKitModelView: UIViewRepresentable {
    let url: URL
    let format: AASXCADFormat

    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.backgroundColor = .systemBackground
        scnView.allowsCameraControl = true
        scnView.autoenablesDefaultLighting = true
        scnView.showsStatistics = false

        loadScene(into: scnView)

        return scnView
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        // No updates needed
    }

    private func loadScene(into scnView: SCNView) {
        DispatchQueue.global(qos: .userInitiated).async {
            var scene: SCNScene?

            switch format {
            case .obj:
                scene = try? SCNScene(url: url, options: nil)

            case .stl:
                // STL requires custom parsing or MDLAsset
                scene = loadSTLScene(from: url)

            case .usdz, .gltf, .glb:
                scene = try? SCNScene(url: url, options: nil)

            default:
                break
            }

            DispatchQueue.main.async {
                if let loadedScene = scene {
                    scnView.scene = loadedScene

                    // Center and scale the model
                    if let rootNode = loadedScene.rootNode.childNodes.first {
                        let (min, max) = rootNode.boundingBox
                        let size = SCNVector3(
                            max.x - min.x,
                            max.y - min.y,
                            max.z - min.z
                        )
                        let maxDimension = Swift.max(size.x, Swift.max(size.y, size.z))
                        if maxDimension > 0 {
                            let scale = 2.0 / Float(maxDimension)
                            rootNode.scale = SCNVector3(scale, scale, scale)
                        }

                        // Center the model
                        let center = SCNVector3(
                            (min.x + max.x) / 2,
                            (min.y + max.y) / 2,
                            (min.z + max.z) / 2
                        )
                        rootNode.position = SCNVector3(-center.x, -center.y, -center.z)
                    }

                    // Add camera
                    let cameraNode = SCNNode()
                    cameraNode.camera = SCNCamera()
                    cameraNode.position = SCNVector3(0, 0, 5)
                    loadedScene.rootNode.addChildNode(cameraNode)
                } else {
                    // Show error scene
                    let errorScene = SCNScene()
                    let textNode = SCNNode()
                    let textGeometry = SCNText(string: "Unable to load model", extrusionDepth: 0.1)
                    textGeometry.font = UIFont.systemFont(ofSize: 0.3)
                    textNode.geometry = textGeometry
                    textNode.position = SCNVector3(-1.5, 0, 0)
                    errorScene.rootNode.addChildNode(textNode)
                    scnView.scene = errorScene
                }
            }
        }
    }

    private func loadSTLScene(from url: URL) -> SCNScene? {
        // Try using ModelIO for STL files
        let asset = MDLAsset(url: url)

        // Check if asset loaded successfully
        guard asset.count > 0 else { return nil }

        asset.loadTextures()

        let scene = SCNScene()
        for i in 0..<asset.count {
            let object = asset.object(at: i)
            let node = SCNNode(mdlObject: object)
            scene.rootNode.addChildNode(node)
        }

        return scene
    }
}

// Import ModelIO for STL support
import ModelIO
import SceneKit.ModelIO

// MARK: - Empty State View

/// View shown when no CAD files are available.
public struct CADModelEmptyState: View {
    public var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "cube.transparent")
                .font(.system(size: 40))
                .foregroundColor(.secondary)

            Text("No 3D Models")
                .font(.headline)

            Text("This asset does not include any 3D CAD models.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Preview Provider

#if DEBUG
struct CADModelSection_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            VStack(spacing: 20) {
                CADModelSection(assetId: "preview-asset")
                CADModelEmptyState()
            }
            .padding()
        }
    }
}
#endif

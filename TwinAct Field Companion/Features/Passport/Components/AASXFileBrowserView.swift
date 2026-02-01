//
//  AASXFileBrowserView.swift
//  TwinAct Field Companion
//
//  Tree view for exploring AASX package file structure.
//  Displays the hierarchical contents with file type icons and metadata.
//

import SwiftUI
import QuickLook

// MARK: - AASX File Browser View

/// Tree browser for exploring the contents of an AASX package.
/// Shows file hierarchy with expandable directories and file metadata.
public struct AASXFileBrowserView: View {

    // MARK: - Properties

    let assetId: String
    @State private var rootNode: AASXPackageNode?
    @State private var isExpanded: Bool = true
    @State private var quickLookURL: URL?
    @State private var expandedNodes: Set<String> = []

    // MARK: - Body

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerView

            if isExpanded {
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
            loadPackageStructure()
        }
        .quickLookPreview($quickLookURL)
    }

    // MARK: - Header View

    private var headerView: some View {
        Button {
            withAnimation {
                isExpanded.toggle()
            }
        } label: {
            HStack {
                Image(systemName: "folder.fill")
                    .font(.title3)
                    .foregroundColor(.blue)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Package Contents")
                        .font(.headline)
                        .foregroundColor(.primary)

                    if let root = rootNode {
                        Text("\(root.childCount) item\(root.childCount == 1 ? "" : "s") in root")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Loading...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
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
        Group {
            if let root = rootNode {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(root.children ?? []) { node in
                        FileNodeView(
                            node: node,
                            expandedNodes: $expandedNodes,
                            onFileTap: handleFileTap,
                            depth: 0
                        )
                    }
                }
            } else {
                ProgressView("Loading package structure...")
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            }
        }
    }

    // MARK: - Private Methods

    private func loadPackageStructure() {
        rootNode = AASXContentStore.shared.packageStructure(for: assetId)
    }

    private func handleFileTap(_ node: AASXPackageNode) {
        guard !node.isDirectory else { return }

        let url = URL(fileURLWithPath: node.path)

        // Use QuickLook for previewable files
        if canQuickLookPreview(node) {
            quickLookURL = url
        }
    }

    private func canQuickLookPreview(_ node: AASXPackageNode) -> Bool {
        let previewableTypes: Set<AASXFileType> = [.pdf, .image, .text, .json]
        return previewableTypes.contains(node.fileType)
    }
}

// MARK: - File Node View

/// Recursive view for displaying a single file/directory node.
private struct FileNodeView: View {
    let node: AASXPackageNode
    @Binding var expandedNodes: Set<String>
    let onFileTap: (AASXPackageNode) -> Void
    let depth: Int

    private var isExpanded: Bool {
        expandedNodes.contains(node.id)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Node row
            nodeRow
                .contentShape(Rectangle())
                .onTapGesture {
                    if node.isDirectory {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if isExpanded {
                                expandedNodes.remove(node.id)
                            } else {
                                expandedNodes.insert(node.id)
                            }
                        }
                    } else {
                        onFileTap(node)
                    }
                }

            // Children (if expanded directory)
            if node.isDirectory && isExpanded, let children = node.children {
                ForEach(children) { child in
                    FileNodeView(
                        node: child,
                        expandedNodes: $expandedNodes,
                        onFileTap: onFileTap,
                        depth: depth + 1
                    )
                }
            }
        }
    }

    private var nodeRow: some View {
        HStack(spacing: 8) {
            // Indentation
            if depth > 0 {
                ForEach(0..<depth, id: \.self) { _ in
                    Rectangle()
                        .fill(Color(.separator))
                        .frame(width: 1)
                        .padding(.leading, 12)
                }
            }

            // Expand indicator for directories
            if node.isDirectory {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .frame(width: 12)
            } else {
                Spacer()
                    .frame(width: 12)
            }

            // File type icon
            Image(systemName: node.fileType.icon)
                .font(.body)
                .foregroundColor(fileTypeColor)
                .frame(width: 20)

            // Name
            Text(node.name)
                .font(.subheadline)
                .foregroundColor(.primary)
                .lineLimit(1)

            Spacer()

            // Metadata
            if !node.isDirectory {
                if let size = node.formattedFileSize {
                    Text(size)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            } else if let children = node.children {
                Text("\(children.count)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(isExpanded && node.isDirectory ? Color(.tertiarySystemBackground) : Color.clear)
    }

    private var fileTypeColor: Color {
        switch node.fileType {
        case .directory: return .blue
        case .json: return .orange
        case .xml: return .purple
        case .pdf: return .red
        case .image: return .green
        case .cad: return .teal
        case .archive: return .brown
        case .text: return .gray
        case .other: return .secondary
        }
    }
}

// MARK: - Compact File Browser

/// Compact version showing only top-level items.
public struct CompactFileBrowserView: View {
    let assetId: String
    @State private var rootNode: AASXPackageNode?
    var onViewAll: (() -> Void)?

    public init(assetId: String, onViewAll: (() -> Void)? = nil) {
        self.assetId = assetId
        self.onViewAll = onViewAll
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let root = rootNode, let children = root.children {
                ForEach(children.prefix(5)) { node in
                    HStack(spacing: 8) {
                        Image(systemName: node.fileType.icon)
                            .font(.caption)
                            .foregroundColor(fileTypeColor(for: node))
                            .frame(width: 16)

                        Text(node.name)
                            .font(.caption)
                            .lineLimit(1)

                        Spacer()

                        if node.isDirectory {
                            Image(systemName: "folder")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 2)
                }

                if children.count > 5 {
                    Button {
                        onViewAll?()
                    } label: {
                        Text("View all \(children.count) items")
                            .font(.caption)
                            .foregroundColor(.accentColor)
                    }
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .onAppear {
            rootNode = AASXContentStore.shared.packageStructure(for: assetId)
        }
    }

    private func fileTypeColor(for node: AASXPackageNode) -> Color {
        switch node.fileType {
        case .directory: return .blue
        case .json: return .orange
        case .xml: return .purple
        case .pdf: return .red
        case .image: return .green
        case .cad: return .teal
        case .archive: return .brown
        case .text: return .gray
        case .other: return .secondary
        }
    }
}

// MARK: - Preview Provider

#if DEBUG
struct AASXFileBrowserView_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            VStack(spacing: 20) {
                AASXFileBrowserView(assetId: "preview-asset")
                CompactFileBrowserView(assetId: "preview-asset")
            }
            .padding()
        }
    }
}
#endif

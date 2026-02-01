//
//  AASJSONExplorerView.swift
//  TwinAct Field Companion
//
//  Interactive JSON tree explorer for viewing AAS structure.
//  Displays collapsible tree with color-coded values and search.
//

import SwiftUI

// MARK: - AAS JSON Explorer View

/// Interactive explorer for viewing the AAS JSON structure.
/// Features collapsible tree, color-coded values, and search.
public struct AASJSONExplorerView: View {

    // MARK: - Properties

    let assetId: String
    @State private var jsonData: [String: Any]?
    @State private var isExpanded: Bool = true
    @State private var searchText: String = ""
    @State private var expandedPaths: Set<String> = []
    @State private var initialExpansionDone: Bool = false

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
            loadJSON()
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
                Image(systemName: "curlybraces")
                    .font(.title3)
                    .foregroundColor(.orange)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text("AAS Structure")
                        .font(.headline)
                        .foregroundColor(.primary)

                    if jsonData != nil {
                        Text("JSON tree explorer")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("No JSON data available")
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
        VStack(alignment: .leading, spacing: 12) {
            // Search bar
            if jsonData != nil {
                searchBar
            }

            // JSON tree
            if let json = jsonData {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(json.keys.sorted()), id: \.self) { key in
                            JSONNodeView(
                                key: key,
                                value: json[key]!,
                                path: key,
                                searchText: searchText,
                                expandedPaths: $expandedPaths,
                                depth: 0
                            )
                        }
                    }
                }
                .frame(maxHeight: 400)
            } else {
                emptyState
            }

            // Actions
            if jsonData != nil {
                actionButtons
            }
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)

            TextField("Search keys or values", text: $searchText)
                .textFieldStyle(.plain)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(8)
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(8)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 30))
                .foregroundColor(.secondary)

            Text("No AAS JSON Found")
                .font(.subheadline)
                .fontWeight(.medium)

            Text("This package does not contain viewable AAS JSON structure.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button {
                expandedPaths.removeAll()
            } label: {
                Label("Collapse All", systemImage: "arrow.down.right.and.arrow.up.left")
                    .font(.caption)
            }
            .buttonStyle(.bordered)

            Button {
                expandToDepth(2)
            } label: {
                Label("Expand Level 2", systemImage: "arrow.up.left.and.arrow.down.right")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
        }
    }

    // MARK: - Private Methods

    private func loadJSON() {
        jsonData = AASXContentStore.shared.aasJSON(for: assetId)

        // Auto-expand first two levels on initial load
        if !initialExpansionDone && jsonData != nil {
            expandToDepth(2)
            initialExpansionDone = true
        }
    }

    private func expandToDepth(_ maxDepth: Int) {
        guard let json = jsonData else { return }
        expandedPaths.removeAll()
        collectPaths(from: json, currentPath: "", currentDepth: 0, maxDepth: maxDepth)
    }

    private func collectPaths(from value: Any, currentPath: String, currentDepth: Int, maxDepth: Int) {
        guard currentDepth < maxDepth else { return }

        if let dict = value as? [String: Any] {
            if !currentPath.isEmpty {
                expandedPaths.insert(currentPath)
            }
            for key in dict.keys {
                let newPath = currentPath.isEmpty ? key : "\(currentPath).\(key)"
                collectPaths(from: dict[key]!, currentPath: newPath, currentDepth: currentDepth + 1, maxDepth: maxDepth)
            }
        } else if let array = value as? [Any] {
            if !currentPath.isEmpty {
                expandedPaths.insert(currentPath)
            }
            for (index, item) in array.enumerated() {
                let newPath = "\(currentPath)[\(index)]"
                collectPaths(from: item, currentPath: newPath, currentDepth: currentDepth + 1, maxDepth: maxDepth)
            }
        }
    }
}

// MARK: - JSON Node View

/// Recursive view for displaying a single JSON key-value pair.
private struct JSONNodeView: View {
    let key: String
    let value: Any
    let path: String
    let searchText: String
    @Binding var expandedPaths: Set<String>
    let depth: Int

    private var isExpanded: Bool {
        expandedPaths.contains(path)
    }

    private var isExpandable: Bool {
        value is [String: Any] || value is [Any]
    }

    private var matchesSearch: Bool {
        guard !searchText.isEmpty else { return true }
        let lowercasedSearch = searchText.lowercased()
        return key.lowercased().contains(lowercasedSearch) ||
               String(describing: value).lowercased().contains(lowercasedSearch)
    }

    var body: some View {
        if matchesSearch || searchText.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                // Node row
                nodeRow
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if isExpandable {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                if isExpanded {
                                    expandedPaths.remove(path)
                                } else {
                                    expandedPaths.insert(path)
                                }
                            }
                        }
                    }

                // Children
                if isExpanded {
                    childrenView
                }
            }
        }
    }

    private var nodeRow: some View {
        HStack(spacing: 4) {
            // Indentation
            if depth > 0 {
                Rectangle()
                    .fill(Color(.separator).opacity(0.5))
                    .frame(width: CGFloat(depth) * 16, height: 1)
                    .hidden()
            }

            // Expand indicator
            if isExpandable {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .frame(width: 12)
            } else {
                Spacer()
                    .frame(width: 12)
            }

            // Key
            Text(key)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(keyColor)

            // Colon
            Text(":")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)

            // Value preview (for non-expandable or collapsed)
            if !isExpandable {
                valuePreview
            } else if !isExpanded {
                collapsedPreview
            }

            Spacer()
        }
        .padding(.leading, CGFloat(depth) * 16)
        .padding(.vertical, 4)
        .background(highlightBackground)
    }

    private var highlightBackground: some View {
        Group {
            if !searchText.isEmpty && matchesSearch {
                Color.yellow.opacity(0.2)
            } else {
                Color.clear
            }
        }
    }

    private var keyColor: Color {
        if !searchText.isEmpty && key.lowercased().contains(searchText.lowercased()) {
            return .orange
        }
        return .primary
    }

    @ViewBuilder
    private var valuePreview: some View {
        if let string = value as? String {
            Text("\"\(string)\"")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.green)
                .lineLimit(1)
        } else if let number = value as? NSNumber {
            if CFBooleanGetTypeID() == CFGetTypeID(number) {
                Text(number.boolValue ? "true" : "false")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.purple)
            } else {
                Text("\(number)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.blue)
            }
        } else if value is NSNull {
            Text("null")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.gray)
        } else {
            Text(String(describing: value))
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
    }

    private var collapsedPreview: some View {
        Group {
            if let dict = value as? [String: Any] {
                Text("{ \(dict.count) keys }")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
            } else if let array = value as? [Any] {
                Text("[ \(array.count) items ]")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
            }
        }
    }

    @ViewBuilder
    private var childrenView: some View {
        if let dict = value as? [String: Any] {
            ForEach(Array(dict.keys.sorted()), id: \.self) { childKey in
                JSONNodeView(
                    key: childKey,
                    value: dict[childKey]!,
                    path: "\(path).\(childKey)",
                    searchText: searchText,
                    expandedPaths: $expandedPaths,
                    depth: depth + 1
                )
            }
        } else if let array = value as? [Any] {
            ForEach(Array(array.enumerated()), id: \.offset) { index, item in
                JSONNodeView(
                    key: "[\(index)]",
                    value: item,
                    path: "\(path)[\(index)]",
                    searchText: searchText,
                    expandedPaths: $expandedPaths,
                    depth: depth + 1
                )
            }
        }
    }
}

// MARK: - Compact JSON Preview

/// Compact preview showing key AAS properties.
public struct CompactAASPreview: View {
    let assetId: String
    @State private var jsonData: [String: Any]?

    public init(assetId: String) {
        self.assetId = assetId
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let json = jsonData {
                // Show key properties
                if let shells = json["assetAdministrationShells"] as? [[String: Any]], let first = shells.first {
                    if let idShort = first["idShort"] as? String {
                        PropertyRow(label: "AAS ID Short", value: idShort)
                    }
                    if let id = first["id"] as? String {
                        PropertyRow(label: "AAS ID", value: String(id.suffix(30)))
                    }
                }

                if let submodels = json["submodels"] as? [[String: Any]] {
                    PropertyRow(label: "Submodels", value: "\(submodels.count)")
                }

                if let assets = json["assets"] as? [[String: Any]] {
                    PropertyRow(label: "Assets", value: "\(assets.count)")
                }
            } else {
                Text("No AAS structure available")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .onAppear {
            jsonData = AASXContentStore.shared.aasJSON(for: assetId)
        }
    }
}

// MARK: - Property Row

private struct PropertyRow: View {
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
                .lineLimit(1)
        }
    }
}

// MARK: - Preview Provider

#if DEBUG
struct AASJSONExplorerView_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            VStack(spacing: 20) {
                AASJSONExplorerView(assetId: "preview-asset")
                CompactAASPreview(assetId: "preview-asset")
            }
            .padding()
        }
    }
}
#endif

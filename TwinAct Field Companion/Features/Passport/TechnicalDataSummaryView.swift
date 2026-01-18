//
//  TechnicalDataSummaryView.swift
//  TwinAct Field Companion
//
//  Technical Data summary view displaying key technical properties
//  from the Technical Data submodel per IDTA specification.
//

import SwiftUI

// MARK: - Technical Data Summary View

/// Summary view of technical data properties.
/// Shows key specifications from the Technical Data submodel.
public struct TechnicalDataSummaryView: View {

    // MARK: - Properties

    let data: TechnicalDataSummary
    @State private var isExpanded: Bool = true
    @State private var searchText: String = ""
    @State private var showAllProperties: Bool = false

    private let maxVisibleProperties = 8

    // MARK: - Body

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            headerView

            if isExpanded {
                Divider()
                    .padding(.horizontal)

                // Content
                contentView
                    .padding()
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .animation(.easeInOut(duration: 0.2), value: isExpanded)
    }

    // MARK: - Header View

    private var headerView: some View {
        Button {
            withAnimation {
                isExpanded.toggle()
            }
        } label: {
            HStack {
                // Icon
                Image(systemName: "cpu.fill")
                    .font(.title3)
                    .foregroundColor(.purple)
                    .frame(width: 32)

                // Title
                VStack(alignment: .leading, spacing: 2) {
                    Text("Technical Data")
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text("\(data.properties.count) specification\(data.properties.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Expand/collapse indicator
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
        VStack(alignment: .leading, spacing: 16) {
            // Search (if many properties)
            if data.properties.count > 10 {
                searchField
            }

            // Properties grid
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 12) {
                ForEach(visibleProperties) { property in
                    TechnicalPropertyCard(property: property)
                }
            }

            // Show more/less button
            if data.properties.count > maxVisibleProperties {
                showMoreButton
            }

            // Submodel info
            submodelInfo
        }
    }

    // MARK: - Search Field

    private var searchField: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)

            TextField("Search specifications...", text: $searchText)
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

    // MARK: - Show More Button

    private var showMoreButton: some View {
        Button {
            withAnimation {
                showAllProperties.toggle()
            }
        } label: {
            HStack {
                Text(showAllProperties ? "Show Less" : "Show All \(data.properties.count) Specifications")
                    .font(.caption)

                Image(systemName: showAllProperties ? "chevron.up" : "chevron.down")
                    .font(.caption2)
            }
            .foregroundColor(.accentColor)
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Submodel Info

    private var submodelInfo: some View {
        HStack(spacing: 4) {
            Image(systemName: "info.circle")
                .font(.caption2)
                .foregroundColor(.secondary)

            Text("Source: \(data.idShort ?? "Technical Data Submodel")")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.top, 8)
    }

    // MARK: - Computed Properties

    private var visibleProperties: [TechnicalProperty] {
        let filtered = searchText.isEmpty
            ? data.properties
            : data.properties.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.value.localizedCaseInsensitiveContains(searchText)
            }

        if showAllProperties || filtered.count <= maxVisibleProperties {
            return filtered
        }

        return Array(filtered.prefix(maxVisibleProperties))
    }
}

// MARK: - Technical Property Card

/// Card displaying a single technical property.
struct TechnicalPropertyCard: View {
    let property: TechnicalProperty

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Property name
            Text(formatPropertyName(property.name))
                .font(.caption2)
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .lineLimit(1)

            // Property value
            Text(property.formattedValue)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(2)

            // Unit (if separate)
            if let unit = property.unit {
                Text(unit)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(8)
    }

    /// Format property name for display (convert camelCase to Title Case).
    private func formatPropertyName(_ name: String) -> String {
        // Insert spaces before capital letters and capitalize first letter
        var result = ""
        for (index, char) in name.enumerated() {
            if char.isUppercase && index > 0 {
                result.append(" ")
            }
            result.append(char)
        }
        return result
    }
}

// MARK: - Compact Technical Data View

/// Compact version of technical data for smaller spaces.
public struct CompactTechnicalDataView: View {
    let properties: [TechnicalProperty]
    let maxVisible: Int

    public init(properties: [TechnicalProperty], maxVisible: Int = 4) {
        self.properties = properties
        self.maxVisible = maxVisible
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(properties.prefix(maxVisible)) { property in
                HStack {
                    Text(property.name)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    Text(property.formattedValue)
                        .font(.caption)
                        .fontWeight(.medium)
                }
            }

            if properties.count > maxVisible {
                Text("+\(properties.count - maxVisible) more")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Technical Data Table View

/// Table-style view for technical data.
public struct TechnicalDataTableView: View {
    let properties: [TechnicalProperty]
    @State private var sortOrder: SortOrder = .name

    enum SortOrder {
        case name
        case value
    }

    public init(properties: [TechnicalProperty]) {
        self.properties = properties
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row
            HStack {
                Text("Property")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text("Value")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.tertiarySystemBackground))

            // Data rows
            ForEach(sortedProperties) { property in
                HStack {
                    Text(property.name)
                        .font(.caption)
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(property.formattedValue)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

                Divider()
                    .padding(.horizontal, 12)
            }
        }
        .background(Color(.secondarySystemBackground))
        .cornerRadius(10)
    }

    private var sortedProperties: [TechnicalProperty] {
        switch sortOrder {
        case .name:
            return properties.sorted { $0.name < $1.name }
        case .value:
            return properties.sorted { $0.value < $1.value }
        }
    }
}

// MARK: - Technical Data Highlights

/// Highlights view showing key technical metrics.
public struct TechnicalDataHighlights: View {
    let highlights: [TechnicalHighlight]

    public init(properties: [TechnicalProperty]) {
        // Extract key highlights from properties
        var highlights: [TechnicalHighlight] = []

        for property in properties {
            let lowercaseName = property.name.lowercased()

            if lowercaseName.contains("power") || lowercaseName.contains("watt") {
                highlights.append(TechnicalHighlight(
                    icon: "bolt.fill",
                    title: "Power",
                    value: property.formattedValue,
                    color: .yellow
                ))
            } else if lowercaseName.contains("voltage") {
                highlights.append(TechnicalHighlight(
                    icon: "minus.plus.batteryblock.fill",
                    title: "Voltage",
                    value: property.formattedValue,
                    color: .orange
                ))
            } else if lowercaseName.contains("current") || lowercaseName.contains("ampere") {
                highlights.append(TechnicalHighlight(
                    icon: "bolt.horizontal.fill",
                    title: "Current",
                    value: property.formattedValue,
                    color: .blue
                ))
            } else if lowercaseName.contains("weight") || lowercaseName.contains("mass") {
                highlights.append(TechnicalHighlight(
                    icon: "scalemass.fill",
                    title: "Weight",
                    value: property.formattedValue,
                    color: .gray
                ))
            } else if lowercaseName.contains("temperature") {
                highlights.append(TechnicalHighlight(
                    icon: "thermometer.medium",
                    title: "Temperature",
                    value: property.formattedValue,
                    color: .red
                ))
            } else if lowercaseName.contains("speed") || lowercaseName.contains("rpm") {
                highlights.append(TechnicalHighlight(
                    icon: "gauge.with.needle.fill",
                    title: "Speed",
                    value: property.formattedValue,
                    color: .purple
                ))
            }
        }

        self.highlights = Array(highlights.prefix(4))
    }

    public var body: some View {
        if !highlights.isEmpty {
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(highlights) { highlight in
                    TechnicalHighlightCard(highlight: highlight)
                }
            }
        }
    }
}

// MARK: - Technical Highlight

/// A key technical metric for display.
public struct TechnicalHighlight: Identifiable {
    public let id = UUID()
    public let icon: String
    public let title: String
    public let value: String
    public let color: Color

    public init(icon: String, title: String, value: String, color: Color) {
        self.icon = icon
        self.title = title
        self.value = value
        self.color = color
    }
}

// MARK: - Technical Highlight Card

/// Card for displaying a technical highlight.
struct TechnicalHighlightCard: View {
    let highlight: TechnicalHighlight

    var body: some View {
        HStack(spacing: 10) {
            // Icon
            ZStack {
                Circle()
                    .fill(highlight.color.opacity(0.15))
                    .frame(width: 36, height: 36)

                Image(systemName: highlight.icon)
                    .font(.body)
                    .foregroundColor(highlight.color)
            }

            // Content
            VStack(alignment: .leading, spacing: 2) {
                Text(highlight.title)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)

                Text(highlight.value)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(10)
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(10)
    }
}

// MARK: - Preview Provider

#if DEBUG
struct TechnicalDataSummaryView_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            VStack(spacing: 20) {
                TechnicalDataSummaryView(
                    data: TechnicalDataSummary(
                        submodelId: "https://example.com/submodel/techdata",
                        idShort: "TechnicalData",
                        properties: [
                            TechnicalProperty(name: "RatedPower", path: "RatedPower", value: "5.5", unit: "kW"),
                            TechnicalProperty(name: "RatedVoltage", path: "RatedVoltage", value: "400", unit: "V"),
                            TechnicalProperty(name: "RatedCurrent", path: "RatedCurrent", value: "11.2", unit: "A"),
                            TechnicalProperty(name: "RatedSpeed", path: "RatedSpeed", value: "1450", unit: "rpm"),
                            TechnicalProperty(name: "Efficiency", path: "Efficiency", value: "91.5", unit: "%"),
                            TechnicalProperty(name: "PowerFactor", path: "PowerFactor", value: "0.85", unit: nil),
                            TechnicalProperty(name: "Weight", path: "Weight", value: "45", unit: "kg"),
                            TechnicalProperty(name: "IP_Rating", path: "IP_Rating", value: "IP55", unit: nil),
                            TechnicalProperty(name: "InsulationClass", path: "InsulationClass", value: "F", unit: nil),
                            TechnicalProperty(name: "AmbientTemperature", path: "AmbientTemperature", value: "-20 to +40", unit: "C")
                        ]
                    )
                )

                TechnicalDataHighlights(
                    properties: [
                        TechnicalProperty(name: "RatedPower", path: "RatedPower", value: "5.5 kW", unit: nil),
                        TechnicalProperty(name: "RatedVoltage", path: "RatedVoltage", value: "400 V", unit: nil),
                        TechnicalProperty(name: "RatedCurrent", path: "RatedCurrent", value: "11.2 A", unit: nil),
                        TechnicalProperty(name: "Weight", path: "Weight", value: "45 kg", unit: nil)
                    ]
                )
            }
            .padding()
        }
    }
}
#endif

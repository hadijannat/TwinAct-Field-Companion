//
//  CarbonFootprintView.swift
//  TwinAct Field Companion
//
//  Carbon Footprint visualization for Digital Product Passport (DPP)
//  sustainability display per IDTA 02023.
//

import SwiftUI

// MARK: - Carbon Footprint View

/// Carbon footprint visualization for DPP.
/// Displays total CO2 equivalent, lifecycle breakdown, and verification status.
public struct CarbonFootprintView: View {

    // MARK: - Properties

    let footprint: CarbonFootprint
    @State private var isExpanded: Bool = true
    @State private var selectedPhase: BreakdownPhase?

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
                Image(systemName: "leaf.fill")
                    .font(.title3)
                    .foregroundColor(.green)
                    .frame(width: 32)

                // Title
                VStack(alignment: .leading, spacing: 2) {
                    Text("Carbon Footprint")
                        .font(.headline)
                        .foregroundColor(.primary)

                    if let total = footprint.formattedTotalCO2 {
                        Text(total)
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }

                Spacer()

                // Verification badge
                if footprint.isVerified {
                    VerificationBadgeSmall()
                }

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
        VStack(alignment: .leading, spacing: 20) {
            // Total CO2eq with gauge
            if let total = footprint.totalCO2eq {
                CarbonGauge(value: total)
            }

            // Breakdown by lifecycle phase
            if !footprint.breakdown.isEmpty {
                LifecycleBreakdownView(
                    breakdown: footprint.breakdown,
                    selectedPhase: $selectedPhase
                )
            }

            // Additional metrics
            if hasAdditionalMetrics {
                additionalMetricsView
            }

            // Verification status
            if footprint.isVerified {
                VerificationView(footprint: footprint)
            }

            // Validity period
            if let validFrom = footprint.validityPeriodStart,
               let validTo = footprint.validityPeriodEnd {
                ValidityPeriodView(from: validFrom, to: validTo)
            }

            // Calculation method
            if let method = footprint.pcfCalculationMethod {
                calculationMethodView(method)
            }
        }
    }

    // MARK: - Additional Metrics

    private var hasAdditionalMetrics: Bool {
        footprint.waterFootprint != nil ||
        footprint.energyEfficiencyClass != nil ||
        footprint.circularEconomyScore != nil ||
        footprint.recyclabilityPercentage != nil
    }

    private var additionalMetricsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Additional Sustainability Metrics")
                .font(.caption)
                .foregroundColor(.secondary)
                .textCase(.uppercase)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                // Water footprint
                if let water = footprint.waterFootprint {
                    MetricCard(
                        icon: "drop.fill",
                        title: "Water Footprint",
                        value: String(format: "%.0f L", water),
                        color: .blue
                    )
                }

                // Energy efficiency class
                if let efficiency = footprint.energyEfficiencyClass {
                    MetricCard(
                        icon: "bolt.fill",
                        title: "Energy Class",
                        value: efficiency,
                        color: energyClassColor(efficiency)
                    )
                }

                // Circular economy score
                if let score = footprint.circularEconomyScore {
                    MetricCard(
                        icon: "arrow.3.trianglepath",
                        title: "Circular Score",
                        value: String(format: "%.0f%%", score),
                        color: .purple
                    )
                }

                // Recyclability
                if let recyclability = footprint.recyclabilityPercentage {
                    MetricCard(
                        icon: "arrow.2.squarepath",
                        title: "Recyclability",
                        value: String(format: "%.0f%%", recyclability),
                        color: .green
                    )
                }

                // Recycled content
                if let recycled = footprint.recycledContentPercentage {
                    MetricCard(
                        icon: "leaf.arrow.triangle.circlepath",
                        title: "Recycled Content",
                        value: String(format: "%.0f%%", recycled),
                        color: .teal
                    )
                }
            }
        }
    }

    // MARK: - Calculation Method

    private func calculationMethodView(_ method: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "function")
                .font(.caption)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text("Calculation Method")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)

                Text(method)
                    .font(.caption)
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Helpers

    private func energyClassColor(_ energyClass: String) -> Color {
        switch energyClass.uppercased() {
        case "A+++", "A++", "A+", "A":
            return .green
        case "B":
            return .mint
        case "C":
            return .yellow
        case "D":
            return .orange
        default:
            return .red
        }
    }
}

// MARK: - Carbon Gauge

/// Visual gauge showing total CO2 equivalent value.
struct CarbonGauge: View {
    let value: Double
    @State private var animatedValue: Double = 0

    var body: some View {
        VStack(spacing: 12) {
            // Circular gauge
            ZStack {
                // Background circle
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 12)

                // Progress arc
                Circle()
                    .trim(from: 0, to: min(animatedValue / referenceValue, 1.0))
                    .stroke(
                        gaugeGradient,
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                // Center content
                VStack(spacing: 4) {
                    Text(formattedValue)
                        .font(.system(size: 28, weight: .bold, design: .rounded))

                    Text("CO2eq")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 140, height: 140)

            // Label
            HStack(spacing: 4) {
                Circle()
                    .fill(gaugeColor)
                    .frame(width: 8, height: 8)

                Text(ratingLabel)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                animatedValue = value
            }
        }
    }

    private var formattedValue: String {
        if value >= 1000 {
            return String(format: "%.1ft", value / 1000)
        }
        return String(format: "%.0fkg", value)
    }

    private var referenceValue: Double {
        // Reference value for gauge (adjustable based on product category)
        max(value * 2, 500)
    }

    private var gaugeColor: Color {
        let ratio = value / referenceValue
        if ratio < 0.3 { return .green }
        if ratio < 0.6 { return .yellow }
        if ratio < 0.8 { return .orange }
        return .red
    }

    private var gaugeGradient: LinearGradient {
        LinearGradient(
            colors: [.green, gaugeColor],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private var ratingLabel: String {
        let ratio = value / referenceValue
        if ratio < 0.3 { return "Excellent sustainability" }
        if ratio < 0.6 { return "Good sustainability" }
        if ratio < 0.8 { return "Average sustainability" }
        return "Needs improvement"
    }
}

// MARK: - Lifecycle Breakdown View

/// View showing CO2 breakdown by lifecycle phase.
struct LifecycleBreakdownView: View {
    let breakdown: [(phase: String, value: Double, percentage: Double)]
    @Binding var selectedPhase: BreakdownPhase?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Lifecycle Breakdown")
                .font(.caption)
                .foregroundColor(.secondary)
                .textCase(.uppercase)

            // Bar chart
            ForEach(breakdown, id: \.phase) { item in
                BreakdownBar(
                    phase: item.phase,
                    value: item.value,
                    percentage: item.percentage,
                    color: phaseColor(item.phase)
                )
            }
        }
    }

    private func phaseColor(_ phase: String) -> Color {
        switch phase.lowercased() {
        case "production", "manufacturing":
            return .blue
        case "transport":
            return .orange
        case "use phase", "use":
            return .purple
        case "end of life", "disposal":
            return .gray
        default:
            return .teal
        }
    }
}

// MARK: - Breakdown Bar

/// Single bar in the lifecycle breakdown chart.
struct BreakdownBar: View {
    let phase: String
    let value: Double
    let percentage: Double
    let color: Color

    @State private var animatedPercentage: Double = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(phase)
                    .font(.caption)
                    .foregroundColor(.primary)

                Spacer()

                Text(String(format: "%.1f kg (%.0f%%)", value, percentage))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))

                    // Progress
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: geometry.size.width * (animatedPercentage / 100))
                }
            }
            .frame(height: 8)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                animatedPercentage = percentage
            }
        }
    }
}

// MARK: - Breakdown Phase

/// Represents a lifecycle phase in the breakdown.
struct BreakdownPhase: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let value: Double
    let percentage: Double
}

// MARK: - Verification View

/// View showing verification status and details.
struct VerificationView: View {
    let footprint: CarbonFootprint

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()

            HStack(spacing: 8) {
                Image(systemName: "checkmark.shield.fill")
                    .foregroundColor(.green)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Third-Party Verified")
                        .font(.caption)
                        .fontWeight(.medium)

                    if let verifier = footprint.verifierName {
                        Text("By \(verifier)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    if let standard = footprint.verificationStandard {
                        Text(standard)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                if let url = footprint.verificationStatement {
                    Link(destination: url) {
                        Image(systemName: "arrow.up.right.square")
                            .font(.caption)
                    }
                }
            }
        }
    }
}

// MARK: - Verification Badge Small

/// Small verification badge for header.
struct VerificationBadgeSmall: View {
    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: "checkmark.seal.fill")
                .font(.caption2)
                .foregroundColor(.green)

            Text("Verified")
                .font(.caption2)
                .foregroundColor(.green)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Color.green.opacity(0.1))
        .cornerRadius(4)
    }
}

// MARK: - Validity Period View

/// View showing the validity period of the carbon footprint data.
struct ValidityPeriodView: View {
    let from: Date
    let to: Date

    private var isValid: Bool {
        Date() <= to
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Divider()

            HStack(spacing: 8) {
                Image(systemName: isValid ? "calendar.badge.checkmark" : "calendar.badge.exclamationmark")
                    .foregroundColor(isValid ? .green : .orange)

                VStack(alignment: .leading, spacing: 2) {
                    Text(isValid ? "Data Valid Until" : "Data Expired")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)

                    Text("\(formattedDate(from)) - \(formattedDate(to))")
                        .font(.caption)
                        .foregroundColor(isValid ? .primary : .orange)
                }
            }
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - Metric Card

/// Card displaying a single sustainability metric.
struct MetricCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)

            Text(value)
                .font(.headline)

            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(10)
    }
}

// MARK: - Preview Provider

#if DEBUG
struct CarbonFootprintView_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            CarbonFootprintView(
                footprint: CarbonFootprint(
                    pcfCO2eq: 125.5,
                    pcfCalculationMethod: "GHG Protocol",
                    tcfCO2eq: 15.2,
                    ucfCO2eq: 280.0,
                    eolCO2eq: 12.3,
                    verificationStatement: URL(string: "https://example.com/verify"),
                    validityPeriodStart: Date(),
                    validityPeriodEnd: Date().addingTimeInterval(365 * 24 * 60 * 60),
                    verifierName: "TUV Rheinland",
                    verificationStandard: "ISO 14067",
                    waterFootprint: 450,
                    energyEfficiencyClass: "A+",
                    circularEconomyScore: 72,
                    recyclabilityPercentage: 85,
                    recycledContentPercentage: 30
                )
            )
            .padding()
        }
    }
}
#endif

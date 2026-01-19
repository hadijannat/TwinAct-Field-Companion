//
//  TimeSeriesMonitoringView.swift
//  TwinAct Field Companion
//
//  Lightweight placeholder for time-series monitoring.
//  This will be backed by IDTA 02008 submodels and/or live telemetry.
//

import SwiftUI

public struct TimeSeriesMonitoringView: View {

    public let assetId: String?

    public init(assetId: String? = nil) {
        self.assetId = assetId
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                ContentUnavailableView {
                    Label("No Time Series Data", systemImage: "chart.line.uptrend.xyaxis")
                } description: {
                    if let assetId {
                        Text("Monitoring is not yet connected for asset \(assetId).")
                    } else {
                        Text("Select an asset to view live sensor trends.")
                    }
                }

                if AppConfiguration.isDemoMode {
                    DemoMonitoringCard()
                }
            }
            .padding()
            .navigationTitle("Monitoring")
        }
    }
}

private struct DemoMonitoringCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Demo Stream")
                .font(.headline)

            HStack {
                MetricChip(title: "Temp", value: "68.2 °C")
                MetricChip(title: "Vibration", value: "0.12 g")
                MetricChip(title: "RPM", value: "1,480")
            }

            Text("Demo data updates every few seconds in production.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

private struct MetricChip: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(Color(.tertiarySystemBackground), in: Capsule())
    }
}

#Preview {
    TimeSeriesMonitoringView(assetId: "demo-asset-001")
}

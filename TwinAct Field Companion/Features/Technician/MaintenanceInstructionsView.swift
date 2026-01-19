//
//  MaintenanceInstructionsView.swift
//  TwinAct Field Companion
//
//  View for displaying and executing maintenance procedures.
//  Supports step-by-step instructions with timers and checklists.
//

import SwiftUI
import Combine

// MARK: - Maintenance Instructions View

/// List view for maintenance procedures.
public struct MaintenanceInstructionsView: View {

    // MARK: - State

    @StateObject private var viewModel: MaintenanceInstructionsViewModel
    @State private var searchText = ""

    // MARK: - Initialization

    /// Initialize with optional asset ID filter.
    /// - Parameter assetId: Optional asset ID to filter instructions
    public init(assetId: String? = nil) {
        _viewModel = StateObject(wrappedValue: MaintenanceInstructionsViewModel(assetId: assetId))
    }

    // MARK: - Body

    public var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.instructions.isEmpty {
                    loadingView
                } else if viewModel.filteredInstructions.isEmpty {
                    emptyStateView
                } else {
                    instructionsList
                }
            }
            .navigationTitle("Maintenance")
            .searchable(text: $viewModel.searchText, prompt: "Search procedures")
            .refreshable {
                await viewModel.refresh()
            }
            .task {
                await viewModel.loadInstructions()
            }
        }
    }

    // MARK: - Instructions List

    private var instructionsList: some View {
        List {
            // Group by category
            ForEach(viewModel.categorizedInstructions.keys.sorted(), id: \.self) { category in
                Section(category) {
                    ForEach(viewModel.categorizedInstructions[category] ?? []) { instruction in
                        NavigationLink(destination: MaintenanceDetailView(instruction: instruction)) {
                            MaintenanceRowView(instruction: instruction)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Loading procedures...")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Empty State View

    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("No Procedures", systemImage: "list.bullet.clipboard")
        } description: {
            if viewModel.searchText.isEmpty {
                Text("No maintenance procedures available for this asset.")
            } else {
                Text("No procedures match your search.")
            }
        }
    }
}

// MARK: - Maintenance Row View

/// Row view for a maintenance instruction.
struct MaintenanceRowView: View {
    let instruction: MaintenanceInstruction

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Icon
            Image(systemName: instruction.type.iconName)
                .font(.title2)
                .foregroundStyle(instruction.type.color)
                .frame(width: 40, height: 40)
                .background(instruction.type.color.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))

            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(instruction.titleText)
                    .font(.headline)
                    .lineLimit(1)

                if let description = instruction.summary {
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                // Metadata
                HStack(spacing: 12) {
                    Label("\(instruction.stepsList.count) steps", systemImage: "list.number")

                    if let duration = instruction.estimatedDuration {
                        Label(formatDuration(duration), systemImage: "clock")
                    }

                    if instruction.requiresShutdown {
                        Label("Shutdown", systemImage: "power")
                            .foregroundStyle(.orange)
                    }
                }
                .font(.caption)
                .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }

    private func formatDuration(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes) min"
        }
    }
}

// MARK: - Maintenance Detail View

/// Detail view for executing a maintenance procedure step by step.
struct MaintenanceDetailView: View {
    let instruction: MaintenanceInstruction

    @State private var currentStep = 0
    @State private var completedSteps: Set<Int> = []
    @State private var timerSeconds: Int?
    @State private var timerIsRunning = false
    @Environment(\.dismiss) private var dismiss

    private var steps: [MaintenanceStep] {
        instruction.stepsList
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                headerSection

                // Progress
                progressSection

                // Current step
                if currentStep < steps.count {
                    currentStepSection
                }

                // Required items
                if let items = instruction.requiredItems, !items.isEmpty {
                    requiredItemsSection(items: items)
                }

                // Safety warnings
                if let warnings = instruction.safetyWarnings, !warnings.isEmpty {
                    safetyWarningsSection(warnings: warnings)
                }

                // All steps overview
                allStepsSection
            }
            .padding()
        }
        .navigationTitle(instruction.titleText)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if isComplete {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Type badge
            HStack {
                Image(systemName: instruction.type.iconName)
                Text(instruction.type.displayName)
            }
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundStyle(instruction.type.color)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(instruction.type.color.opacity(0.1), in: Capsule())

            // Summary
            if let summary = instruction.summary {
                Text(summary)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Progress Section

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Progress")
                    .font(.headline)
                Spacer()
                Text("\(completedSteps.count)/\(steps.count) steps")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: Double(completedSteps.count), total: Double(steps.count))
                .tint(isComplete ? .green : .accentColor)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Current Step Section

    private var currentStepSection: some View {
        let step = steps[currentStep]

        return VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Step \(currentStep + 1)")
                    .font(.headline)
                Spacer()
                if !completedSteps.contains(currentStep) {
                    Button("Mark Complete") {
                        markStepComplete()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }

            Text(step.instruction)
                .font(.body)

            // Timer if this step has duration
            if let duration = step.duration, duration > 0 {
                timerView(duration: duration)
            }

            // Step image
            if let imageURL = step.imageURL {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                            .cornerRadius(8)
                    case .failure:
                        EmptyView()
                    case .empty:
                        ProgressView()
                    @unknown default:
                        EmptyView()
                    }
                }
                .frame(maxHeight: 200)
            }

            // Navigation
            HStack {
                Button {
                    if currentStep > 0 {
                        currentStep -= 1
                    }
                } label: {
                    Label("Previous", systemImage: "chevron.left")
                }
                .disabled(currentStep == 0)

                Spacer()

                Button {
                    if currentStep < steps.count - 1 {
                        currentStep += 1
                    }
                } label: {
                    Label("Next", systemImage: "chevron.right")
                        .labelStyle(.titleAndIcon)
                }
                .disabled(currentStep >= steps.count - 1)
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Timer View

    private func timerView(duration: Int) -> some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "timer")
                Text(formatTime(timerSeconds ?? duration))
                    .font(.title2.monospacedDigit())
                    .fontWeight(.semibold)
            }

            HStack(spacing: 16) {
                Button {
                    timerIsRunning.toggle()
                } label: {
                    Image(systemName: timerIsRunning ? "pause.fill" : "play.fill")
                }
                .buttonStyle(.borderedProminent)

                Button {
                    timerSeconds = duration
                    timerIsRunning = false
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(Color.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
        .onAppear {
            timerSeconds = duration
        }
    }

    // MARK: - Required Items Section

    private func requiredItemsSection(items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Required Items", systemImage: "wrench.and.screwdriver")
                .font(.headline)

            ForEach(items, id: \.self) { item in
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle")
                        .foregroundStyle(.green)
                    Text(item)
                }
                .font(.subheadline)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Safety Warnings Section

    private func safetyWarningsSection(warnings: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Safety Warnings", systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundStyle(.orange)

            ForEach(warnings, id: \.self) { warning in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.circle")
                        .foregroundStyle(.orange)
                    Text(warning)
                }
                .font(.subheadline)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - All Steps Section

    private var allStepsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("All Steps")
                .font(.headline)

            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                Button {
                    currentStep = index
                } label: {
                    HStack(alignment: .top, spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(completedSteps.contains(index) ? Color.green : Color.secondary.opacity(0.3))
                                .frame(width: 28, height: 28)

                            if completedSteps.contains(index) {
                                Image(systemName: "checkmark")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.white)
                            } else {
                                Text("\(index + 1)")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(index == currentStep ? .primary : .secondary)
                            }
                        }

                        Text(step.instruction)
                            .font(.subheadline)
                            .foregroundStyle(index == currentStep ? .primary : .secondary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)

                        Spacer()
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Helpers

    private var isComplete: Bool {
        completedSteps.count == steps.count
    }

    private func markStepComplete() {
        completedSteps.insert(currentStep)
        if currentStep < steps.count - 1 {
            currentStep += 1
        }
    }

    private func formatTime(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}

// MARK: - Maintenance Instruction UI Adapters

private extension MaintenanceInstruction {
    var titleText: String {
        title.text(for: "en") ?? title.first?.text ?? "Maintenance"
    }

    var summary: String? {
        description?.text(for: "en") ?? description?.first?.text
    }

    var type: MaintenanceType {
        maintenanceType
    }

    var stepsList: [MaintenanceStep] {
        steps ?? []
    }

    var requiredItems: [String]? {
        let items = (requiredTools ?? []) + (requiredParts ?? [])
        return items.isEmpty ? nil : items
    }

    var safetyWarnings: [String]? {
        safetyInstructions?.map { $0.text }
    }

    var requiresShutdown: Bool {
        false
    }
}

private extension MaintenanceType {
    var color: Color {
        switch self {
        case .preventive:
            return .blue
        case .corrective:
            return .orange
        case .predictive:
            return .green
        case .conditionBased:
            return .purple
        }
    }
}

private extension MaintenanceStep {
    var instruction: String {
        description.text(for: "en") ?? description.first?.text ?? "Step"
    }

    var imageURL: URL? {
        image
    }
}

// MARK: - Maintenance Instructions View Model

/// View model for maintenance instructions.
@MainActor
public final class MaintenanceInstructionsViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published public private(set) var instructions: [MaintenanceInstruction] = []
    @Published public var isLoading: Bool = false
    @Published public var searchText: String = ""

    // MARK: - Properties

    private let assetId: String?

    // MARK: - Computed Properties

    /// Filtered instructions based on search text.
    public var filteredInstructions: [MaintenanceInstruction] {
        if searchText.isEmpty {
            return instructions
        }

        let lowercasedSearch = searchText.lowercased()
        return instructions.filter { instruction in
            instruction.titleText.lowercased().contains(lowercasedSearch) ||
            (instruction.summary?.lowercased().contains(lowercasedSearch) ?? false) ||
            instruction.type.displayName.lowercased().contains(lowercasedSearch)
        }
    }

    /// Instructions grouped by category.
    public var categorizedInstructions: [String: [MaintenanceInstruction]] {
        Dictionary(grouping: filteredInstructions) { $0.type.displayName }
    }

    // MARK: - Initialization

    public init(assetId: String? = nil) {
        self.assetId = assetId
        setupDemoData()
    }

    // MARK: - Public Methods

    public func loadInstructions() async {
        guard !isLoading else { return }

        isLoading = true

        // In production, load from submodel service
        // For now, use demo data

        isLoading = false
    }

    public func refresh() async {
        await loadInstructions()
    }

    // MARK: - Private Methods

    private func setupDemoData() {
        func ls(_ text: String) -> LangString {
            LangString(language: "en", text: text)
        }

        instructions = [
            MaintenanceInstruction(
                id: "oil-change",
                title: [ls("Oil Change Procedure")],
                description: [ls("Standard oil change for main drive system with filter replacement.")],
                maintenanceType: .preventive,
                steps: [
                    MaintenanceStep(stepNumber: 1, description: [ls("Ensure the machine is powered off and locked out")]),
                    MaintenanceStep(stepNumber: 2, description: [ls("Allow oil to cool for at least 15 minutes")], duration: 900),
                    MaintenanceStep(stepNumber: 3, description: [ls("Position drain pan under the oil drain plug")]),
                    MaintenanceStep(stepNumber: 4, description: [ls("Remove drain plug and allow oil to drain completely")], duration: 600),
                    MaintenanceStep(stepNumber: 5, description: [ls("Replace oil filter with new filter (P/N: OIL-FLT-001)")]),
                    MaintenanceStep(stepNumber: 6, description: [ls("Reinstall drain plug with new gasket")]),
                    MaintenanceStep(stepNumber: 7, description: [ls("Fill with 5 liters of ISO VG 68 hydraulic oil")]),
                    MaintenanceStep(stepNumber: 8, description: [ls("Run machine for 5 minutes and check for leaks")], duration: 300)
                ],
                requiredTools: ["Drain pan", "Wrench set"],
                requiredParts: ["5L ISO VG 68 oil", "Oil filter P/N: OIL-FLT-001", "Drain plug gasket"],
                safetyInstructions: [ls("Ensure lockout/tagout is complete"), ls("Hot oil can cause burns"), ls("Use proper PPE")],
                estimatedDuration: 2700
            ),
            MaintenanceInstruction(
                id: "belt-tension",
                title: [ls("Belt Tension Adjustment")],
                description: [ls("Adjust drive belt tension to specification.")],
                maintenanceType: .corrective,
                steps: [
                    MaintenanceStep(stepNumber: 1, description: [ls("Power off machine and engage safety lockout")]),
                    MaintenanceStep(stepNumber: 2, description: [ls("Remove belt guard cover")]),
                    MaintenanceStep(stepNumber: 3, description: [ls("Check current belt tension with tension gauge")]),
                    MaintenanceStep(stepNumber: 4, description: [ls("Loosen motor mounting bolts")]),
                    MaintenanceStep(stepNumber: 5, description: [ls("Adjust motor position until tension reads 45-50 lbs")]),
                    MaintenanceStep(stepNumber: 6, description: [ls("Tighten motor mounting bolts to 35 Nm")]),
                    MaintenanceStep(stepNumber: 7, description: [ls("Verify belt alignment")]),
                    MaintenanceStep(stepNumber: 8, description: [ls("Reinstall belt guard")])
                ],
                requiredTools: ["Belt tension gauge", "Torque wrench", "Allen key set"],
                safetyInstructions: [ls("Complete lockout before work"), ls("Keep hands clear of pulleys")],
                estimatedDuration: 1800
            )
        ]
    }
}

// MARK: - Preview

#Preview {
    MaintenanceInstructionsView(assetId: "demo-asset-001")
}

//
//  NameplateCardView.swift
//  TwinAct Field Companion
//
//  Digital Nameplate card view displaying manufacturer and product information
//  per IDTA 02006-2-0 specification.
//

import SwiftUI

// MARK: - Nameplate Card View

/// Card view displaying Digital Nameplate information.
/// Shows manufacturer info, product identification, and compliance markings.
public struct NameplateCardView: View {

    // MARK: - Properties

    let nameplate: DigitalNameplate
    @State private var isExpanded: Bool = true

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
                Image(systemName: "tag.fill")
                    .font(.title3)
                    .foregroundColor(.blue)
                    .frame(width: 32)

                // Title
                VStack(alignment: .leading, spacing: 2) {
                    Text("Digital Nameplate")
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text(nameplate.manufacturerName ?? "Unknown Manufacturer")
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
            // Manufacturer header with logo
            manufacturerHeader

            // Key-value pairs in grid
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 12) {
                NameplateRow(label: "Serial Number", value: nameplate.serialNumber)
                NameplateRow(label: "Order Code", value: nameplate.orderCode)
                NameplateRow(label: "Production Date", value: formattedDate(nameplate.productionDate))
                NameplateRow(label: "Country", value: nameplate.countryOfOrigin)
                NameplateRow(label: "Hardware", value: nameplate.hardwareVersion)
                NameplateRow(label: "Firmware", value: nameplate.firmwareVersion)
                NameplateRow(label: "Software", value: nameplate.softwareVersion)
                NameplateRow(label: "Year Built", value: nameplate.yearOfConstruction.map { String($0) })
            }

            // Product family/type info
            if nameplate.manufacturerProductFamily != nil || nameplate.manufacturerProductType != nil {
                productInfo
            }

            // Markings/Certifications
            if let markings = nameplate.markings, !markings.isEmpty {
                MarkingsView(markings: markings)
            }

            // Contact info
            if let address = nameplate.manufacturerAddress {
                addressView(address)
            }
        }
    }

    // MARK: - Manufacturer Header

    private var manufacturerHeader: some View {
        HStack(spacing: 12) {
            // Manufacturer logo
            if let logoURL = nameplate.manufacturerLogo {
                AsyncImage(url: logoURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: 80, maxHeight: 40)

                    default:
                        manufacturerPlaceholder
                    }
                }
            } else {
                manufacturerPlaceholder
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(nameplate.manufacturerName ?? "Unknown Manufacturer")
                    .font(.headline)

                if let designation = nameplate.manufacturerProductDesignation {
                    Text(designation)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
        .padding(.bottom, 4)
    }

    private var manufacturerPlaceholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.tertiarySystemBackground))
                .frame(width: 60, height: 40)

            Image(systemName: "building.2.fill")
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Product Info

    private var productInfo: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()

            Text("Product Information")
                .font(.caption)
                .foregroundColor(.secondary)
                .textCase(.uppercase)

            if let family = nameplate.manufacturerProductFamily {
                HStack {
                    Text("Product Family:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(family)
                        .font(.caption)
                        .fontWeight(.medium)
                }
            }

            if let type = nameplate.manufacturerProductType {
                HStack {
                    Text("Product Type:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(type)
                        .font(.caption)
                        .fontWeight(.medium)
                }
            }
        }
    }

    // MARK: - Address View

    private func addressView(_ address: Address) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()

            HStack {
                Image(systemName: "location.fill")
                    .font(.caption)
                    .foregroundColor(.blue)

                Text("Manufacturer Address")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
            }

            Text(address.formattedAddress)
                .font(.caption)
                .foregroundColor(.primary)

            // Contact info
            if let phone = address.phone {
                HStack(spacing: 4) {
                    Image(systemName: "phone.fill")
                        .font(.caption2)
                        .foregroundColor(.green)
                    Link(phone, destination: URL(string: "tel:\(phone)")!)
                        .font(.caption)
                }
            }

            if let email = address.email {
                HStack(spacing: 4) {
                    Image(systemName: "envelope.fill")
                        .font(.caption2)
                        .foregroundColor(.blue)
                    Link(email, destination: URL(string: "mailto:\(email)")!)
                        .font(.caption)
                }
            }
        }
    }

    // MARK: - Helpers

    private func formattedDate(_ date: Date?) -> String? {
        guard let date = date else { return nil }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - Nameplate Row

/// Single row in the nameplate grid displaying a label-value pair.
struct NameplateRow: View {
    let label: String
    let value: String?

    var body: some View {
        if let value = value, !value.isEmpty {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)

                Text(value)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Markings View

/// View displaying compliance markings and certifications.
struct MarkingsView: View {
    let markings: [Marking]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()

            HStack {
                Image(systemName: "checkmark.seal.fill")
                    .font(.caption)
                    .foregroundColor(.green)

                Text("Certifications & Markings")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
            }

            // Markings grid
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 70), spacing: 8)
            ], spacing: 8) {
                ForEach(markings, id: \.name) { marking in
                    MarkingBadge(marking: marking)
                }
            }
        }
    }
}

// MARK: - Marking Badge

/// Individual marking/certification badge.
struct MarkingBadge: View {
    let marking: Marking

    var body: some View {
        VStack(spacing: 4) {
            if let logoURL = marking.file {
                AsyncImage(url: logoURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 40, height: 40)

                    default:
                        markingPlaceholder
                    }
                }
            } else {
                markingPlaceholder
            }

            Text(marking.name)
                .font(.caption2)
                .lineLimit(1)
                .foregroundColor(.secondary)
        }
        .frame(width: 70)
        .padding(.vertical, 8)
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(8)
    }

    private var markingPlaceholder: some View {
        ZStack {
            Circle()
                .fill(markingColor.opacity(0.2))
                .frame(width: 40, height: 40)

            Text(marking.name.prefix(2).uppercased())
                .font(.caption.bold())
                .foregroundColor(markingColor)
        }
    }

    private var markingColor: Color {
        // Common marking colors
        switch marking.name.uppercased() {
        case "CE":
            return .blue
        case "UL", "UL LISTED":
            return .red
        case "FCC":
            return .purple
        case "ROHS":
            return .green
        case "WEEE":
            return .orange
        default:
            return .gray
        }
    }
}

// MARK: - Compact Nameplate View

/// Compact version of nameplate for list displays.
public struct CompactNameplateView: View {
    let nameplate: DigitalNameplate

    public var body: some View {
        HStack(spacing: 12) {
            // Manufacturer logo or placeholder
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.tertiarySystemBackground))
                    .frame(width: 50, height: 50)

                if let logoURL = nameplate.manufacturerLogo {
                    AsyncImage(url: logoURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } placeholder: {
                        Image(systemName: "building.2.fill")
                            .foregroundColor(.gray)
                    }
                    .frame(width: 40, height: 40)
                } else {
                    Image(systemName: "building.2.fill")
                        .foregroundColor(.gray)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(nameplate.manufacturerProductDesignation ?? nameplate.manufacturerName ?? "Unknown")
                    .font(.subheadline)
                    .fontWeight(.medium)

                if let serial = nameplate.serialNumber {
                    Text("S/N: \(serial)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if let markings = nameplate.markings, !markings.isEmpty {
                HStack(spacing: 2) {
                    ForEach(markings.prefix(3), id: \.name) { marking in
                        Text(marking.name)
                            .font(.caption2)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(4)
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Preview Provider

#if DEBUG
struct NameplateCardView_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            VStack(spacing: 20) {
                NameplateCardView(
                    nameplate: DigitalNameplate(
                        manufacturerName: "Siemens AG",
                        manufacturerProductDesignation: "SIMATIC S7-1500 PLC",
                        manufacturerProductFamily: "SIMATIC",
                        manufacturerProductType: "S7-1500",
                        orderCode: "6ES7 511-1AK02-0AB0",
                        serialNumber: "SN-2024-123456",
                        productionDate: Date(),
                        countryOfOrigin: "Germany",
                        yearOfConstruction: 2024,
                        hardwareVersion: "2.0",
                        firmwareVersion: "3.1.2",
                        softwareVersion: "V3.0",
                        manufacturerAddress: Address(
                            street: "Werner-von-Siemens-Strasse 1",
                            zipCode: "80333",
                            city: "Munich",
                            country: "Germany",
                            phone: "+49 89 636-00",
                            email: "info@siemens.com"
                        ),
                        markings: [
                            Marking(name: "CE"),
                            Marking(name: "UL"),
                            Marking(name: "RoHS")
                        ]
                    )
                )

                CompactNameplateView(
                    nameplate: DigitalNameplate(
                        manufacturerName: "ABB",
                        manufacturerProductDesignation: "AC500 PLC",
                        serialNumber: "ABB-2024-789"
                    )
                )
            }
            .padding()
        }
    }
}
#endif

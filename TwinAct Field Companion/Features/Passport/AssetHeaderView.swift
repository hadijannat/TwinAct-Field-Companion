//
//  AssetHeaderView.swift
//  TwinAct Field Companion
//
//  Asset header component displaying product image and basic information.
//  Used at the top of the Passport view.
//

import SwiftUI

// MARK: - Asset Header View

/// Asset header with product image and basic info.
/// Displays prominently at the top of the Passport view.
public struct AssetHeaderView: View {

    // MARK: - Properties

    let asset: Asset?

    // MARK: - Body

    public var body: some View {
        VStack(spacing: 16) {
            // Product image or placeholder
            productImage

            // Asset name
            Text(asset?.name ?? "Unknown Asset")
                .font(.title2.bold())
                .multilineTextAlignment(.center)

            // Manufacturer and model
            if let manufacturer = asset?.manufacturer {
                Text(manufacturer)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            // Asset ID badge
            if let id = asset?.id {
                AssetIdBadge(id: id)
            }

            // Quick info pills
            if asset != nil {
                quickInfoPills
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    // MARK: - Product Image

    private var productImage: some View {
        Group {
            if let imageURL = asset?.thumbnailURL {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .frame(width: 200, height: 200)

                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)

                    case .failure:
                        placeholderImage

                    @unknown default:
                        placeholderImage
                    }
                }
            } else {
                placeholderImage
            }
        }
    }

    private var placeholderImage: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [Color.blue.opacity(0.2), Color.purple.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(spacing: 8) {
                Image(systemName: "cube.box.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.blue.opacity(0.6))

                Text("No Image Available")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: 200, height: 160)
    }

    // MARK: - Quick Info Pills

    private var quickInfoPills: some View {
        HStack(spacing: 8) {
            if let serial = asset?.serialNumber {
                InfoPill(icon: "number", text: serial, color: .blue)
            }

            if let model = asset?.model {
                InfoPill(icon: "cpu", text: model, color: .purple)
            }

            if let assetType = asset?.assetType {
                InfoPill(icon: "tag", text: assetType, color: .orange)
            }
        }
        .font(.caption)
    }
}

// MARK: - Asset ID Badge

/// Compact badge displaying the asset ID.
struct AssetIdBadge: View {
    let id: String
    @State private var isCopied = false

    var body: some View {
        Button {
            copyToClipboard()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                    .font(.caption2)

                Text(truncatedId)
                    .font(.caption.monospaced())
                    .lineLimit(1)
            }
            .foregroundColor(isCopied ? .green : .secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(.tertiarySystemBackground))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Asset ID: \(id). Tap to copy.")
    }

    private var truncatedId: String {
        if id.count > 40 {
            let start = id.prefix(16)
            let end = id.suffix(12)
            return "\(start)...\(end)"
        }
        return id
    }

    private func copyToClipboard() {
        UIPasteboard.general.string = id
        withAnimation(.easeInOut(duration: 0.2)) {
            isCopied = true
        }

        // Reset after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(.easeInOut(duration: 0.2)) {
                isCopied = false
            }
        }
    }
}

// MARK: - Info Pill

/// Small pill-shaped info display.
struct InfoPill: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundColor(color)

            Text(text)
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.1))
        .cornerRadius(6)
    }
}

// MARK: - Large Asset Header View

/// Larger version of asset header for detail views.
public struct LargeAssetHeaderView: View {
    let asset: Asset?
    let nameplate: DigitalNameplate?

    public init(asset: Asset?, nameplate: DigitalNameplate? = nil) {
        self.asset = asset
        self.nameplate = nameplate
    }

    public var body: some View {
        VStack(spacing: 20) {
            // Large product image
            if let imageURL = nameplate?.productImage ?? asset?.thumbnailURL {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 280)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 6)

                    default:
                        largePlaceholder
                    }
                }
            } else {
                largePlaceholder
            }

            // Info
            VStack(spacing: 8) {
                Text(nameplate?.manufacturerProductDesignation ?? asset?.name ?? "Unknown Asset")
                    .font(.title.bold())
                    .multilineTextAlignment(.center)

                if let manufacturer = nameplate?.manufacturerName ?? asset?.manufacturer {
                    HStack(spacing: 8) {
                        // Manufacturer logo
                        if let logoURL = nameplate?.manufacturerLogo {
                            AsyncImage(url: logoURL) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                            } placeholder: {
                                EmptyView()
                            }
                            .frame(height: 20)
                        }

                        Text(manufacturer)
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                }

                if let id = asset?.id {
                    AssetIdBadge(id: id)
                }
            }
        }
        .padding(.vertical)
    }

    private var largePlaceholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.blue.opacity(0.15),
                            Color.purple.opacity(0.1),
                            Color.teal.opacity(0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(spacing: 12) {
                Image(systemName: "cube.transparent.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue.opacity(0.6), .purple.opacity(0.4)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                Text("Digital Twin")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .frame(height: 220)
    }
}

// MARK: - Preview Provider

#if DEBUG
struct AssetHeaderView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Regular header
            AssetHeaderView(
                asset: Asset(
                    id: "https://example.com/aas/motor-123456",
                    name: "Electric Motor XR-500",
                    manufacturer: "Siemens AG",
                    serialNumber: "SN-2024-001234",
                    model: "XR-500-3PH"
                )
            )
            .previewDisplayName("With Asset")

            // Without image
            AssetHeaderView(asset: nil)
                .previewDisplayName("No Asset")

            // Large header
            LargeAssetHeaderView(
                asset: Asset(
                    id: "https://example.com/aas/pump-789",
                    name: "Centrifugal Pump CP-200",
                    manufacturer: "Grundfos"
                ),
                nameplate: DigitalNameplate(
                    manufacturerName: "Grundfos",
                    manufacturerProductDesignation: "Centrifugal Pump CP-200"
                )
            )
            .previewDisplayName("Large Header")
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
#endif

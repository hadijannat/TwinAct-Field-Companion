//
//  AppState.swift
//  TwinAct Field Companion
//
//  Shared app state for active asset context and cross-feature coordination.
//

import Foundation
import Combine

@MainActor
final class AppState: ObservableObject {

    @Published var selectedAsset: Asset?
    @Published var lastDiscoveryAt: Date?

    private let assetStorageKey = "TwinAct.SelectedAssetSnapshot"
    private let discoveryStorageKey = "TwinAct.LastDiscoveryAt"

    init() {
        if let data = UserDefaults.standard.data(forKey: assetStorageKey),
           let snapshot = try? JSONDecoder().decode(AssetSnapshot.self, from: data) {
            selectedAsset = snapshot.toAsset()
            lastDiscoveryAt = UserDefaults.standard.object(forKey: discoveryStorageKey) as? Date
        } else if AppConfiguration.isDemoMode {
            selectedAsset = DemoData.asset
        }
    }

    func setSelectedAsset(_ asset: Asset) {
        selectedAsset = asset
        lastDiscoveryAt = Date()
        persistSnapshot(for: asset)
    }

    func clearSelection() {
        selectedAsset = nil
        lastDiscoveryAt = nil
        UserDefaults.standard.removeObject(forKey: assetStorageKey)
        UserDefaults.standard.removeObject(forKey: discoveryStorageKey)
    }

    private func persistSnapshot(for asset: Asset) {
        let snapshot = AssetSnapshot(from: asset)
        if let data = try? JSONEncoder().encode(snapshot) {
            UserDefaults.standard.set(data, forKey: assetStorageKey)
            if let lastDiscoveryAt {
                UserDefaults.standard.set(lastDiscoveryAt, forKey: discoveryStorageKey)
            }
        }
    }
}

private struct AssetSnapshot: Codable {
    let id: String
    let name: String
    let assetType: String?
    let manufacturer: String?
    let serialNumber: String?
    let model: String?
    let thumbnailURL: String?
    let availableSubmodels: [String]

    init(from asset: Asset) {
        id = asset.id
        name = asset.name
        assetType = asset.assetType
        manufacturer = asset.manufacturer
        serialNumber = asset.serialNumber
        model = asset.model
        thumbnailURL = asset.thumbnailURL?.absoluteString
        availableSubmodels = asset.availableSubmodels.map { $0.rawValue }
    }

    func toAsset() -> Asset {
        let submodels = Set(availableSubmodels.compactMap { SubmodelType(rawValue: $0) })
        return Asset(
            id: id,
            name: name,
            assetType: assetType,
            manufacturer: manufacturer,
            serialNumber: serialNumber,
            model: model,
            thumbnailURL: thumbnailURL.flatMap { URL(string: $0) },
            aasDescriptor: nil,
            availableSubmodels: submodels
        )
    }
}

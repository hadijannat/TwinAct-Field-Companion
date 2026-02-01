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
    let aasId: String
    let globalAssetId: String?
    let name: String
    let assetType: String?
    let manufacturer: String?
    let serialNumber: String?
    let model: String?
    let thumbnailURL: String?
    let availableSubmodels: [String]

    private enum CodingKeys: String, CodingKey {
        case id
        case aasId
        case globalAssetId
        case name
        case assetType
        case manufacturer
        case serialNumber
        case model
        case thumbnailURL
        case availableSubmodels
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        aasId = try container.decodeIfPresent(String.self, forKey: .aasId) ?? id
        globalAssetId = try container.decodeIfPresent(String.self, forKey: .globalAssetId)
        name = try container.decode(String.self, forKey: .name)
        assetType = try container.decodeIfPresent(String.self, forKey: .assetType)
        manufacturer = try container.decodeIfPresent(String.self, forKey: .manufacturer)
        serialNumber = try container.decodeIfPresent(String.self, forKey: .serialNumber)
        model = try container.decodeIfPresent(String.self, forKey: .model)
        thumbnailURL = try container.decodeIfPresent(String.self, forKey: .thumbnailURL)
        availableSubmodels = try container.decodeIfPresent([String].self, forKey: .availableSubmodels) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(aasId, forKey: .aasId)
        try container.encodeIfPresent(globalAssetId, forKey: .globalAssetId)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(assetType, forKey: .assetType)
        try container.encodeIfPresent(manufacturer, forKey: .manufacturer)
        try container.encodeIfPresent(serialNumber, forKey: .serialNumber)
        try container.encodeIfPresent(model, forKey: .model)
        try container.encodeIfPresent(thumbnailURL, forKey: .thumbnailURL)
        try container.encode(availableSubmodels, forKey: .availableSubmodels)
    }

    init(from asset: Asset) {
        id = asset.id
        aasId = asset.aasId
        globalAssetId = asset.globalAssetId
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
            aasId: aasId,
            globalAssetId: globalAssetId,
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

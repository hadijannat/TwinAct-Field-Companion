//
//  UITestHarness.swift
//  TwinAct Field Companion
//
//  Helpers to configure deterministic UI test state (demo data, AI providers, AASX import).
//

import Foundation
import os.log
import ZIPFoundation
#if os(iOS)
import UIKit
#endif

@MainActor
enum UITestHarness {
    private static let logger = Logger(
        subsystem: AppConfiguration.AppInfo.bundleIdentifier,
        category: "UITestHarness"
    )
    private static let testAASXFilename = "UITest-Import.aasx"

    static func configureIfNeeded(container: DependencyContainer) {
        guard AppConfiguration.isUITest else { return }

        let env = ProcessInfo.processInfo.environment

        if envFlag("UITEST_FORCE_CLOUD_INFERENCE", defaultValue: true) {
            UserDefaults.standard.set(false, forKey: "useOnDeviceInference")
        }

        if let apiKey = env["UITEST_OPENROUTER_API_KEY"] ?? env["OPENROUTER_API_KEY"],
           !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let manager = container.aiProviderManager
            manager.storeAPIKey(apiKey, for: .openRouter)

            var config = manager.configuration(for: .openRouter)
            if let model = env["UITEST_OPENROUTER_MODEL"],
               !model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                config.modelId = model
            }
            manager.saveConfiguration(config)
            manager.activeProviderType = .openRouter
            logger.info("Configured OpenRouter for UI tests.")
        }

        let shouldAutoImport = envFlag("UITEST_IMPORT_AASX", defaultValue: false)
        let shouldPrepare = envFlag("UITEST_PREPARE_AASX", defaultValue: shouldAutoImport)
        if shouldPrepare {
            Task { @MainActor in
                let assetId = env["UITEST_AASX_ASSET_ID"] ?? DemoData.assetId
                let pdfText = env["UITEST_AASX_PDF_TEXT"]
                    ?? "Maintenance interval: 6 months. Follow safety procedures before servicing."
                do {
                    let aasxURL = try createTestAASXPackage(assetId: assetId, pdfText: pdfText)
                    let preparedURL = try copyAASXToDocuments(aasxURL)
                    UserDefaults.standard.set(preparedURL.lastPathComponent, forKey: "UITEST_AASX_FILENAME")
                    logger.info("Prepared UI test AASX: \(preparedURL.lastPathComponent, privacy: .public)")

                    if shouldAutoImport {
                        let importManager = AASXImportManager()
                        await importManager.importFromFile(preparedURL, assetIdOverride: assetId)
                        logger.info("Imported UI test AASX for asset: \(assetId, privacy: .public)")
                    }
                } catch {
                    logger.error("Failed to import UI test AASX: \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - Helpers

    private static func envFlag(_ key: String, defaultValue: Bool) -> Bool {
        guard let raw = ProcessInfo.processInfo.environment[key]?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
              !raw.isEmpty else {
            return defaultValue
        }
        return raw == "1" || raw == "true" || raw == "yes"
    }

    private static func createTestAASXPackage(assetId: String, pdfText: String) throws -> URL {
        let fileManager = FileManager.default
        let baseDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: baseDir, withIntermediateDirectories: true)

        let relsDir = baseDir.appendingPathComponent("_rels", isDirectory: true)
        let aasDir = baseDir.appendingPathComponent("aas", isDirectory: true)
        let docsDir = baseDir.appendingPathComponent("documents", isDirectory: true)
        try fileManager.createDirectory(at: relsDir, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: aasDir, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: docsDir, withIntermediateDirectories: true)

        let contentTypesURL = baseDir.appendingPathComponent("[Content_Types].xml")
        let relsURL = relsDir.appendingPathComponent(".rels")
        let aasURL = aasDir.appendingPathComponent("aas.json")
        let pdfURL = docsDir.appendingPathComponent("maintenance.pdf")

        let contentTypes = """
        <?xml version="1.0" encoding="UTF-8"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
          <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
          <Default Extension="json" ContentType="application/json"/>
          <Default Extension="pdf" ContentType="application/pdf"/>
        </Types>
        """

        let rels = """
        <?xml version="1.0" encoding="UTF-8"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
          <Relationship Id="rId1" Type="http://www.admin-shell.io/aasx/relationships/aas-spec" Target="/aas/aas.json"/>
        </Relationships>
        """

        let aasJSON = """
        {
          "id": "\(assetId)",
          "assetInformation": {
            "globalAssetId": "\(assetId)"
          }
        }
        """

        try contentTypes.data(using: .utf8)?.write(to: contentTypesURL, options: .atomic)
        try rels.data(using: .utf8)?.write(to: relsURL, options: .atomic)
        try aasJSON.data(using: .utf8)?.write(to: aasURL, options: .atomic)

#if os(iOS)
        try createPDF(at: pdfURL, text: pdfText)
#else
        try pdfText.data(using: .utf8)?.write(to: pdfURL, options: .atomic)
#endif

        let aasxURL = fileManager.temporaryDirectory
            .appendingPathComponent("ui-test-\(UUID().uuidString)")
            .appendingPathExtension("aasx")

        let archive = try Archive(url: aasxURL, accessMode: .create, pathEncoding: nil)
        let enumerator = fileManager.enumerator(
            at: baseDir,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )
        while let fileURL = enumerator?.nextObject() as? URL {
            let isRegular = (try? fileURL.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) ?? false
            if !isRegular { continue }
            let relativePath = fileURL.path.replacingOccurrences(of: baseDir.path + "/", with: "")
            try archive.addEntry(with: relativePath, relativeTo: baseDir)
        }

        return aasxURL
    }

    private static func copyAASXToDocuments(_ url: URL) throws -> URL {
        let fileManager = FileManager.default
        guard let documentsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw CocoaError(.fileNoSuchFile)
        }
        let destination = documentsDir.appendingPathComponent(testAASXFilename)
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        try fileManager.copyItem(at: url, to: destination)
        return destination
    }

#if os(iOS)
    private static func createPDF(at url: URL, text: String) throws {
        let bounds = CGRect(x: 0, y: 0, width: 612, height: 792)
        let renderer = UIGraphicsPDFRenderer(bounds: bounds)
        try renderer.writePDF(to: url) { context in
            context.beginPage()
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.lineBreakMode = .byWordWrapping
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 16),
                .paragraphStyle: paragraphStyle
            ]
            let rect = CGRect(x: 40, y: 40, width: bounds.width - 80, height: bounds.height - 80)
            text.draw(in: rect, withAttributes: attributes)
        }
    }
#endif
}

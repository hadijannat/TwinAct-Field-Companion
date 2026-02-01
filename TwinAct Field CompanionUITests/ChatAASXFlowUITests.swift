//
//  ChatAASXFlowUITests.swift
//  TwinAct Field CompanionUITests
//
//  End-to-end UI test: configure OpenRouter, import AASX, open chat, ask question.
//

import XCTest

final class ChatAASXFlowUITests: XCTestCase {

    func testAASXImportAndChatWithOpenRouter() throws {
        let environment = ProcessInfo.processInfo.environment
        guard let apiKey = environment["OPENROUTER_API_KEY"], !apiKey.isEmpty else {
            throw XCTSkip("OPENROUTER_API_KEY not set in test environment.")
        }

        let app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launchEnvironment["UITEST_MODE"] = "1"
        app.launchEnvironment["UITEST_DEMO_MODE"] = "1"
        app.launchEnvironment["UITEST_OPENROUTER_API_KEY"] = apiKey
        app.launchEnvironment["UITEST_OPENROUTER_MODEL"] = "anthropic/claude-sonnet-4"
        app.launchEnvironment["UITEST_PREPARE_AASX"] = "1"
        app.launchEnvironment["UITEST_AASX_ASSET_ID"] = "urn:hydraflow:aas:cre95-3-2-96516050"
        app.launchEnvironment["UITEST_AASX_PDF_TEXT"] = "Maintenance interval: 6 months. Keep records for compliance."
        app.launch()

        // Open demo asset passport
        let demoAssetButton = app.buttons["Demo Asset"]
        XCTAssertTrue(demoAssetButton.waitForExistence(timeout: 8), "Demo Asset card not visible.")
        demoAssetButton.tap()

        // Open chat
        let chatButton = app.buttons["Chat with AI"]
        XCTAssertTrue(chatButton.waitForExistence(timeout: 8), "Chat button not visible.")
        chatButton.tap()

        // Go back to passport to import via file picker
        let doneButton = app.buttons["Done"]
        if doneButton.waitForExistence(timeout: 5) {
            doneButton.tap()
        }

        // Open import menu
        let importMenu = app.buttons["Import AASX"]
        XCTAssertTrue(importMenu.waitForExistence(timeout: 8), "Import menu not visible.")
        importMenu.tap()
        let importFromFiles = app.buttons["Import from Files"]
        XCTAssertTrue(importFromFiles.waitForExistence(timeout: 8), "Import from Files not visible.")
        importFromFiles.tap()

        // Select file from file picker
        selectFileNamed("UITest-Import.aasx", in: app)

        // Open chat again
        XCTAssertTrue(chatButton.waitForExistence(timeout: 8), "Chat button not visible after import.")
        chatButton.tap()

        let indexedLabel = app.staticTexts["Documents indexed"]
        XCTAssertTrue(indexedLabel.waitForExistence(timeout: 30), "Indexed documents status not visible.")

        // Send a question
        let input = app.textFields["chat.input"]
        XCTAssertTrue(input.waitForExistence(timeout: 8), "Chat input not visible.")
        input.tap()
        input.typeText("What does the maintenance document say about intervals?")

        let sendButton = app.buttons["chat.sendButton"]
        XCTAssertTrue(sendButton.waitForExistence(timeout: 8), "Send button not visible.")
        sendButton.tap()

        // Wait for generation to finish (button label flips back to Send Message)
        let sendLabelPredicate = NSPredicate(format: "label == 'Send Message'")
        expectation(for: sendLabelPredicate, evaluatedWith: sendButton, handler: nil)
        waitForExpectations(timeout: 60)
    }

    private func selectFileNamed(_ filename: String, in app: XCUIApplication) {
        let candidateApps = [
            app,
            XCUIApplication(bundleIdentifier: "com.apple.DocumentsApp")
        ]

        for candidate in candidateApps {
            if candidate.buttons["Browse"].waitForExistence(timeout: 3) {
                candidate.buttons["Browse"].tap()
            }

            if candidate.buttons["On My iPhone"].waitForExistence(timeout: 5) {
                candidate.buttons["On My iPhone"].tap()
            }

            if candidate.staticTexts["TwinAct Field"].waitForExistence(timeout: 5) {
                candidate.staticTexts["TwinAct Field"].tap()
            }

            if candidate.staticTexts[filename].waitForExistence(timeout: 5) {
                candidate.staticTexts[filename].tap()
                return
            }
        }

        XCTFail("Failed to select \(filename) from file picker.")
    }
}

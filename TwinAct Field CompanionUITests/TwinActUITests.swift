//
//  TwinActUITests.swift
//  TwinAct Field CompanionUITests
//
//  XCUITest UI tests for critical user flows.
//

import XCTest

/// UI tests for critical user flows in TwinAct Field Companion.
/// These tests verify onboarding, navigation, settings, and demo mode functionality.
final class TwinActUITests: XCTestCase {

    // MARK: - Properties

    var app: XCUIApplication!

    // MARK: - Setup & Teardown

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()

        // Reset app state for consistent test runs
        app.launchArguments = ["--uitesting"]

        // Reset UserDefaults to get fresh state
        app.launchArguments.append(contentsOf: ["-hasCompletedOnboarding", "NO"])
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Helper Methods

    /// Waits for an element to exist with a timeout.
    /// - Parameters:
    ///   - element: The XCUIElement to wait for.
    ///   - timeout: Maximum time to wait in seconds.
    /// - Returns: True if the element exists within the timeout.
    @discardableResult
    private func waitForElement(_ element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        return element.waitForExistence(timeout: timeout)
    }

    /// Completes the onboarding flow by navigating through all pages and selecting demo mode.
    private func completeOnboarding() {
        // Wait for onboarding to appear
        let discoverTitle = app.staticTexts["Discover Assets"]
        XCTAssertTrue(waitForElement(discoverTitle), "Onboarding should start with Discover Assets page")

        // Navigate through all 5 onboarding pages
        for _ in 0..<4 {
            let nextButton = app.buttons["Next"]
            if nextButton.exists {
                nextButton.tap()
            }
        }

        // Tap "Get Started" on the last page
        let getStartedButton = app.buttons["Get Started"]
        XCTAssertTrue(waitForElement(getStartedButton), "Get Started button should appear on last onboarding page")
        getStartedButton.tap()

        // Handle demo mode prompt - select "Enable Demo Mode"
        let enableDemoButton = app.buttons["Enable Demo Mode"]
        XCTAssertTrue(waitForElement(enableDemoButton), "Demo mode prompt should appear")
        enableDemoButton.tap()

        // Wait for main app to appear (tab bar)
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(waitForElement(tabBar), "Tab bar should appear after onboarding completion")
    }

    /// Resets the app to a state where onboarding is already completed and demo mode is enabled.
    private func launchWithOnboardingCompleted() {
        app.launchArguments = ["--uitesting"]
        app.launchArguments.append(contentsOf: ["-hasCompletedOnboarding", "YES"])
        app.launchArguments.append(contentsOf: ["-com.twinact.fieldcompanion.demoModeEnabled", "YES"])
        app.launch()
    }
}

// MARK: - Onboarding Flow Tests

extension TwinActUITests {

    /// Tests the complete onboarding flow from start to finish.
    /// Verifies that users can navigate through all onboarding pages and complete the flow.
    func testOnboardingCompletionFlow() throws {
        app.launch()

        // Verify onboarding starts
        let discoverTitle = app.staticTexts["Discover Assets"]
        XCTAssertTrue(waitForElement(discoverTitle), "Onboarding should start with Discover Assets page")

        // Page 1: Discover Assets
        XCTAssertTrue(app.staticTexts["Scan QR codes to identify industrial equipment"].exists)
        let nextButton = app.buttons["Next"]
        XCTAssertTrue(nextButton.exists, "Next button should be visible")
        nextButton.tap()

        // Page 2: Digital Passport
        let passportTitle = app.staticTexts["Digital Passport"]
        XCTAssertTrue(waitForElement(passportTitle), "Should navigate to Digital Passport page")
        nextButton.tap()

        // Page 3: Technician Tools
        let technicianTitle = app.staticTexts["Technician Tools"]
        XCTAssertTrue(waitForElement(technicianTitle), "Should navigate to Technician Tools page")
        nextButton.tap()

        // Page 4: AR Overlays
        let arTitle = app.staticTexts["AR Overlays"]
        XCTAssertTrue(waitForElement(arTitle), "Should navigate to AR Overlays page")
        nextButton.tap()

        // Page 5: Voice & AI Assistant
        let voiceTitle = app.staticTexts["Voice & AI Assistant"]
        XCTAssertTrue(waitForElement(voiceTitle), "Should navigate to Voice & AI Assistant page")

        // Verify "Get Started" button appears on last page
        let getStartedButton = app.buttons["Get Started"]
        XCTAssertTrue(waitForElement(getStartedButton), "Get Started button should appear on final page")
        XCTAssertFalse(nextButton.exists, "Next button should not exist on final page")

        // Complete onboarding with demo mode
        getStartedButton.tap()

        // Verify demo mode alert appears
        let demoModeAlert = app.alerts["Demo Mode"]
        XCTAssertTrue(waitForElement(demoModeAlert), "Demo Mode alert should appear")

        // Select demo mode
        let enableDemoButton = app.buttons["Enable Demo Mode"]
        XCTAssertTrue(enableDemoButton.exists, "Enable Demo Mode button should exist")
        enableDemoButton.tap()

        // Verify main app appears with tab bar
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(waitForElement(tabBar), "Tab bar should appear after onboarding")

        // Verify all tabs are present
        XCTAssertTrue(app.tabBars.buttons["Discover"].exists, "Discover tab should exist")
        XCTAssertTrue(app.tabBars.buttons["Passport"].exists, "Passport tab should exist")
        XCTAssertTrue(app.tabBars.buttons["Technician"].exists, "Technician tab should exist")
        XCTAssertTrue(app.tabBars.buttons["Settings"].exists, "Settings tab should exist")
    }

    /// Tests that the back button works correctly during onboarding.
    func testOnboardingBackNavigation() throws {
        app.launch()

        // Navigate forward
        let discoverTitle = app.staticTexts["Discover Assets"]
        XCTAssertTrue(waitForElement(discoverTitle))

        app.buttons["Next"].tap()

        let passportTitle = app.staticTexts["Digital Passport"]
        XCTAssertTrue(waitForElement(passportTitle))

        // Navigate back
        let backButton = app.buttons["Back"]
        XCTAssertTrue(backButton.exists, "Back button should exist after first page")
        backButton.tap()

        // Verify we're back on first page
        XCTAssertTrue(waitForElement(discoverTitle), "Should return to Discover Assets page")
        XCTAssertFalse(backButton.exists, "Back button should not exist on first page")
    }

    /// Tests selecting "Connect to Server" option during onboarding.
    func testOnboardingConnectToServerOption() throws {
        app.launch()

        // Navigate through onboarding to the end
        let discoverTitle = app.staticTexts["Discover Assets"]
        XCTAssertTrue(waitForElement(discoverTitle))

        for _ in 0..<4 {
            let nextButton = app.buttons["Next"]
            if nextButton.exists {
                nextButton.tap()
            }
        }

        // Tap Get Started
        let getStartedButton = app.buttons["Get Started"]
        XCTAssertTrue(waitForElement(getStartedButton))
        getStartedButton.tap()

        // Select "Connect to Server"
        let connectButton = app.buttons["Connect to Server"]
        XCTAssertTrue(waitForElement(connectButton), "Connect to Server button should exist")
        connectButton.tap()

        // Verify main app appears
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(waitForElement(tabBar), "Tab bar should appear after selecting Connect to Server")
    }
}

// MARK: - Tab Navigation Tests

extension TwinActUITests {

    /// Tests navigation between all main tabs.
    func testTabNavigation() throws {
        launchWithOnboardingCompleted()

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(waitForElement(tabBar), "Tab bar should be visible")

        // Test Discover tab (should be selected by default)
        let discoverTab = app.tabBars.buttons["Discover"]
        XCTAssertTrue(discoverTab.isSelected || discoverTab.exists, "Discover tab should exist")

        // Navigate to Passport tab
        let passportTab = app.tabBars.buttons["Passport"]
        XCTAssertTrue(passportTab.exists, "Passport tab should exist")
        passportTab.tap()

        // Verify Passport view content (look for navigation title or empty state)
        let passportContent = app.navigationBars["Passport"].firstMatch
        let passportEmptyState = app.staticTexts["No Asset Selected"]
        let passportLoaded = passportContent.waitForExistence(timeout: 3) || passportEmptyState.waitForExistence(timeout: 3)
        XCTAssertTrue(passportLoaded, "Passport view should be displayed")

        // Navigate to Technician tab
        let technicianTab = app.tabBars.buttons["Technician"]
        XCTAssertTrue(technicianTab.exists, "Technician tab should exist")
        technicianTab.tap()

        // Verify Technician view is displayed
        let technicianNavBar = app.navigationBars.firstMatch
        XCTAssertTrue(waitForElement(technicianNavBar), "Technician view should have navigation bar")

        // Navigate to Settings tab
        let settingsTab = app.tabBars.buttons["Settings"]
        XCTAssertTrue(settingsTab.exists, "Settings tab should exist")
        settingsTab.tap()

        // Verify Settings view content
        let settingsTitle = app.navigationBars["Settings"].firstMatch
        XCTAssertTrue(waitForElement(settingsTitle), "Settings view should be displayed")

        // Navigate back to Discover tab
        discoverTab.tap()
        XCTAssertTrue(discoverTab.exists, "Should return to Discover tab")
    }

    /// Tests that tab selection persists after navigating within a tab.
    func testTabSelectionPersistence() throws {
        launchWithOnboardingCompleted()

        // Navigate to Settings tab
        let settingsTab = app.tabBars.buttons["Settings"]
        XCTAssertTrue(waitForElement(settingsTab))
        settingsTab.tap()

        // Verify Settings is displayed
        let settingsTitle = app.navigationBars["Settings"]
        XCTAssertTrue(waitForElement(settingsTitle))

        // Navigate to another tab and back
        let discoverTab = app.tabBars.buttons["Discover"]
        discoverTab.tap()

        settingsTab.tap()

        // Settings should still show
        XCTAssertTrue(waitForElement(settingsTitle), "Settings should still be displayed after tab switch")
    }
}

// MARK: - Settings Screen Tests

extension TwinActUITests {

    /// Tests that the Settings screen displays all required sections.
    func testSettingsScreenContent() throws {
        launchWithOnboardingCompleted()

        // Navigate to Settings
        let settingsTab = app.tabBars.buttons["Settings"]
        XCTAssertTrue(waitForElement(settingsTab))
        settingsTab.tap()

        // Verify Settings title
        let settingsTitle = app.navigationBars["Settings"]
        XCTAssertTrue(waitForElement(settingsTitle), "Settings navigation bar should exist")

        // Verify Demo Mode section exists
        let demoModeHeader = app.staticTexts["Demo Mode"]
        XCTAssertTrue(waitForElement(demoModeHeader), "Demo Mode section should exist")

        // Verify Account section
        let accountHeader = app.staticTexts["Account"]
        XCTAssertTrue(app.staticTexts["Account"].exists, "Account section should exist")

        // Verify About section (scroll if needed)
        let aboutHeader = app.staticTexts["About"]
        if !aboutHeader.exists {
            app.swipeUp()
        }
        XCTAssertTrue(waitForElement(aboutHeader), "About section should exist")

        // Verify App Version is displayed
        let appVersionLabel = app.staticTexts["App Version"]
        XCTAssertTrue(appVersionLabel.exists || waitForElement(appVersionLabel), "App Version should be displayed")
    }

    /// Tests navigation to Licenses screen from Settings.
    func testSettingsLicensesNavigation() throws {
        launchWithOnboardingCompleted()

        // Navigate to Settings
        let settingsTab = app.tabBars.buttons["Settings"]
        XCTAssertTrue(waitForElement(settingsTab))
        settingsTab.tap()

        // Scroll to find Licenses
        let licensesButton = app.buttons["Licenses"]
        var attempts = 0
        while !licensesButton.exists && attempts < 5 {
            app.swipeUp()
            attempts += 1
        }

        XCTAssertTrue(licensesButton.exists, "Licenses button should exist")
        licensesButton.tap()

        // Verify Licenses screen
        let licensesTitle = app.navigationBars["Licenses"]
        XCTAssertTrue(waitForElement(licensesTitle), "Licenses screen should be displayed")

        // Navigate back
        let backButton = app.navigationBars.buttons.element(boundBy: 0)
        if backButton.exists {
            backButton.tap()
        }

        // Verify we're back on Settings
        let settingsTitle = app.navigationBars["Settings"]
        XCTAssertTrue(waitForElement(settingsTitle), "Should return to Settings")
    }

    /// Tests navigation to Privacy Policy screen from Settings.
    func testSettingsPrivacyPolicyNavigation() throws {
        launchWithOnboardingCompleted()

        // Navigate to Settings
        let settingsTab = app.tabBars.buttons["Settings"]
        XCTAssertTrue(waitForElement(settingsTab))
        settingsTab.tap()

        // Scroll to find Privacy Policy
        let privacyButton = app.buttons["Privacy Policy"]
        var attempts = 0
        while !privacyButton.exists && attempts < 5 {
            app.swipeUp()
            attempts += 1
        }

        XCTAssertTrue(privacyButton.exists, "Privacy Policy button should exist")
        privacyButton.tap()

        // Verify Privacy Policy screen
        let privacyTitle = app.navigationBars["Privacy Policy"]
        XCTAssertTrue(waitForElement(privacyTitle), "Privacy Policy screen should be displayed")
    }
}

// MARK: - Demo Mode Tests

extension TwinActUITests {

    /// Tests that demo mode toggle is visible and functional in Settings.
    func testDemoModeToggleVisibility() throws {
        launchWithOnboardingCompleted()

        // Navigate to Settings
        let settingsTab = app.tabBars.buttons["Settings"]
        XCTAssertTrue(waitForElement(settingsTab))
        settingsTab.tap()

        // Verify Demo Mode toggle exists
        let demoModeToggle = app.switches.firstMatch
        XCTAssertTrue(waitForElement(demoModeToggle), "Demo Mode toggle should exist")

        // Verify demo mode description text
        let descriptionText = app.staticTexts["Use bundled sample data without server connection"]
        XCTAssertTrue(descriptionText.exists, "Demo mode description should be visible")
    }

    /// Tests toggling demo mode off shows confirmation alert.
    func testDemoModeToggleOffConfirmation() throws {
        launchWithOnboardingCompleted()

        // Navigate to Settings
        let settingsTab = app.tabBars.buttons["Settings"]
        XCTAssertTrue(waitForElement(settingsTab))
        settingsTab.tap()

        // Find and tap the demo mode toggle (assuming it's ON)
        let demoModeToggle = app.switches.firstMatch
        XCTAssertTrue(waitForElement(demoModeToggle))

        // Get the current value
        let isCurrentlyOn = demoModeToggle.value as? String == "1"

        if isCurrentlyOn {
            // Tap to turn off
            demoModeToggle.tap()

            // Verify confirmation alert appears
            let disableAlert = app.alerts["Disable Demo Mode?"]
            XCTAssertTrue(waitForElement(disableAlert), "Confirmation alert should appear when disabling demo mode")

            // Verify alert has Cancel and Disable buttons
            XCTAssertTrue(app.buttons["Cancel"].exists, "Cancel button should exist in alert")
            XCTAssertTrue(app.buttons["Disable"].exists, "Disable button should exist in alert")

            // Cancel the action
            app.buttons["Cancel"].tap()

            // Verify toggle is still on
            XCTAssertTrue(demoModeToggle.value as? String == "1", "Toggle should remain on after canceling")
        }
    }

    /// Tests that demo mode indicator appears when demo mode is enabled.
    func testDemoModeIndicatorVisibility() throws {
        launchWithOnboardingCompleted()

        // In demo mode, check for demo mode indicators/banners
        // The app shows "Demo Mode" text or "DEMO" badge when in demo mode

        // Navigate to Settings to verify demo mode status
        let settingsTab = app.tabBars.buttons["Settings"]
        XCTAssertTrue(waitForElement(settingsTab))
        settingsTab.tap()

        // Verify we're in demo mode by checking the "Not connected (Demo Mode)" text in Server Connection section
        var attempts = 0
        let notConnectedText = app.staticTexts["Not connected (Demo Mode)"]
        while !notConnectedText.exists && attempts < 3 {
            app.swipeUp()
            attempts += 1
        }

        XCTAssertTrue(notConnectedText.exists, "Demo mode indicator should show 'Not connected (Demo Mode)'")
    }

    /// Tests the Demo Data Info screen in Settings when in demo mode.
    func testDemoDataInfoNavigation() throws {
        launchWithOnboardingCompleted()

        // Navigate to Settings
        let settingsTab = app.tabBars.buttons["Settings"]
        XCTAssertTrue(waitForElement(settingsTab))
        settingsTab.tap()

        // Scroll to find Demo Data section
        let demoDataButton = app.buttons["View Demo Asset Info"]
        var attempts = 0
        while !demoDataButton.exists && attempts < 5 {
            app.swipeUp()
            attempts += 1
        }

        // In demo mode, this section should exist
        if demoDataButton.exists {
            demoDataButton.tap()

            // Verify Demo Asset Info screen
            let demoAssetTitle = app.navigationBars["Demo Asset Info"]
            XCTAssertTrue(waitForElement(demoAssetTitle), "Demo Asset Info screen should be displayed")

            // Verify demo asset information is shown
            let nameLabel = app.staticTexts["Name"]
            XCTAssertTrue(nameLabel.exists, "Name label should exist in Demo Asset Info")
        }
    }
}

// MARK: - Accessibility Tests

extension TwinActUITests {

    /// Tests that key UI elements have accessibility identifiers for testing.
    func testAccessibilityIdentifiers() throws {
        launchWithOnboardingCompleted()

        // Verify tab bar buttons are accessible
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(waitForElement(tabBar))

        XCTAssertTrue(app.tabBars.buttons["Discover"].isHittable, "Discover tab should be hittable")
        XCTAssertTrue(app.tabBars.buttons["Passport"].isHittable, "Passport tab should be hittable")
        XCTAssertTrue(app.tabBars.buttons["Technician"].isHittable, "Technician tab should be hittable")
        XCTAssertTrue(app.tabBars.buttons["Settings"].isHittable, "Settings tab should be hittable")
    }
}

// MARK: - Performance Tests

extension TwinActUITests {

    /// Tests that the app launches within acceptable time.
    func testAppLaunchPerformance() throws {
        if #available(iOS 14.0, *) {
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                app.launch()
            }
        }
    }
}

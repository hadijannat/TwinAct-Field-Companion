//
//  TwinActUITestsLaunchTests.swift
//  TwinAct Field CompanionUITests
//
//  Launch tests for measuring app launch performance and verifying launch state.
//

import XCTest

/// Launch tests for TwinAct Field Companion.
/// These tests verify proper app launch behavior and measure launch performance.
final class TwinActUITestsLaunchTests: XCTestCase {

    // MARK: - Properties

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - Launch Tests

    /// Tests that the app launches successfully.
    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launch()

        // Take a screenshot of the launch screen
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Tests app launch with fresh state (first launch scenario).
    @MainActor
    func testFreshLaunch() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launchArguments.append(contentsOf: ["-hasCompletedOnboarding", "NO"])
        app.launch()

        // Verify onboarding appears for fresh launch
        let onboardingTitle = app.staticTexts["Discover Assets"]
        XCTAssertTrue(onboardingTitle.waitForExistence(timeout: 5), "Onboarding should appear on fresh launch")

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Fresh Launch - Onboarding"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Tests app launch with onboarding already completed.
    @MainActor
    func testReturningUserLaunch() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launchArguments.append(contentsOf: ["-hasCompletedOnboarding", "YES"])
        app.launchArguments.append(contentsOf: ["-com.twinact.fieldcompanion.demoModeEnabled", "YES"])
        app.launch()

        // Verify main app appears (tab bar)
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5), "Tab bar should appear for returning user")

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Returning User Launch - Main App"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Tests app launch in demo mode.
    @MainActor
    func testDemoModeLaunch() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launchArguments.append(contentsOf: ["-hasCompletedOnboarding", "YES"])
        app.launchArguments.append(contentsOf: ["-com.twinact.fieldcompanion.demoModeEnabled", "YES"])
        app.launch()

        // Verify app launches in demo mode
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5), "App should launch successfully in demo mode")

        // Navigate to settings to verify demo mode
        app.tabBars.buttons["Settings"].tap()

        let settingsTitle = app.navigationBars["Settings"]
        XCTAssertTrue(settingsTitle.waitForExistence(timeout: 3), "Settings should be accessible")

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Demo Mode Launch - Settings"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Tests app launch with server connection mode (non-demo).
    @MainActor
    func testServerModeLaunch() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launchArguments.append(contentsOf: ["-hasCompletedOnboarding", "YES"])
        app.launchArguments.append(contentsOf: ["-com.twinact.fieldcompanion.demoModeEnabled", "NO"])
        app.launch()

        // Verify app launches
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5), "App should launch in server mode")

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Server Mode Launch"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

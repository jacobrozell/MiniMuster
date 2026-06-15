import XCTest

/// Smoke tests for the native v2 shell — launch, sample data, tab navigation.
final class MusterRollUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launchApp(persistent: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = persistent ? ["UI-Testing-Persistent"] : ["UI-Testing"]
        app.launch()
        return app
    }

    private func terminateApp(_ app: XCUIApplication) {
        app.terminate()
    }

    /// Fresh in-memory installs show onboarding once; dismiss before other smoke steps.
    private func dismissOnboardingIfNeeded(_ app: XCUIApplication) {
        let skip = app.buttons["onboardingSkip"]
        let cont = app.buttons["onboardingContinue"]
        if skip.waitForExistence(timeout: 2) {
            skip.tap()
            return
        }
        if cont.waitForExistence(timeout: 1) {
            cont.tap()
        }
    }

    private func tapTab(_ app: XCUIApplication, id: String) {
        let tab = app.buttons[id]
        if tab.waitForExistence(timeout: 3) {
            tab.tap()
            return
        }
        // Floating tab bar fallback (label-based)
        let label = id == "tabPaints" ? "Paints" : "Collection"
        XCTAssertTrue(app.buttons[label].waitForExistence(timeout: 3))
        app.buttons[label].tap()
    }

    func testLaunchShowsOnboardingThenCollection() throws {
        let app = launchApp()
        XCTAssertTrue(app.buttons["onboardingSkip"].waitForExistence(timeout: 5)
                      || app.buttons["onboardingContinue"].waitForExistence(timeout: 5))
        dismissOnboardingIfNeeded(app)
        XCTAssertTrue(app.navigationBars["Collection"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["loadSampleData"].waitForExistence(timeout: 5))
    }

    func testLoadSampleDataAndSwitchTabs() throws {
        let app = launchApp()
        dismissOnboardingIfNeeded(app)

        XCTAssertTrue(app.buttons["loadSampleData"].waitForExistence(timeout: 5))
        app.buttons["loadSampleData"].tap()
        XCTAssertTrue(app.staticTexts["Hallowed Knights"].waitForExistence(timeout: 8))

        tapTab(app, id: "tabPaints")
        XCTAssertTrue(app.navigationBars["Paints"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Absolution Green"].waitForExistence(timeout: 5))

        tapTab(app, id: "tabCollection")
        XCTAssertTrue(app.navigationBars["Collection"].waitForExistence(timeout: 5))
    }

    func testSettingsSheetOpens() throws {
        let app = launchApp()
        dismissOnboardingIfNeeded(app)
        XCTAssertTrue(app.buttons["settings"].waitForExistence(timeout: 5))
        app.buttons["settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Done"].exists)
    }

    func testOnboardingNotShownAfterRelaunch() throws {
        resetUITestPersistentStore()
        let app = launchApp(persistent: true)
        XCTAssertTrue(app.buttons["onboardingSkip"].waitForExistence(timeout: 5))
        dismissOnboardingIfNeeded(app)
        XCTAssertTrue(app.navigationBars["Collection"].waitForExistence(timeout: 5))

        terminateApp(app)
        let relaunched = launchApp(persistent: true)
        XCTAssertFalse(relaunched.buttons["onboardingSkip"].waitForExistence(timeout: 2))
        XCTAssertFalse(relaunched.buttons["onboardingContinue"].waitForExistence(timeout: 1))
        XCTAssertTrue(relaunched.navigationBars["Collection"].waitForExistence(timeout: 5))
    }

    func testOnboardingLoadSampleOpensCollection() throws {
        let app = launchApp()
        advanceOnboardingToLastPage(app)
        XCTAssertTrue(app.buttons["onboardingLoadSample"].waitForExistence(timeout: 3))
        app.buttons["onboardingLoadSample"].tap()
        XCTAssertTrue(app.staticTexts["Hallowed Knights"].waitForExistence(timeout: 8))
    }

    func testOnboardingOpenSettings() throws {
        let app = launchApp()
        advanceOnboardingToLastPage(app)
        XCTAssertTrue(app.buttons["onboardingOpenSettings"].waitForExistence(timeout: 3))
        app.buttons["onboardingOpenSettings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
    }

    private func advanceOnboardingToLastPage(_ app: XCUIApplication) {
        XCTAssertTrue(app.buttons["onboardingSkip"].waitForExistence(timeout: 5)
                      || app.buttons["onboardingContinue"].waitForExistence(timeout: 5))
        for _ in 0..<3 where app.buttons["onboardingContinue"].waitForExistence(timeout: 2) {
            app.buttons["onboardingContinue"].tap()
        }
    }

    private func resetUITestPersistentStore() {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "MusterRollUITest-Persistent", directoryHint: .isDirectory)
        try? FileManager.default.removeItem(at: directory)
    }
}

import XCTest

/// Smoke tests for the native v2 shell — launch, sample data, tab navigation.
final class MiniMusterUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIApplication().terminate()
    }

    override func tearDownWithError() throws {
        XCUIApplication().terminate()
    }

    private func launchApp(persistent: Bool = false, resetPersistent: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        var args = persistent ? ["UI-Testing-Persistent"] : ["UI-Testing"]
        if resetPersistent { args.append("UI-Testing-ResetPersistent") }
        app.launchArguments = args
        app.launch()
        return app
    }

    private func terminateApp(_ app: XCUIApplication) {
        app.terminate()
    }

    /// Fresh in-memory installs show onboarding once; dismiss before other smoke steps.
    private func dismissOnboardingIfNeeded(_ app: XCUIApplication) {
        let skip = app.buttons.matching(identifier: "onboardingSkip").firstMatch
        if skip.waitForExistence(timeout: 5) {
            skip.tap()
            _ = waitForCollectionHome(app, timeout: 8)
            return
        }
        let cont = app.buttons.matching(identifier: "onboardingContinue").firstMatch
        if cont.waitForExistence(timeout: 2) {
            cont.tap()
            _ = waitForCollectionHome(app, timeout: 8)
        }
    }

    @discardableResult
    private func waitForCollectionHome(_ app: XCUIApplication, timeout: TimeInterval = 8) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if app.navigationBars["Collection"].exists { return true }
            if app.buttons["loadSampleData"].exists { return true }
            if app.buttons.matching(identifier: "tabCollection").firstMatch.exists { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }
        return app.navigationBars["Collection"].exists
            || app.buttons["loadSampleData"].exists
            || app.buttons.matching(identifier: "tabCollection").firstMatch.exists
    }

    private func tapTab(_ app: XCUIApplication, id: String) {
        let tabs = app.buttons.matching(identifier: id)
        if tabs.firstMatch.waitForExistence(timeout: 5) {
            let tab = tabs.firstMatch
            for _ in 0..<4 where !tab.isHittable {
                app.swipeUp()
            }
            tab.tap()
            return
        }
        let label = id == "tabPaints" ? "Paints" : "Collection"
        let labeled = app.buttons.matching(NSPredicate(format: "label == %@", label))
        XCTAssertTrue(labeled.firstMatch.waitForExistence(timeout: 5))
        labeled.firstMatch.tap()
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
        waitForCollectionHome(app)

        let loadSample = app.buttons["loadSampleData"]
        XCTAssertTrue(loadSample.waitForExistence(timeout: 5))
        loadSample.tap()
        XCTAssertTrue(app.staticTexts["Hallowed Knights"].waitForExistence(timeout: 12))

        tapTab(app, id: "tabPaints")
        XCTAssertTrue(app.navigationBars["Paints"].waitForExistence(timeout: 8))
        XCTAssertTrue(
            app.staticTexts["Absolution Green"].waitForExistence(timeout: 8)
            || app.descendants(matching: .any)
                .matching(NSPredicate(format: "label CONTAINS[c] %@", "Absolution Green"))
                .firstMatch.waitForExistence(timeout: 4)
        )

        tapTab(app, id: "tabCollection")
        waitForCollectionHome(app)
        XCTAssertTrue(app.staticTexts["Hallowed Knights"].waitForExistence(timeout: 5))
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
        let app = launchApp(persistent: true, resetPersistent: true)
        XCTAssertTrue(app.buttons.matching(identifier: "onboardingSkip").firstMatch.waitForExistence(timeout: 10))
        dismissOnboardingIfNeeded(app)
        XCTAssertTrue(waitForCollectionHome(app, timeout: 15))

        terminateApp(app)
        Thread.sleep(forTimeInterval: 0.5)
        let relaunched = launchApp(persistent: true)
        XCTAssertFalse(relaunched.buttons.matching(identifier: "onboardingSkip").firstMatch
            .waitForExistence(timeout: 2))
        XCTAssertTrue(waitForCollectionHome(relaunched, timeout: 15))
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
        XCTAssertTrue(
            app.buttons.matching(identifier: "onboardingSkip").firstMatch.waitForExistence(timeout: 5)
            || app.buttons.matching(identifier: "onboardingContinue").firstMatch.waitForExistence(timeout: 5)
        )
        for _ in 0..<3 {
            let cont = app.buttons.matching(identifier: "onboardingContinue").firstMatch
            guard cont.waitForExistence(timeout: 2) else { break }
            cont.tap()
        }
    }

    private func resetUITestPersistentStore() {
        launchApp(persistent: true, resetPersistent: true).terminate()
    }
}

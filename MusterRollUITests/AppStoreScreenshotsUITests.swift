import XCTest
#if canImport(UIKit)
import UIKit
#endif

/// Captures App Store marketing screenshots. Run via scripts/capture-app-store-screenshots.sh
final class AppStoreScreenshotsUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private var screenshotsDirectory: URL {
        let root: URL
        if let env = ProcessInfo.processInfo.environment["SCREENSHOTS_DIR"], !env.isEmpty {
            root = URL(fileURLWithPath: env, isDirectory: true)
        } else {
            root = URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appending(path: ".app-store-screenshots/_staging")
        }
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private func saveScreenshot(_ app: XCUIApplication, name: String) throws {
        let data = app.screenshot().pngRepresentation
        try data.write(to: screenshotsDirectory.appending(path: "\(name).png"))
    }

    private func dismissOnboarding(_ app: XCUIApplication) {
        if app.buttons["onboardingSkip"].waitForExistence(timeout: 2) {
            app.buttons["onboardingSkip"].tap()
        }
    }

    private func tapTab(_ app: XCUIApplication, id: String) {
        let tabs = app.buttons.matching(identifier: id)
        if tabs.firstMatch.waitForExistence(timeout: 3) {
            tabs.firstMatch.tap()
            return
        }
        let label = id == "tabPaints" ? "Paints" : "Collection"
        let labeled = app.buttons.matching(NSPredicate(format: "label == %@", label))
        XCTAssertTrue(labeled.firstMatch.waitForExistence(timeout: 3))
        labeled.firstMatch.tap()
    }

    private func waitForLabel(_ text: String, in app: XCUIApplication, timeout: TimeInterval = 8) -> Bool {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS[c] %@", text))
            .firstMatch
            .waitForExistence(timeout: timeout)
    }

    private func openArmy(named name: String, in app: XCUIApplication) {
        let id = "army-\(name)"
        for query in [app.buttons, app.otherElements] {
            let row = query[id]
            if row.waitForExistence(timeout: 5) {
                row.tap()
                return
            }
        }
        let fallback = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS[c] %@", name))
            .firstMatch
        XCTAssertTrue(fallback.waitForExistence(timeout: 5))
        fallback.tap()
    }

    private func openUnit(named name: String, in app: XCUIApplication) {
        let id = "unit-\(name)"
        for query in [app.buttons, app.otherElements] {
            let row = query[id]
            if row.waitForExistence(timeout: 5) {
                row.tap()
                return
            }
        }
        let fallback = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS[c] %@", name))
            .firstMatch
        XCTAssertTrue(fallback.waitForExistence(timeout: 5))
        fallback.tap()
    }

    private func popToCollectionRoot(_ app: XCUIApplication) {
        for _ in 0..<4 {
            if app.buttons["settings"].waitForExistence(timeout: 1) { return }
            let back = app.navigationBars.buttons.firstMatch
            guard back.exists else { return }
            back.tap()
        }
    }

    private func tapLoadSampleData(_ app: XCUIApplication) {
        let button = app.buttons["loadSampleData"]
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        for _ in 0..<4 where !button.isHittable {
            app.swipeUp()
        }
        if button.isHittable {
            button.tap()
        } else {
            button.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
    }

    /// Single-session flow: empty → sample data → army → unit → paints → settings.
    func testCaptureAppStoreScreenshots() throws {
        let app = XCUIApplication()
        app.launchArguments = ["UI-Testing"]
        app.launch()
        dismissOnboarding(app)

        XCTAssertTrue(app.navigationBars["Collection"].waitForExistence(timeout: 5))
        try saveScreenshot(app, name: "01-empty-collection")

        tapLoadSampleData(app)
        XCTAssertTrue(waitForLabel("Hallowed Knights", in: app, timeout: 15))
        try saveScreenshot(app, name: "02-collection-armies")

        openArmy(named: "Hallowed Knights", in: app)
        XCTAssertTrue(waitForLabel("Lord-Vigilant", in: app, timeout: 15))
        try saveScreenshot(app, name: "03-army-units")

        openUnit(named: "Lord-Vigilant on Gryph-stalker", in: app)
        XCTAssertTrue(waitForLabel("Lord-Vigilant", in: app))
        try saveScreenshot(app, name: "04-unit-detail")

        tapTab(app, id: "tabPaints")
        XCTAssertTrue(app.navigationBars["Paints"].waitForExistence(timeout: 5))
        XCTAssertTrue(waitForLabel("Absolution Green", in: app))
        try saveScreenshot(app, name: "05-paints")

        tapTab(app, id: "tabCollection")
#if canImport(UIKit)
        if UIDevice.current.userInterfaceIdiom != .pad {
            popToCollectionRoot(app)
        }
#else
        popToCollectionRoot(app)
#endif
        let settings = app.buttons.matching(identifier: "settings")
        XCTAssertTrue(settings.firstMatch.waitForExistence(timeout: 10))
        settings.firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        app.swipeUp()
        try saveScreenshot(app, name: "06-settings-data")
    }
}

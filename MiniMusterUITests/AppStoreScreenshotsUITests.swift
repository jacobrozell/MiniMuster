import XCTest
#if canImport(UIKit)
import UIKit
#endif

/// Captures App Store marketing screenshots. Run via scripts/capture-app-store-screenshots.sh
final class AppStoreScreenshotsUITests: XCTestCase {

    private enum CaptureVariant: String {
        case light
        case dark
        case accessibility
    }

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
        let label: String
        switch id {
        case "tabPaints": label = "Paints"
        case "tabCollection": label = "Collection"
        default: label = id
        }
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

    private func tapRow(_ row: XCUIElement, in app: XCUIApplication) {
        scrollToReveal(row, in: app)
        if row.isHittable {
            row.tap()
            return
        }
        row.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }

    private func waitForArmyDetail(named name: String, in app: XCUIApplication, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if app.staticTexts["Select an Army"].exists { /* still on placeholder */ }
            else if app.navigationBars[name].exists { return true }
            else if app.descendants(matching: .any)
                .matching(NSPredicate(format: "identifier BEGINSWITH 'unit-'"))
                .firstMatch.exists { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }
        return false
    }

    private func armyRow(named name: String, in app: XCUIApplication) -> XCUIElement? {
        let id = "army-\(name)"
        let queries: [XCUIElementQuery] = [
            app.buttons,
            app.cells,
            app.tables.cells,
            app.collectionViews.cells,
            app.otherElements,
        ]
        for query in queries {
            let row = query[id]
            if row.waitForExistence(timeout: 1) { return row }
        }
        let labeled = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == %@ OR label CONTAINS[c] %@", id, name))
            .firstMatch
        return labeled.waitForExistence(timeout: 2) ? labeled : nil
    }

    private func openArmy(named name: String, in app: XCUIApplication) {
        XCTAssertNotNil(armyRow(named: name, in: app), "Army row not found: \(name)")

        for _ in 0..<3 {
            guard let row = armyRow(named: name, in: app) else { break }
            tapRow(row, in: app)
            if waitForArmyDetail(named: name, in: app, timeout: 4) { return }
        }
        XCTAssertTrue(
            waitForArmyDetail(named: name, in: app, timeout: 12),
            "Army detail did not open"
        )
    }

    private func scrollToReveal(_ element: XCUIElement, in app: XCUIApplication, maxSwipes: Int = 6) {
        for _ in 0..<maxSwipes where !element.waitForExistence(timeout: 1) || !element.isHittable {
            app.swipeUp()
        }
    }

    private func openUnit(named name: String, in app: XCUIApplication) {
        let id = "unit-\(name)"
        for query in [app.buttons, app.cells, app.otherElements] {
            let row = query[id]
            if row.waitForExistence(timeout: 5) {
                tapRow(row, in: app)
                return
            }
        }
        let fallback = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS[c] %@", name))
            .firstMatch
        XCTAssertTrue(fallback.waitForExistence(timeout: 5))
        tapRow(fallback, in: app)
    }

    private func tapSettings(_ app: XCUIApplication) {
#if canImport(UIKit)
        if UIDevice.current.userInterfaceIdiom == .pad {
            let more = app.buttons["More"]
            if more.waitForExistence(timeout: 3) {
                more.tap()
                let settings = app.buttons["Settings"]
                if settings.waitForExistence(timeout: 3) {
                    settings.tap()
                    return
                }
            }
        }
#endif
        for query in [
            app.buttons.matching(identifier: "settings"),
            app.buttons.matching(NSPredicate(format: "label == 'Settings'")),
            app.toolbars.buttons.matching(identifier: "settings"),
            app.toolbars.buttons.matching(NSPredicate(format: "label == 'Settings'"))
        ] {
            if query.firstMatch.waitForExistence(timeout: 2) {
                query.firstMatch.tap()
                return
            }
        }
        XCTFail("Settings button not found")
    }

    private func dismissSettings(_ app: XCUIApplication) {
        let done = app.buttons.matching(NSPredicate(format: "label == 'Done' OR label == 'Close'"))
        if done.firstMatch.waitForExistence(timeout: 2) {
            done.firstMatch.tap()
            return
        }
        app.swipeDown()
    }

    private func tapLoadSampleData(_ app: XCUIApplication) {
        let button = app.buttons["loadSampleData"]
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        scrollToReveal(button, in: app, maxSwipes: 8)
        if button.isHittable {
            button.tap()
        } else {
            button.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
        XCTAssertTrue(
            waitForLabel("Hallowed Knights", in: app, timeout: 30),
            "Sample data did not load"
        )
    }

    private func configureAppForCapture(_ app: XCUIApplication, variant: CaptureVariant) {
        var args = ["UI-Testing"]
        switch variant {
        case .light:
            args.append("UI-Testing-LightTheme")
            XCUIDevice.shared.appearance = .light
        case .dark:
            args.append("UI-Testing-DarkTheme")
            XCUIDevice.shared.appearance = .dark
        case .accessibility:
            XCUIDevice.shared.appearance = .light
            app.launchEnvironment["UIPreferredContentSizeCategoryName"] =
                "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge"
        }
        app.launchArguments = args
    }

    private func runCaptureFlow(variant: CaptureVariant) throws {
        let app = XCUIApplication()
        configureAppForCapture(app, variant: variant)
        app.launch()
        dismissOnboarding(app)

        XCTAssertTrue(app.navigationBars["Collection"].waitForExistence(timeout: 5))
        try saveScreenshot(app, name: "01-empty-collection")

        tapLoadSampleData(app)
        try saveScreenshot(app, name: "02-collection-armies")

#if canImport(UIKit)
        if UIDevice.current.userInterfaceIdiom != .pad {
            openArmy(named: "Hallowed Knights", in: app)
        } else {
            XCTAssertTrue(
                waitForArmyDetail(named: "Hallowed Knights", in: app, timeout: 15),
                "Army detail did not open"
            )
        }
#else
        openArmy(named: "Hallowed Knights", in: app)
#endif
        try saveScreenshot(app, name: "03-army-units")

        openUnit(named: "Lord-Vigilant on Gryph-stalker", in: app)
        XCTAssertTrue(waitForLabel("Lord-Vigilant", in: app))
        try saveScreenshot(app, name: "04-unit-detail")

        tapTab(app, id: "tabPaints")
        XCTAssertTrue(app.navigationBars["Paints"].waitForExistence(timeout: 5))
        XCTAssertTrue(waitForLabel("Absolution Green", in: app))
        try saveScreenshot(app, name: "05-paints")

        // Capture settings from Collection so the iPad sidebar stays visible in the shot.
        tapTab(app, id: "tabCollection")
        XCTAssertTrue(
            app.navigationBars["Collection"].waitForExistence(timeout: 10)
                || app.buttons["army-Hallowed Knights"].waitForExistence(timeout: 3),
            "Collection tab did not open"
        )
        tapSettings(app)
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        app.swipeUp()
        try saveScreenshot(app, name: "06-settings-data")
    }

    func testCaptureAppStoreScreenshotsLight() throws {
        try runCaptureFlow(variant: .light)
    }

    func testCaptureAppStoreScreenshotsDark() throws {
        try runCaptureFlow(variant: .dark)
    }

    func testCaptureAppStoreScreenshotsAccessibility() throws {
        try runCaptureFlow(variant: .accessibility)
    }
}

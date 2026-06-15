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

    private func openArmy(named name: String, in app: XCUIApplication) {
        let id = "army-\(name)"
        for query in [app.buttons, app.otherElements] {
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

    private func scrollToReveal(_ element: XCUIElement, in app: XCUIApplication, maxSwipes: Int = 6) {
        for _ in 0..<maxSwipes where !element.waitForExistence(timeout: 1) || !element.isHittable {
            app.swipeUp()
        }
    }

    private func openUnit(named name: String, in app: XCUIApplication) {
        let id = "unit-\(name)"
        for query in [app.buttons, app.otherElements] {
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
            waitForLabel("Hallowed Knights", in: app, timeout: 20),
            "Sample data did not load"
        )
    }

    private func configureAppForCapture(_ app: XCUIApplication, variant: CaptureVariant) {
        app.launchArguments = ["UI-Testing"]

        switch variant {
        case .light:
            XCUIDevice.shared.appearance = .light
        case .dark:
            XCUIDevice.shared.appearance = .dark
        case .accessibility:
            XCUIDevice.shared.appearance = .light
            app.launchEnvironment["UIPreferredContentSizeCategoryName"] =
                "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge"
        }
    }

    private func applyTheme(named theme: String, in app: XCUIApplication) {
        tapSettings(app)
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        let themeButton = app.buttons[theme]
        XCTAssertTrue(themeButton.waitForExistence(timeout: 3), "Theme control not found: \(theme)")
        themeButton.tap()
        dismissSettings(app)
    }

    private func runCaptureFlow(variant: CaptureVariant) throws {
        let app = XCUIApplication()
        configureAppForCapture(app, variant: variant)
        app.launch()
        dismissOnboarding(app)

        switch variant {
        case .light:
            applyTheme(named: "Light", in: app)
        case .dark:
            applyTheme(named: "Dark", in: app)
        case .accessibility:
            break
        }

        XCTAssertTrue(app.navigationBars["Collection"].waitForExistence(timeout: 5))
        try saveScreenshot(app, name: "01-empty-collection")

        tapLoadSampleData(app)
        try saveScreenshot(app, name: "02-collection-armies")

        // Capture settings while the collection sidebar is visible (iPad split view hides it after tab switches).
        tapSettings(app)
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        app.swipeUp()
        try saveScreenshot(app, name: "06-settings-data")
        dismissSettings(app)
        tapTab(app, id: "tabCollection")

        openArmy(named: "Hallowed Knights", in: app)
        let lordVigilant = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS[c] %@", "Lord-Vigilant"))
            .firstMatch
        scrollToReveal(lordVigilant, in: app)
        XCTAssertTrue(waitForLabel("Lord-Vigilant", in: app, timeout: 15))
        try saveScreenshot(app, name: "03-army-units")

        openUnit(named: "Lord-Vigilant on Gryph-stalker", in: app)
        XCTAssertTrue(waitForLabel("Lord-Vigilant", in: app))
        try saveScreenshot(app, name: "04-unit-detail")

        tapTab(app, id: "tabPaints")
        XCTAssertTrue(app.navigationBars["Paints"].waitForExistence(timeout: 5))
        XCTAssertTrue(waitForLabel("Absolution Green", in: app))
        try saveScreenshot(app, name: "05-paints")
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

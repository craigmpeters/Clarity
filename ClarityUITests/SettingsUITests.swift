import XCTest

@MainActor
final class SettingsUITests: ClarityUITestCase {
    func testSettingsRowsExist() {
        switchToTab("Settings")

        XCTAssertTrue(app.staticTexts["Settings"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Manage Categories & Targets"].exists)
        XCTAssertTrue(app.staticTexts["Choose a Companion"].exists)
        XCTAssertTrue(app.staticTexts["Notifications"].exists)
        XCTAssertTrue(app.staticTexts["Change App Icon"].exists)
        XCTAssertTrue(app.staticTexts["Change Swipe Options"].exists)
    }

    func testCategoriesNavigation() {
        switchToTab("Settings")
        app.buttons["settings-categories"].tap()
        XCTAssertTrue(app.staticTexts["Categories & Targets"].waitForExistence(timeout: 5))
    }

    func testNotificationsNavigation() {
        switchToTab("Settings")
        app.buttons["settings-notifications"].tap()
        XCTAssertTrue(app.staticTexts["Notifications"].waitForExistence(timeout: 5))
    }

    func testSwipeOptionsNavigation() {
        switchToTab("Settings")
        app.buttons["settings-swipe"].tap()
        XCTAssertTrue(app.staticTexts["Swipe Settings"].waitForExistence(timeout: 5))
    }

    func testAppIconNavigation() {
        switchToTab("Settings")
        app.buttons["settings-appicon"].tap()
        XCTAssertTrue(app.staticTexts["App Icon"].waitForExistence(timeout: 5))
    }
}

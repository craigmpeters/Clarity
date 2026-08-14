import XCTest

@MainActor
final class StatsUITests: ClarityUITestCase {
    func testStatisticsSectionsRender() {
        switchToTab("Stats")

        XCTAssertTrue(app.staticTexts["Statistics"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Completed"].exists)
        XCTAssertTrue(app.staticTexts["Focus Time"].exists)
        XCTAssertTrue(app.staticTexts["Daily Average"].exists)

        XCTAssertTrue(app.staticTexts["Habits"].exists)
        XCTAssertTrue(app.staticTexts["Drink Water"].exists || app.staticTexts["No active habits yet."].exists)
    }

    func testExportMenuOpens() {
        switchToTab("Stats")
        app.buttons["stats-menu"].tap()
        XCTAssertTrue(app.buttons["Export Stats"].waitForExistence(timeout: 5))
    }
}

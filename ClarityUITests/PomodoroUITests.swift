import XCTest

@MainActor
final class PomodoroUITests: ClarityUITestCase {
    func testFocusTabIdleState() {
        switchToTab("Focus")
        XCTAssertTrue(app.staticTexts["No active session"].waitForExistence(timeout: 5))
    }

    func testStartTimerFromTaskRow() {
        XCTAssertTrue(app.staticTexts["Team standup meeting prep"].waitForExistence(timeout: 5))
        let taskCell = app.cells.containing(
            NSPredicate(format: "label == %@", "Team standup meeting prep")
        ).firstMatch
        assertExists(taskCell)
        taskCell.swipeRight()

        let startButton = app.buttons["Start Timer"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 3))
        startButton.tap()

        switchToTab("Focus")
        XCTAssertTrue(app.staticTexts["Team standup meeting prep"].waitForExistence(timeout: 5))

        // Stop the timer so subsequent tests start on the Tasks tab without a persisted timer.
        let stopButton = app.buttons["Stop Timer"]
        if stopButton.waitForExistence(timeout: 3) {
            stopButton.tap()
        }
    }
}

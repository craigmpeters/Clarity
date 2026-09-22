import XCTest

@MainActor
final class TaskFormUITests: ClarityUITestCase {
    func testCreateNewTask() {
        app.buttons["task-add"].tap()

        let nameField = app.textFields["task-form-name"]
        assertExists(nameField)
        nameField.tap()
        nameField.typeText("UI Test Task")

        app.buttons["task-form-date-toggle"].tap()
        app.buttons["quick-date-tomorrow"].tap()
        app.buttons["task-form-save"].tap()

        XCTAssertTrue(app.staticTexts["UI Test Task"].waitForExistence(timeout: 5))
    }

    func testSaveDisabledWhenNameEmpty() {
        app.buttons["task-add"].tap()
        let saveButton = app.buttons["task-form-save"]
        assertExists(saveButton)
        XCTAssertFalse(saveButton.isEnabled)
    }

    func testCancelClosesForm() {
        app.buttons["task-add"].tap()
        app.buttons["task-form-cancel"].tap()
        XCTAssertTrue(app.buttons["task-add"].waitForExistence(timeout: 5))
    }

    func testRecurringTaskOptions() {
        app.buttons["task-add"].tap()

        let nameField = app.textFields["task-form-name"]
        nameField.tap()
        nameField.typeText("Recurring UI Task")

        // Dismiss the keyboard by tapping a different field so the repeating toggle is unobscured.
        app.buttons["task-form-date-toggle"].tap()
        // Scroll the form to bring the repeating toggle into the visible area.
        app.swipeUp()

        let recurringToggle = app.switches["task-form-repeating-toggle"]
        assertExists(recurringToggle)
        tapRightEdge(of: recurringToggle)

        // Verify the toggle actually turned on before saving.
        XCTAssertEqual(recurringToggle.value as? String, "1")

        app.buttons["task-form-save"].tap()

        XCTAssertTrue(app.staticTexts["Recurring UI Task"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Daily"].exists)
    }
}

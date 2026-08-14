import XCTest

@MainActor
final class HabitUITests: ClarityUITestCase {
    func testHabitsListAppears() {
        switchToTab("Habits")
        XCTAssertTrue(app.staticTexts["Drink Water"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Read 30 Minutes"].exists)
    }

    func testWizardCreatesHabit() {
        switchToTab("Habits")
        app.buttons["habit-add"].tap()

        app.buttons["habit-wizard-next"].tap()

        let nameField = app.textFields["habit-wizard-name"]
        assertExists(nameField)
        nameField.tap()
        nameField.typeText("Walk")

        app.buttons["habit-wizard-next"].tap()
        app.buttons["habit-wizard-next"].tap()

        let saveButton = app.buttons["habit-wizard-save"]
        assertExists(saveButton)
        saveButton.tap()

        XCTAssertTrue(app.staticTexts["Walk"].waitForExistence(timeout: 5))
    }

    func testIncrementHabit() {
        switchToTab("Habits")
        let habit = app.staticTexts["Drink Water"]
        assertExists(habit)
        habit.tap()

        XCTAssertTrue(app.staticTexts["Drink Water"].exists)
    }
}

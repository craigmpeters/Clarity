import XCTest

@MainActor
final class TaskListUITests: ClarityUITestCase {
    func testSeededTasksAppear() {
        XCTAssertTrue(app.staticTexts["Review quarterly reports"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Team standup meeting prep"].exists)
    }

    func testAddButtonOpensTaskForm() {
        app.buttons["task-add"].tap()
        XCTAssertTrue(app.textFields["task-form-name"].waitForExistence(timeout: 5))
    }

    func testFilterMenuChangesList() {
        XCTAssertTrue(app.staticTexts["Review quarterly reports"].waitForExistence(timeout: 5))

        app.buttons["Filter"].tap()
        app.buttons["All Tasks"].tap()

        XCTAssertTrue(app.staticTexts["Review quarterly reports"].waitForExistence(timeout: 5))
    }
}

import XCTest

@MainActor
final class TaskSwipeUITests: ClarityUITestCase {
    func testSwipeToComplete() {
        let taskCell = app.cells.containing(
            NSPredicate(format: "label == %@", "Review quarterly reports")
        ).firstMatch
        assertExists(taskCell)

        taskCell.swipeRight()
        let completeButton = app.buttons["Complete Task"]
        assertExists(completeButton, timeout: 3)
        completeButton.tap()

        XCTAssertFalse(app.staticTexts["Review quarterly reports"].waitForExistence(timeout: 5))
    }

    func testSwipeToDeleteAndConfirm() {
        let taskCell = app.cells.containing(
            NSPredicate(format: "label == %@", "Client presentation slides")
        ).firstMatch
        assertExists(taskCell)

        taskCell.swipeLeft()
        let deleteButton = app.buttons["Delete Task"]
        assertExists(deleteButton, timeout: 3)
        deleteButton.tap()

        let confirmDelete = app.buttons["Delete"]
        assertExists(confirmDelete, timeout: 3)
        confirmDelete.tap()

        XCTAssertFalse(app.staticTexts["Client presentation slides"].waitForExistence(timeout: 5))
    }
}

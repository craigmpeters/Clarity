//
//  ClarityUITestCase.swift
//  ClarityUITests
//
//  Base class for UI tests. Handles deterministic app launch and common helpers.
//

import XCTest

class ClarityUITestCase: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        try super.setUpWithError()
        continueAfterFailure = false

        app = XCUIApplication()
        app.launchArguments = [
            "--uitesting",
            "--uitesting-skip-onboarding",
            "--uitesting-disable-companion"
        ]
        app.terminate()
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
        try super.tearDownWithError()
    }

    // MARK: - Navigation helpers

    func switchToTab(_ identifier: String) {
        let tab = app.tabBars.buttons[identifier]
        XCTAssertTrue(tab.waitForExistence(timeout: 5))
        tab.tap()
    }

    func assertExists(_ element: XCUIElement, timeout: TimeInterval = 5) {
        XCTAssertTrue(element.waitForExistence(timeout: timeout))
    }

    // MARK: - Coordinate helpers

    func tapCoordinate(normalizedX: Double, normalizedY: Double) {
        let screenSize = app.windows.element(boundBy: 0).frame.size
        let point = CGPoint(
            x: screenSize.width * normalizedX,
            y: screenSize.height * normalizedY
        )
        let coordinate = app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
            .withOffset(CGVector(dx: point.x, dy: point.y))
        coordinate.tap()
    }

    func tapRightEdge(of element: XCUIElement) {
        element.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
    }

    // MARK: - Onboarding helpers

    func launchWithoutSkippingOnboarding() {
        app.terminate()
        app.launchArguments = ["--uitesting", "--uitesting-disable-companion"]
        app.launch()
    }
}

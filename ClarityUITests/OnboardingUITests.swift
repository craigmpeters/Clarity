import XCTest

@MainActor
final class OnboardingUITests: ClarityUITestCase {
    func testOnboardingFlowCompletesAndLandsOnTasks() {
        launchWithoutSkippingOnboarding()

        let nextButton = app.buttons["onboarding-next"]
        let getStartedButton = app.buttons["onboarding-get-started"]

        assertExists(nextButton)
        XCTAssertTrue(app.staticTexts["Welcome to Clarity"].exists)
        nextButton.tap()

        XCTAssertTrue(app.staticTexts["Swipe to Take Action"].exists)
        nextButton.tap()

        assertExists(getStartedButton)
        XCTAssertTrue(getStartedButton.label == "Get Started")
        getStartedButton.tap()

        XCTAssertTrue(app.tabBars.buttons["Tasks"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.collectionViews["task-list"].waitForExistence(timeout: 10))
    }

    func testOnboardingBackButtonNavigation() {
        launchWithoutSkippingOnboarding()

        let nextButton = app.buttons["onboarding-next"]
        let backButton = app.buttons["onboarding-back"]

        assertExists(nextButton)
        nextButton.tap()
        XCTAssertTrue(app.staticTexts["Swipe to Take Action"].exists)

        assertExists(backButton)
        backButton.tap()
        XCTAssertTrue(app.staticTexts["Welcome to Clarity"].exists)
    }
}

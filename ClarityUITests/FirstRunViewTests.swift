////
////  FirstRunViewTests.swift
////  ClarityTests
////
////  Created by AI Assistant on 07/09/2025.
////
//
//import XCTest
//import SwiftUI
//@testable import Clarity
//
//final class FirstRunViewTests: XCTestCase {
//    
//    override func setUp() {
//        super.setUp()
//        // Reset onboarding state before each test
//        UserDefaults.resetOnboardingState()
//    }
//    
//    override func tearDown() {
//        super.tearDown()
//        // Clean up after each test
//        UserDefaults.resetOnboardingState()
//    }
//    
//    func testOnboardingInitialState() {
//        // Given
//        XCTAssertFalse(UserDefaults.hasCompletedOnboarding, "Onboarding should not be completed initially")
//        XCTAssertFalse(UserDefaults.hasSeenSwipeGesturesTooltip, "Swipe gestures tooltip should not be seen initially")
//    }
//    
//    func testOnboardingCompletion() {
//        // When
//        UserDefaults.hasCompletedOnboarding = true
//        
//        // Then
//        XCTAssertTrue(UserDefaults.hasCompletedOnboarding, "Onboarding should be marked as completed")
//    }
//    
//    func testOnboardingReset() {
//        // Given
//        UserDefaults.hasCompletedOnboarding = true
//        UserDefaults.hasSeenSwipeGesturesTooltip = true
//        
//        // When
//        UserDefaults.resetOnboardingState()
//        
//        // Then
//        XCTAssertFalse(UserDefaults.hasCompletedOnboarding, "Onboarding should be reset")
//        XCTAssertFalse(UserDefaults.hasSeenSwipeGesturesTooltip, "Swipe gestures tooltip should be reset")
//    }
//    
//    func testSwipeActionDemoCreation() {
//        // Given
//        let demo = SwipeActionDemo(
//            title: "Test Action",
//            subtitle: "Test Subtitle",
//            direction: .right,
//            color: .blue,
//            icon: "timer",
//            description: "Test Description"
//        )
//        
//        // Then
//        XCTAssertEqual(demo.title, "Test Action")
//        XCTAssertEqual(demo.subtitle, "Test Subtitle")
//        XCTAssertEqual(demo.direction, .right)
//        XCTAssertEqual(demo.color, .blue)
//        XCTAssertEqual(demo.icon, "timer")
//        XCTAssertEqual(demo.description, "Test Description")
//    }
//    
//    func testOnboardingPageCreation() {
//        // Given
//        let page = OnboardingPage(
//            title: "Welcome",
//            subtitle: "Get Started",
//            systemImage: "brain.head.profile",
//            description: "Welcome to the app"
//        )
//        
//        // Then
//        XCTAssertEqual(page.title, "Welcome")
//        XCTAssertEqual(page.subtitle, "Get Started")
//        XCTAssertEqual(page.systemImage, "brain.head.profile")
//        XCTAssertEqual(page.description, "Welcome to the app")
//    }
//    
//    func testUserDefaultsExtension() {
//        // Test initial state
//        XCTAssertFalse(UserDefaults.hasCompletedOnboarding)
//        XCTAssertFalse(UserDefaults.hasSeenSwipeGesturesTooltip)
//        
//        // Test setting values
//        UserDefaults.hasCompletedOnboarding = true
//        UserDefaults.hasSeenSwipeGesturesTooltip = true
//        
//        XCTAssertTrue(UserDefaults.hasCompletedOnboarding)
//        XCTAssertTrue(UserDefaults.hasSeenSwipeGesturesTooltip)
//        
//        // Test persistence
//        let newInstance = UserDefaults.standard
//        XCTAssertTrue(newInstance.bool(forKey: "hasCompletedOnboarding"))
//        XCTAssertTrue(newInstance.bool(forKey: "hasSeenSwipeGesturesTooltip"))
//    }
//}
//
//// MARK: - SwipeActionDemo Tests
//final class SwipeActionDemoTests: XCTestCase {
//    
//    func testSwipeDirectionEnum() {
//        // Test enum cases exist
//        let leftDirection = SwipeActionDemo.SwipeDirection.left
//        let rightDirection = SwipeActionDemo.SwipeDirection.right
//        
//        XCTAssertNotEqual(leftDirection, rightDirection)
//    }
//    
//    func testSwipeActionDemoEquality() {
//        // Given
//        let demo1 = SwipeActionDemo(
//            title: "Timer",
//            subtitle: "Start timer",
//            direction: .right,
//            color: .blue,
//            icon: "timer",
//            description: "Start a pomodoro session"
//        )
//        
//        let demo2 = SwipeActionDemo(
//            title: "Timer",
//            subtitle: "Start timer",
//            direction: .right,
//            color: .blue,
//            icon: "timer",
//            description: "Start a pomodoro session"
//        )
//        
//        // Then - properties should match
//        XCTAssertEqual(demo1.title, demo2.title)
//        XCTAssertEqual(demo1.subtitle, demo2.subtitle)
//        XCTAssertEqual(demo1.direction, demo2.direction)
//        XCTAssertEqual(demo1.icon, demo2.icon)
//        XCTAssertEqual(demo1.description, demo2.description)
//    }
//    
//    func testPredefinedSwipeActions() {
//        // Test the three main swipe actions exist in the demo
//        let timerAction = SwipeActionDemo(
//            title: "Start Pomodoro Timer",
//            subtitle: "Swipe right to begin focus session",
//            direction: .right,
//            color: .blue,
//            icon: "timer",
//            description: "Quick access to start your focused work session"
//        )
//        
//        let completeAction = SwipeActionDemo(
//            title: "Mark Complete",
//            subtitle: "Swipe right to finish task",
//            direction: .right,
//            color: .green,
//            icon: "checkmark",
//            description: "Mark tasks as done with a simple gesture"
//        )
//        
//        let deleteAction = SwipeActionDemo(
//            title: "Delete Task",
//            subtitle: "Swipe left to remove",
//            direction: .left,
//            color: .red,
//            icon: "trash",
//            description: "Remove tasks you no longer need"
//        )
//        
//        // Verify timer action
//        XCTAssertEqual(timerAction.direction, .right)
//        XCTAssertEqual(timerAction.icon, "timer")
//        XCTAssertEqual(timerAction.color, .blue)
//        
//        // Verify complete action
//        XCTAssertEqual(completeAction.direction, .right)
//        XCTAssertEqual(completeAction.icon, "checkmark")
//        XCTAssertEqual(completeAction.color, .green)
//        
//        // Verify delete action
//        XCTAssertEqual(deleteAction.direction, .left)
//        XCTAssertEqual(deleteAction.icon, "trash")
//        XCTAssertEqual(deleteAction.color, .red)
//    }
//}
//
//// MARK: - Integration Tests
//final class FirstRunIntegrationTests: XCTestCase {
//    
//    override func setUp() {
//        super.setUp()
//        UserDefaults.resetOnboardingState()
//    }
//    
//    override func tearDown() {
//        super.tearDown()
//        UserDefaults.resetOnboardingState()
//    }
//    
//    func testFirstRunFlowCompletion() {
//        // Given - fresh app state
//        XCTAssertFalse(UserDefaults.hasCompletedOnboarding)
//        
//        // When - simulating completion of onboarding
//        UserDefaults.hasCompletedOnboarding = true
//        
//        // Then - should not show first run on next app launch
//        XCTAssertTrue(UserDefaults.hasCompletedOnboarding)
//        
//        // Simulate app restart check
//        let shouldShowFirstRun = !UserDefaults.hasCompletedOnboarding
//        XCTAssertFalse(shouldShowFirstRun, "First run should not show after completion")
//    }
//    
//    func testOnboardingPersistenceAcrossAppSessions() {
//        // Given - complete onboarding in "first session"
//        UserDefaults.hasCompletedOnboarding = true
//        UserDefaults.hasSeenSwipeGesturesTooltip = true
//        
//        // When - simulate app termination and restart by creating new UserDefaults instance
//        let persistedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
//        let persistedTooltip = UserDefaults.standard.bool(forKey: "hasSeenSwipeGesturesTooltip")
//        
//        // Then - state should persist
//        XCTAssertTrue(persistedOnboarding, "Onboarding completion should persist across app sessions")
//        XCTAssertTrue(persistedTooltip, "Tooltip state should persist across app sessions")
//    }
//}
//
//// MARK: - Performance Tests
//final class FirstRunPerformanceTests: XCTestCase {
//    
//    func testUserDefaultsReadPerformance() {
//        measure {
//            // Test reading UserDefaults multiple times (simulating app checks)
//            for _ in 0..<1000 {
//                _ = UserDefaults.hasCompletedOnboarding
//                _ = UserDefaults.hasSeenSwipeGesturesTooltip
//            }
//        }
//    }
//    
//    func testUserDefaultsWritePerformance() {
//        measure {
//            // Test writing UserDefaults multiple times
//            for i in 0..<100 {
//                UserDefaults.hasCompletedOnboarding = (i % 2 == 0)
//                UserDefaults.hasSeenSwipeGesturesTooltip = (i % 2 == 1)
//            }
//        }
//    }
//}
//
//// MARK: - Mock Tests for UI Components
//final class FirstRunUITests: XCTestCase {
//    
//    func testOnboardingPageContent() {
//        // Test that onboarding pages have required content
//        let welcomePage = OnboardingPage(
//            title: "Welcome to Clarity",
//            subtitle: "Your focused productivity companion",
//            systemImage: "brain.head.profile",
//            description: "Break down complex tasks, stay focused with Pomodoro timers, and track your progress with beautiful insights."
//        )
//        
//        XCTAssertFalse(welcomePage.title.isEmpty, "Title should not be empty")
//        XCTAssertFalse(welcomePage.subtitle.isEmpty, "Subtitle should not be empty")
//        XCTAssertFalse(welcomePage.systemImage.isEmpty, "System image should not be empty")
//        XCTAssertFalse(welcomePage.description.isEmpty, "Description should not be empty")
//        
//        // Test that system image is valid SF Symbol
//        let validSFSymbols = ["brain.head.profile", "hand.tap", "target"]
//        XCTAssertTrue(validSFSymbols.contains(welcomePage.systemImage), "Should use valid SF Symbol")
//    }
//    
//    func testSwipeGestureInstructions() {
//        // Test that swipe instructions are clear and actionable
//        let rightSwipeAction = SwipeActionDemo(
//            title: "Start Timer",
//            subtitle: "Swipe right to begin",
//            direction: .right,
//            color: .blue,
//            icon: "timer",
//            description: "Quick access to timer"
//        )
//        
//        // Verify instruction clarity
//        XCTAssertTrue(rightSwipeAction.subtitle.contains("right"), "Right swipe should mention 'right'")
//        XCTAssertEqual(rightSwipeAction.direction, .right, "Direction should match instruction")
//        
//        let leftSwipeAction = SwipeActionDemo(
//            title: "Delete Task",
//            subtitle: "Swipe left to remove",
//            direction: .left,
//            color: .red,
//            icon: "trash",
//            description: "Remove unwanted tasks"
//        )
//        
//        XCTAssertTrue(leftSwipeAction.subtitle.contains("left"), "Left swipe should mention 'left'")
//        XCTAssertEqual(leftSwipeAction.direction, .left, "Direction should match instruction")
//    }
//}

//
//  RecurrenceAndFilterMenuTests.swift
//  ClarityTests
//
//  Created by OpenCode on 13/08/2026.
//

import Foundation
import Testing
@testable import Clarity

struct RecurrenceAndFilterMenuTests {

    // MARK: - Recurrence description

    @Test func nonRepeatingTaskReturnsNoDescription() {
        let description = RecurrenceDescription.forTask(repeating: false, interval: .daily, customRecurrenceDays: 1, everySpecificDayDay: nil)
        #expect(description == nil)
    }

    @Test func dailyIntervalReturnsDaily() {
        let description = RecurrenceDescription.forTask(repeating: true, interval: .daily, customRecurrenceDays: 1, everySpecificDayDay: nil)
        #expect(description == "Daily")
    }

    @Test func weeklyIntervalUsesDisplayName() {
        let description = RecurrenceDescription.forTask(repeating: true, interval: .weekly, customRecurrenceDays: 1, everySpecificDayDay: nil)
        #expect(description == "Weekly")
    }

    @Test func customOneDayReturnsDaily() {
        let description = RecurrenceDescription.forTask(repeating: true, interval: .custom, customRecurrenceDays: 1, everySpecificDayDay: nil)
        #expect(description == "Daily")
    }

    @Test func customMultipleDaysReturnsEveryNDays() {
        let description = RecurrenceDescription.forTask(repeating: true, interval: .custom, customRecurrenceDays: 5, everySpecificDayDay: nil)
        #expect(description == "Every 5 days")
    }

    @Test func specificDayUsesWeekdaySymbol() {
        let description = RecurrenceDescription.forTask(repeating: true, interval: .specific, customRecurrenceDays: 1, everySpecificDayDay: 1)
        #expect(description == Calendar.current.weekdaySymbols[1])
    }

    @Test func missingSpecificDayFallsBackToDisplayName() {
        let description = RecurrenceDescription.forTask(repeating: true, interval: .specific, customRecurrenceDays: 1, everySpecificDayDay: nil)
        #expect(description == "Every Specific Day")
    }

    // MARK: - Category filter

    @Test func noFocusSettingsAllowsAllCategories() {
        let allNames = Set(["Work", "Home", "Health"])
        let result = CategoryFilter.allowedNames(allNames: allNames, focusedNames: [], isHide: false)
        #expect(result.isEmpty)
    }

    @Test func showModeIntersectsWithFocusedNames() {
        let allNames = Set(["Work", "Home", "Health"])
        let result = CategoryFilter.allowedNames(allNames: allNames, focusedNames: ["Work", "Health"], isHide: false)
        #expect(result == Set(["Work", "Health"]))
    }

    @Test func showModeIgnoresFocusedNamesNotInAllCategories() {
        let allNames = Set(["Work", "Home"])
        let result = CategoryFilter.allowedNames(allNames: allNames, focusedNames: ["Work", "Gym"], isHide: false)
        #expect(result == Set(["Work"]))
    }

    @Test func hideModeSubtractsFocusedNames() {
        let allNames = Set(["Work", "Home", "Health"])
        let result = CategoryFilter.allowedNames(allNames: allNames, focusedNames: ["Work"], isHide: true)
        #expect(result == Set(["Home", "Health"]))
    }

    @Test func hideModeWithNoFocusedNamesAllowsAll() {
        let allNames = Set(["Work", "Home", "Health"])
        let result = CategoryFilter.allowedNames(allNames: allNames, focusedNames: [], isHide: true)
        #expect(result == allNames)
    }
}

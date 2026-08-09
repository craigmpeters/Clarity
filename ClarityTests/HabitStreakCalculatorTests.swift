//
//  HabitStreakCalculatorTests.swift
//  ClarityTests
//
//  Created by OpenCode on 08/08/2026.
//

import Foundation
import Testing
@testable import Clarity

struct HabitStreakCalculatorTests {

    private let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 1 // Sunday, matching HabitStreakCalculator
        return cal
    }()
    private let habitUUID = UUID()

    private func date(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = 12
        return calendar.date(from: components) ?? Date()
    }

    private func occurrence(_ date: Date, completed: Bool = true, freezeUsed: Bool = false) -> HabitOccurrenceDTO {
        HabitOccurrenceDTO(
            habitUUID: habitUUID,
            periodStart: date,
            currentAmount: completed ? 1 : 0,
            completed: completed,
            freezeUsed: freezeUsed
        )
    }

    /// Generate completed occurrences for a full week starting at `weekStart`.
    private func fullWeek(start: Date) -> [HabitOccurrenceDTO] {
        (0..<7).compactMap { offset -> HabitOccurrenceDTO? in
            guard let day = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
            return occurrence(day)
        }
    }

    /// Return the start of the calendar week for the reference date.
    private func weekStart(for date: Date) -> Date {
        calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date
    }

    @Test func dailyHabitSevenDaysCountsOneWeekStreak() {
        let reference = date(year: 2026, month: 1, day: 7)
        let start = weekStart(for: reference)
        let occurrences = fullWeek(start: start)
        let result = HabitStreakCalculator.streak(occurrences: occurrences, frequency: 7, freezes: 0, referenceDate: reference)
        #expect(result.current == 1)
        #expect(result.longest == 1)
        #expect(result.freezesEarned == 1)
        #expect(result.atRisk == false)
    }

    @Test func threeTimesWeeklyHabitWithThreeCompletedDaysSucceeds() {
        let reference = date(year: 2026, month: 1, day: 7)
        let start = weekStart(for: reference)
        let occurrences = [0, 2, 4].compactMap { offset -> HabitOccurrenceDTO? in
            guard let day = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
            return occurrence(day)
        }
        let result = HabitStreakCalculator.streak(occurrences: occurrences, frequency: 3, freezes: 0, referenceDate: reference)
        #expect(result.current == 1)
        #expect(result.longest == 1)
    }

    @Test func freezeUsedOnMissedDayPreservesStreak() {
        let reference = date(year: 2026, month: 1, day: 14)
        let previousStart = calendar.date(byAdding: .day, value: -7, to: weekStart(for: reference))!
        var occurrences = (0..<6).compactMap { offset -> HabitOccurrenceDTO? in
            guard let day = calendar.date(byAdding: .day, value: offset, to: previousStart) else { return nil }
            return occurrence(day)
        }
        if let missedDay = calendar.date(byAdding: .day, value: 6, to: previousStart) {
            occurrences.append(occurrence(missedDay, completed: false, freezeUsed: true))
        }
        let result = HabitStreakCalculator.streak(occurrences: occurrences, frequency: 7, freezes: 1, referenceDate: reference)
        #expect(result.current == 1) // previous week succeeded; current week still in progress
        #expect(result.longest == 1)
        #expect(result.atRisk == false)
    }

    @Test func noFreezeAfterGraceWindowExpires() {
        // Previous week failed two weeks ago; the next period (last week) succeeded,
        // so we are now past the grace window for the failed week.
        let reference = date(year: 2026, month: 1, day: 25)
        let currentWeekStart = weekStart(for: reference)
        let previousStart = calendar.date(byAdding: .day, value: -7, to: currentWeekStart)!
        let failedStart = calendar.date(byAdding: .day, value: -7, to: previousStart)!
        var occurrences = (0..<5).compactMap { offset -> HabitOccurrenceDTO? in
            guard let day = calendar.date(byAdding: .day, value: offset, to: failedStart) else { return nil }
            return occurrence(day)
        }
        // Make the intervening week succeed so the failed week is the most recent miss.
        occurrences.append(contentsOf: fullWeek(start: previousStart))
        let result = HabitStreakCalculator.streak(occurrences: occurrences, frequency: 7, freezes: 1, referenceDate: reference)
        #expect(result.atRisk == false)
        #expect(result.current == 1) // previous week succeeded; in-progress week preserves the streak
    }

    @Test func freezeAvailableWithinNextPeriodGraceWindow() {
        // Previous week failed on Sunday 2026-01-11; today is the next Sunday 2026-01-18,
        // which is the start of the next period (the grace window).
        let reference = date(year: 2026, month: 1, day: 18)
        let previousStart = calendar.date(byAdding: .day, value: -7, to: weekStart(for: reference))!
        let occurrences = (0..<5).compactMap { offset -> HabitOccurrenceDTO? in
            guard let day = calendar.date(byAdding: .day, value: offset, to: previousStart) else { return nil }
            return occurrence(day)
        }
        let result = HabitStreakCalculator.streak(occurrences: occurrences, frequency: 7, freezes: 1, referenceDate: reference)
        #expect(result.atRisk == true)
        #expect(result.current == 0)
    }

    @Test func inProgressWeekPreservesExistingStreak() {
        let reference = date(year: 2026, month: 1, day: 8)
        let start = weekStart(for: reference)
        let previousStart = calendar.date(byAdding: .day, value: -7, to: start)!
        var occurrences = fullWeek(start: previousStart)
        // Add a few completed days in the current week but not enough to succeed yet.
        for offset in [0, 1] {
            if let day = calendar.date(byAdding: .day, value: offset, to: start) {
                occurrences.append(occurrence(day))
            }
        }
        let result = HabitStreakCalculator.streak(occurrences: occurrences, frequency: 7, freezes: 0, referenceDate: reference)
        #expect(result.current == 1) // previous week succeeded; current week in progress
        #expect(result.longest == 1)
    }

    @Test func freezesEarnedCapAtMaxFreezes() {
        let reference = date(year: 2026, month: 1, day: 21)
        let start = weekStart(for: reference)
        var occurrences = fullWeek(start: start)
        for offset in [1, 2] {
            if let previous = calendar.date(byAdding: .day, value: -offset * 7, to: start) {
                occurrences.append(contentsOf: fullWeek(start: previous))
            }
        }
        let result = HabitStreakCalculator.streak(occurrences: occurrences, frequency: 7, freezes: 0, referenceDate: reference)
        #expect(result.freezesEarned == 3)
    }

    @Test func weeklyBoundaryUsesCalendarWeek() {
        let reference = date(year: 2026, month: 1, day: 5)
        let start = weekStart(for: reference)
        let previousStart = calendar.date(byAdding: .day, value: -7, to: start)!
        let occurrences = fullWeek(start: previousStart)
        let result = HabitStreakCalculator.streak(occurrences: occurrences, frequency: 7, freezes: 0, referenceDate: reference)
        #expect(result.current == 1) // previous week only; current week has no completions
    }
}

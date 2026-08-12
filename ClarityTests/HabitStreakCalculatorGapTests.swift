//
//  HabitStreakCalculatorGapTests.swift
//  ClarityTests
//
//  Created by OpenCode on 09/08/2026.
//

import Foundation
import Testing
@testable import Clarity

struct HabitStreakCalculatorGapTests {

    private let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 1 // Sunday, matching HabitStreakCalculator
        return cal
    }()
    private let habitUUID = UUID()

    private func date(year: Int, month: Int, day: Int, hour: Int = 12) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        return calendar.date(from: components) ?? Date()
    }

    private func occurrence(
        _ date: Date,
        completed: Bool = true,
        freezeUsed: Bool = false,
        habitUUID: UUID? = nil
    ) -> HabitOccurrenceDTO {
        HabitOccurrenceDTO(
            habitUUID: habitUUID ?? self.habitUUID,
            periodStart: date,
            currentAmount: completed ? 1 : 0,
            completed: completed,
            freezeUsed: freezeUsed
        )
    }

    private func weekStart(for date: Date) -> Date {
        calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date
    }

    @Test func frequencyClamping() {
        let ref = date(year: 2026, month: 1, day: 7)
        let start = weekStart(for: ref)
        let occurrences = (0..<7).compactMap { offset -> HabitOccurrenceDTO? in
            guard let day = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
            return occurrence(day)
        }

        #expect(HabitStreakCalculator.streak(occurrences: occurrences, frequency: 0, freezes: 0, referenceDate: ref).current == 1)
        #expect(HabitStreakCalculator.streak(occurrences: occurrences, frequency: 8, freezes: 0, referenceDate: ref).current == 1)
        #expect(HabitStreakCalculator.streak(occurrences: occurrences, frequency: -3, freezes: 0, referenceDate: ref).current == 1)
    }

    @Test func emptyOccurrencesReturnsZero() {
        let ref = date(year: 2026, month: 1, day: 7)
        let result = HabitStreakCalculator.streak(occurrences: [], frequency: 7, freezes: 0, referenceDate: ref)
        #expect(result.current == 0)
        #expect(result.longest == 0)
        #expect(result.freezesEarned == 0)
        #expect(result.atRisk == false)
    }

    @Test func sameDayDuplicateKeepsMostRecent() {
        let ref = date(year: 2026, month: 1, day: 7)
        let start = weekStart(for: ref)
        let day1 = calendar.date(byAdding: .day, value: 0, to: start)!
        let day2 = calendar.date(byAdding: .day, value: 1, to: start)!

        // Two occurrences on day1: first completed, then later un-completed.
        let occurrences = [
            occurrence(day1, completed: true),
            occurrence(day1, completed: false),
            occurrence(day2, completed: true),
            occurrence(day2, completed: true),
            occurrence(day2, completed: true),
            occurrence(day2, completed: true),
            occurrence(day2, completed: true)
        ]

        let result = HabitStreakCalculator.streak(occurrences: occurrences, frequency: 7, freezes: 0, referenceDate: ref)
        // Most recent on day1 is un-completed, so the week is missing one day.
        #expect(result.current == 0)
    }

    @Test func longestEqualsCurrentWhenCurrentWeekIsOpen() {
        // PINNED: when the current week is still open, longest always equals current (not an all-time max).
        let ref = date(year: 2026, month: 1, day: 21)
        let start = weekStart(for: ref)
        var occurrences: [HabitOccurrenceDTO] = []
        for weekOffset in [0, -1, -2] {
            if let weekStart = calendar.date(byAdding: .weekOfYear, value: weekOffset, to: start) {
                for offset in 0..<7 {
                    if let day = calendar.date(byAdding: .day, value: offset, to: weekStart) {
                        occurrences.append(occurrence(day))
                    }
                }
            }
        }
        let result = HabitStreakCalculator.streak(occurrences: occurrences, frequency: 7, freezes: 0, referenceDate: ref)
        #expect(result.current == 3)
        #expect(result.longest == 3)
    }

    @Test func longestResetsToZeroWhenCurrentWeekClosedAndFailed() {
        // PINNED: when the current week is closed and failed, both current and longest are reset to 0.
        let previousWeekEnd = date(year: 2026, month: 1, day: 10)
        let reference = previousWeekEnd // Saturday: last day of the previous week, which is closed
        let previousStart = weekStart(for: previousWeekEnd)

        let occurrences = (0..<5).compactMap { offset -> HabitOccurrenceDTO? in
            guard let day = calendar.date(byAdding: .day, value: offset, to: previousStart) else { return nil }
            return occurrence(day)
        }

        let result = HabitStreakCalculator.streak(occurrences: occurrences, frequency: 7, freezes: 0, referenceDate: reference)
        #expect(result.current == 0)
        #expect(result.longest == 0)
    }

    @Test func atRiskAtMissedPeriodBoundary() {
        // Failed week: Jan 4-10 (only 5 days). Reference is the first day of the next week (Jan 11), which is
        // the start of the grace window.
        let missedWeekEnd = date(year: 2026, month: 1, day: 10)
        let missedStart = weekStart(for: missedWeekEnd)
        let reference = calendar.date(byAdding: .day, value: 1, to: missedWeekEnd)!

        let occurrences = (0..<5).compactMap { offset -> HabitOccurrenceDTO? in
            guard let day = calendar.date(byAdding: .day, value: offset, to: missedStart) else { return nil }
            return occurrence(day)
        }

        let result = HabitStreakCalculator.streak(occurrences: occurrences, frequency: 7, freezes: 1, referenceDate: reference)
        #expect(result.atRisk == true)
        #expect(result.missedPeriod != nil)
    }

    @Test func atRiskAtGraceEndBoundary() {
        // Failed week: Jan 4-10. The next week (Jan 11-17) succeeds, so the missed period is Jan 10.
        // Grace ends Jan 17. Reference is the very start of Jan 17, which is the last possible instant in the window.
        let missedWeekEnd = date(year: 2026, month: 1, day: 10)
        let missedStart = weekStart(for: missedWeekEnd)
        let nextWeekStart = calendar.date(byAdding: .day, value: 1, to: missedWeekEnd)!
        let reference = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 6, to: nextWeekStart)!)

        var occurrences: [HabitOccurrenceDTO] = []
        // Failed week: only 5 completions
        for offset in 0..<5 {
            if let day = calendar.date(byAdding: .day, value: offset, to: missedStart) {
                occurrences.append(occurrence(day))
            }
        }
        // Succeeding week: 7 completions
        for offset in 0..<7 {
            if let day = calendar.date(byAdding: .day, value: offset, to: nextWeekStart) {
                occurrences.append(occurrence(day))
            }
        }

        let result = HabitStreakCalculator.streak(occurrences: occurrences, frequency: 7, freezes: 1, referenceDate: reference)
        #expect(result.atRisk == true)
    }

    @Test func atRiskAfterGraceEndIsFalse() {
        // Failed week: Jan 4-10. The next week (Jan 11-17) succeeds, so the missed period is Jan 10.
        // Grace ends Jan 17. Reference Jan 18 is the first day after the grace window.
        let missedWeekEnd = date(year: 2026, month: 1, day: 10)
        let missedStart = weekStart(for: missedWeekEnd)
        let nextWeekStart = calendar.date(byAdding: .day, value: 1, to: missedWeekEnd)!
        let reference = calendar.date(byAdding: .day, value: 7, to: nextWeekStart)!

        var occurrences: [HabitOccurrenceDTO] = []
        for offset in 0..<5 {
            if let day = calendar.date(byAdding: .day, value: offset, to: missedStart) {
                occurrences.append(occurrence(day))
            }
        }
        for offset in 0..<7 {
            if let day = calendar.date(byAdding: .day, value: offset, to: nextWeekStart) {
                occurrences.append(occurrence(day))
            }
        }

        let result = HabitStreakCalculator.streak(occurrences: occurrences, frequency: 7, freezes: 1, referenceDate: reference)
        #expect(result.atRisk == false)
    }

    @Test func missedPeriodValueIsEndOfFailedWeek() {
        // PINNED: missedPeriod is the LAST day of the failed week (not the start).
        let missedWeekEnd = date(year: 2026, month: 1, day: 10)
        let missedStart = weekStart(for: missedWeekEnd)
        let nextWeekStart = calendar.date(byAdding: .day, value: 1, to: missedWeekEnd)!
        let reference = calendar.date(byAdding: .day, value: 1, to: nextWeekStart)!

        var occurrences: [HabitOccurrenceDTO] = []
        for offset in 0..<5 {
            if let day = calendar.date(byAdding: .day, value: offset, to: missedStart) {
                occurrences.append(occurrence(day))
            }
        }
        for offset in 0..<7 {
            if let day = calendar.date(byAdding: .day, value: offset, to: nextWeekStart) {
                occurrences.append(occurrence(day))
            }
        }

        let result = HabitStreakCalculator.streak(occurrences: occurrences, frequency: 7, freezes: 1, referenceDate: reference)
        #expect(result.missedPeriod == calendar.startOfDay(for: missedWeekEnd))
    }

    @Test func calculatorDoesNotFilterByHabitUUID() {
        // PINNED: the calculator treats all occurrences as belonging to the same habit.
        let ref = date(year: 2026, month: 1, day: 7)
        let start = weekStart(for: ref)
        let otherUUID = UUID()
        var occurrences = (0..<7).compactMap { offset -> HabitOccurrenceDTO? in
            guard let day = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
            return occurrence(day, habitUUID: self.habitUUID)
        }
        occurrences.append(occurrence(start, completed: true, habitUUID: otherUUID))

        let result = HabitStreakCalculator.streak(occurrences: occurrences, frequency: 7, freezes: 0, referenceDate: ref)
        #expect(result.current == 1)
    }
}

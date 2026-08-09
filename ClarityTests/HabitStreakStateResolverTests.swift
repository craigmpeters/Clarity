//
//  HabitStreakStateResolverTests.swift
//  ClarityTests
//
//  Unit tests for the companion's habit-streak state classification.
//

import Foundation
import Testing
@testable import Clarity

struct HabitStreakStateResolverTests {

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

    private func weekStart(for date: Date) -> Date {
        calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date
    }

    private func habit(weeklyFrequency: Int = 7, streakFreezes: Int = 0) -> HabitDTO {
        HabitDTO(
            name: "Test Habit",
            dailyTarget: 1,
            weeklyFrequency: weeklyFrequency,
            streakFreezes: streakFreezes
        )
    }

    @Test func milestoneStateAtSevenWeeks() {
        let reference = date(year: 2026, month: 1, day: 7)
        let start = weekStart(for: reference)
        var occurrences = fullWeek(start: start)
        // Add six prior successful weeks so after completing today we hit 7.
        for offset in 1...6 {
            if let previous = calendar.date(byAdding: .day, value: -offset * 7, to: start) {
                occurrences.append(contentsOf: fullWeek(start: previous))
            }
        }
        let state = HabitStreakState.resolve(
            habit: habit(),
            completedOccurrences: occurrences,
            completedAt: reference
        )
        #expect(state == .milestone(streak: 7))
    }

    @Test func continuedStateWhenExtendingStreak() {
        let reference = date(year: 2026, month: 1, day: 7)
        let start = weekStart(for: reference)
        var occurrences = fullWeek(start: start)
        // Add one prior successful week.
        if let previous = calendar.date(byAdding: .day, value: -7, to: start) {
            occurrences.append(contentsOf: fullWeek(start: previous))
        }
        let state = HabitStreakState.resolve(
            habit: habit(),
            completedOccurrences: occurrences,
            completedAt: reference
        )
        #expect(state == .continued(streak: 2))
    }

    @Test func savedStateWhenAtRisk() {
        // Previous week failed; today (first day of the new week) is within the grace window.
        // With one freeze available, the habit is at risk and this completion is a step toward saving it.
        let reference = date(year: 2026, month: 1, day: 18)
        let previousStart = calendar.date(byAdding: .day, value: -7, to: weekStart(for: reference))!
        let occurrences = (0..<5).compactMap { offset -> HabitOccurrenceDTO? in
            guard let day = calendar.date(byAdding: .day, value: offset, to: previousStart) else { return nil }
            return occurrence(day)
        }
        let state = HabitStreakState.resolve(
            habit: habit(streakFreezes: 1),
            completedOccurrences: occurrences,
            completedAt: reference
        )
        #expect(state == .saved(streak: 0))
    }

    @Test func restartedStateAfterBreak() {
        // One successful week, then a failed week, now completing again mid-week.
        // The streak is broken (0) but the longest streak was 1, so this is a restart.
        let reference = date(year: 2026, month: 1, day: 18)
        let currentWeekStart = weekStart(for: reference)
        let previousStart = calendar.date(byAdding: .day, value: -7, to: currentWeekStart)!
        let priorStart = calendar.date(byAdding: .day, value: -7, to: previousStart)!
        var occurrences = fullWeek(start: priorStart)
        occurrences.append(occurrence(previousStart)) // one completion in the failed week
        occurrences.append(occurrence(currentWeekStart)) // the completion being tested
        let state = HabitStreakState.resolve(
            habit: habit(),
            completedOccurrences: occurrences,
            completedAt: reference
        )
        #expect(state == .restarted(streak: 0))
    }
}

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
        cal.firstWeekday = 1  // Sunday, matching HabitStreakCalculator
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

    private func occurrence(_ date: Date, completed: Bool = true, freezeUsed: Bool = false)
        -> HabitOccurrenceDTO
    {
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
            guard let day = calendar.date(byAdding: .day, value: offset, to: start) else {
                return nil
            }
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

    @Test func milestoneStateAtSevenDays() throws {
        // One full successful week; reference is the week's Saturday, so the week
        // is closed and succeeded: current == 7 days, hitting the first milestone.
        let reference = date(year: 2026, month: 1, day: 7)
        let start = weekStart(for: reference)
        let saturday = try #require(calendar.date(byAdding: .day, value: 6, to: start))
        let occurrences = fullWeek(start: start)
        let state = HabitStreakState.resolve(
            habit: habit(),
            completedOccurrences: occurrences,
            completedAt: saturday
        )
        #expect(state == .milestone(streak: 7))
    }

    @Test func continuedStateWhenExtendingStreak() {
        // 14 consecutive completed days ending today (Wednesday). Rolling streak is
        // literal consecutive on-track days, not weeks×7: today completed (+1) plus
        // the 13 prior days. Just below the milestone trigger (14 is not a milestone).
        let reference = date(year: 2026, month: 1, day: 7)
        var occurrences: [HabitOccurrenceDTO] = []
        for offset in 0..<14 {
            if let day = calendar.date(byAdding: .day, value: -(13 - offset), to: reference) {
                occurrences.append(occurrence(day))
            }
        }
        let state = HabitStreakState.resolve(
            habit: habit(),
            completedOccurrences: occurrences,
            completedAt: reference
        )
        #expect(state == .continued(streak: 14))
    }

    @Test func savedStateWhenAtRisk() throws {
        // Previous week failed; today (first day of the new week) is within the grace window.
        // With one freeze available, the habit is at risk and this completion is a step toward saving it.
        let reference = date(year: 2026, month: 1, day: 18)
        let previousStart = try #require(
            calendar.date(byAdding: .day, value: -7, to: weekStart(for: reference)))
        let occurrences = (0..<5).compactMap { offset -> HabitOccurrenceDTO? in
            guard let day = calendar.date(byAdding: .day, value: offset, to: previousStart) else {
                return nil
            }
            return occurrence(day)
        }
        let state = HabitStreakState.resolve(
            habit: habit(streakFreezes: 1),
            completedOccurrences: occurrences,
            completedAt: reference
        )
        #expect(state == .saved(streak: 0))
    }

    @Test func restartedStateAfterBreak() throws {
        // One successful week, then a failed week. Resolved at the very start of the
        // new week, before any current-week completion, so the streak is broken (0)
        // while prior activity exists.
        // Rolling-model note: with 8 completed days in history the user has earned one
        // freeze (8 / 7 = 1), the balance is still spendable, and a missed day within
        // the grace window promotes the resolver to .saved rather than .restarted.
        // This is intentional — a streak reset never erases earned freezes.
        let currentWeekStart = date(year: 2026, month: 1, day: 18, hour: 0)
        let previousStart = try #require(
            calendar.date(byAdding: .day, value: -7, to: currentWeekStart))
        let priorStart = try #require(calendar.date(byAdding: .day, value: -7, to: previousStart))
        var occurrences = fullWeek(start: priorStart)
        occurrences.append(occurrence(previousStart))  // one completion in the failed week
        let state = HabitStreakState.resolve(
            habit: habit(),
            completedOccurrences: occurrences,
            completedAt: currentWeekStart
        )
        #expect(state == .saved(streak: 0))
    }

    @Test func restartedStateWithNoEarnedFreezes() throws {
        // Verify .restarted still exists: only enough history for 0 earned freezes
        // (6 completed days), so the resolver must report a true restart. There is
        // no balance and no grace-window rescue available.
        let currentWeekStart = date(year: 2026, month: 1, day: 18, hour: 0)
        let previousStart = try #require(
            calendar.date(byAdding: .day, value: -7, to: currentWeekStart))
        var occurrences: [HabitOccurrenceDTO] = []
        for offset in 0..<6 {
            if let day = calendar.date(byAdding: .day, value: offset, to: previousStart) {
                occurrences.append(occurrence(day))
            }
        }
        let state = HabitStreakState.resolve(
            habit: habit(),
            completedOccurrences: occurrences,
            completedAt: currentWeekStart
        )
        #expect(state == .restarted(streak: 0))
    }
}

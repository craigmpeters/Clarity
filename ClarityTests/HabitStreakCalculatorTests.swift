//
//  HabitStreakCalculatorTests.swift
//  ClarityTests
//
//  Adapter-level tests for `HabitStreakCalculator`, which now delegates to
//  `HabitProgressEngine` (rolling-window semantics). Calendar-week behaviour
//  was retired by Step B — see docs/20261004/clarity-rolling-habits-spec.md.
//

import Foundation
import Testing

@testable import Clarity

struct HabitStreakCalculatorTests {
    private let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 1  // Sunday, matching HabitStreakCalculator
        cal.timeZone = TimeZone(identifier: "Europe/London") ?? .current
        return cal
    }()

    private let habitUUID = UUID()

    private func date(year: Int, month: Int, day: Int, hour: Int = 12) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.timeZone = calendar.timeZone
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

    /// Build `count` completed days ending at (and including) `endingOn`, walking
    /// backwards day by day.
    private func rollingDays(endingOn: Date, count: Int) -> [HabitOccurrenceDTO] {
        (0..<count).compactMap { offset in
            guard
                let day = calendar.date(byAdding: .day, value: -(count - 1) + offset, to: endingOn)
            else { return nil }
            return occurrence(day)
        }
    }

    // MARK: - Adapter surface

    @Test func adapterConsecutiveDailyDays() {
        // 7 consecutive completed days ending Wednesday. Current streak is 7
        // (literal consecutive on-track days, not weeks×7).
        let reference = date(year: 2026, month: 1, day: 7)
        let occurrences = rollingDays(endingOn: reference, count: 7)
        let result = HabitStreakCalculator.streak(
            occurrences: occurrences, frequency: 7, freezes: 0, referenceDate: reference
        )
        #expect(result.current == 7)
        #expect(result.longest == 7)
        #expect(result.atRisk == false)
    }

    @Test func adapterFewerThanTargetStillCountsCompleted() {
        // 3-of-7 target with two completed days so far this week; the streak is
        // the literal chain (Tue completed, Sun completed 3 days earlier).
        // Streak runs back through Wed pending, Tue completed, Mon missed (breaks,
        // because trailing window credit 1 < 3 target). current = 1.
        let reference = date(year: 2026, month: 1, day: 7)
        let sunday = date(year: 2026, month: 1, day: 4)
        let tuesday = date(year: 2026, month: 1, day: 6)
        let occurrences = [occurrence(sunday), occurrence(tuesday)]
        let result = HabitStreakCalculator.streak(
            occurrences: occurrences, frequency: 3, freezes: 0, referenceDate: reference
        )
        #expect(result.current == 1)
        #expect(result.longest == 1)
    }

    @Test func adapterFrozenDayCountsAsOnTrack() throws {
        // 6 consecutive completed days ending Thursday, Friday frozen, Saturday pending.
        // The frozen Friday carries the chain forward. current = 7.
        let friday = date(year: 2026, month: 1, day: 16)
        let saturday = date(year: 2026, month: 1, day: 17)
        var occurrences = try rollingDays(
            endingOn: #require(calendar.date(byAdding: .day, value: -1, to: friday)), count: 6
        )
        occurrences.append(occurrence(friday, completed: false, freezeUsed: true))
        let result = HabitStreakCalculator.streak(
            occurrences: occurrences, frequency: 7, freezes: 0, referenceDate: saturday
        )
        #expect(result.current == 7)
        #expect(result.longest == 7)
        #expect(result.atRisk == false)
    }

    @Test func adapterMissWithinGraceWindowIsAtRisk() {
        // 7-day streak ends with a real miss 2 days ago; today is still within the
        // grace window so atRisk=true when a freeze is available.
        // For the adapter to surface atRisk we need to pass freezesSpent=0 and have
        // the engine derive at least one available freeze from completed-day history.
        let today = date(year: 2026, month: 1, day: 18)
        // 14 days completed ending 3 days ago; one missed day 2 days ago; one missed
        // day yesterday. This guarantees a streak break with a recent missedDay in
        // reach of the grace window.
        var occurrences: [HabitOccurrenceDTO] = []
        for offset in 3...16 {
            if let day = calendar.date(byAdding: .day, value: -offset, to: today) {
                occurrences.append(occurrence(day))
            }
        }
        let result = HabitStreakCalculator.streak(
            occurrences: occurrences, frequency: 7, freezes: 1, referenceDate: today
        )
        #expect(result.current == 0)
        #expect(result.atRisk == true)
        #expect(result.missedPeriod != nil)
    }

    @Test func adapterFreezeBalancePersistsAcrossStreakReset() throws {
        // 14 completed days ending last week, one miss yesterday, today pending.
        // Streak is broken (current = 0), longest retained, but the freeze balance
        // derived from completed-day history is preserved.
        let today = date(year: 2026, month: 1, day: 18)
        let occurrences = try rollingDays(
            endingOn: #require(calendar.date(byAdding: .day, value: -2, to: today)), count: 14
        )
        // Yesterday missed (no occurrence). Today pending.
        let result = HabitStreakCalculator.streak(
            occurrences: occurrences, frequency: 7, freezes: 0, referenceDate: today
        )
        #expect(result.current == 0)
        #expect(result.longest == 14)
        // 14 completed days >= 14, plus perfect-window bonuses; capped at 3.
        #expect(result.freezesEarned == HabitConfig.maxFreezes)
    }

    // MARK: - Saturday regression (Step A, still applies via the adapter)

    /// Regression: a daily habit with completions through Friday, evaluated on
    /// Saturday 12:00 with nothing yet logged, must NOT report a zero streak.
    @Test func saturdayWithUnfinishedWeekDoesNotResetStreak() {
        let saturday = date(year: 2026, month: 1, day: 10)
        // Completions Sun Jan 4 - Fri Jan 9 (6 days); Saturday pending.
        var occurrences: [HabitOccurrenceDTO] = []
        for offset in 1...6 {
            if let day = calendar.date(byAdding: .day, value: -offset, to: saturday) {
                occurrences.append(occurrence(day))
            }
        }
        let result = HabitStreakCalculator.streak(
            occurrences: occurrences, frequency: 7, freezes: 0, referenceDate: saturday
        )
        #expect(result.current == 6)
        #expect(result.atRisk == false)
    }

    /// Same data evaluated on Sunday 00:01 (after Saturday actually missed) — the
    /// streak is broken because yesterday genuinely missed.
    @Test func sundayAfterSaturdayMissedResetsStreak() {
        let sunday = date(year: 2026, month: 1, day: 11)
        var occurrences: [HabitOccurrenceDTO] = []
        for offset in 2...7 {
            if let day = calendar.date(byAdding: .day, value: -offset, to: sunday) {
                occurrences.append(occurrence(day))
            }
        }
        // Yesterday (Saturday) is missed.
        let result = HabitStreakCalculator.streak(
            occurrences: occurrences, frequency: 7, freezes: 0, referenceDate: sunday,
            freezesSpent: 0
        )
        #expect(result.current == 0)
        #expect(result.longest == 6)
        #expect(result.missedPeriod != nil)
        // 6 completed days is below the freeze-earn threshold, so atRisk must be false:
        // there's nothing to spend.
        #expect(result.atRisk == false)
    }

    /// Same scenario, but with enough completed history that freezes have been earned.
    /// The grace window opens immediately on Sunday after the missed Saturday, so the
    /// habit is at risk and a freeze could be spent.
    @Test func sundayAfterSaturdayMissedIsAtRiskWithEarnedFreeze() {
        let sunday = date(year: 2026, month: 1, day: 11)
        // 14 completed days ending Friday Jan 9 (so we have a long history and the
        // freeze accounting has something to count).
        var occurrences: [HabitOccurrenceDTO] = []
        for offset in 2...15 {
            if let day = calendar.date(byAdding: .day, value: -offset, to: sunday) {
                occurrences.append(occurrence(day))
            }
        }
        // Yesterday (Sat Jan 10) missed.
        let result = HabitStreakCalculator.streak(
            occurrences: occurrences, frequency: 7, freezes: 0, referenceDate: sunday,
            freezesSpent: 0
        )
        #expect(result.current == 0)
        #expect(result.atRisk == true)
        #expect(result.missedPeriod != nil)
    }
}

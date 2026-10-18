//
//  HabitProgressEngineTests.swift
//  ClarityTests
//
//  Step B: pure rolling-habit engine tests. Calendar is Sunday-start Gregorian in
//  Europe/London; `now` is injected; occurrences are all the engine sees.
//

import Foundation
import Testing

@testable import Clarity

struct HabitProgressEngineTests {
    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.firstWeekday = 1
        c.timeZone = TimeZone(identifier: "Europe/London")!
        return c
    }()

    private let habitUUID = UUID()

    // MARK: - Fixtures

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        var c = DateComponents()
        c.year = year
        c.month = month
        c.day = day
        c.hour = hour
        c.timeZone = calendar.timeZone
        return calendar.date(from: c) ?? Date()
    }

    private func occurrence(
        _ date: Date,
        completed: Bool = true,
        freezeUsed: Bool = false,
        amount: Double = 1
    ) -> HabitOccurrenceDTO {
        HabitOccurrenceDTO(
            habitUUID: habitUUID,
            periodStart: date,
            currentAmount: amount,
            completed: completed,
            freezeUsed: freezeUsed
        )
    }

    private func eval(
        _ occurrences: [HabitOccurrenceDTO],
        dailyTarget: Double = 1,
        targetDaysPerWindow: Int = 7,
        windowDays: Int = 7,
        freezesSpent: Int = 0,
        pauseRanges: [ClosedRange<Date>] = [],
        now: Date
    ) -> HabitProgressResult {
        HabitProgressEngine.evaluate(
            occurrences: occurrences,
            dailyTarget: dailyTarget,
            targetDaysPerWindow: targetDaysPerWindow,
            windowDays: windowDays,
            freezesSpent: freezesSpent,
            pauseRanges: pauseRanges,
            now: now,
            calendar: calendar
        )
    }

    private func rollDays(_ endingOn: Date, count: Int) -> [HabitOccurrenceDTO] {
        (0..<count).compactMap { offset in
            guard
                let day = calendar.date(byAdding: .day, value: -(count - 1) + offset, to: endingOn)
            else { return nil }
            return occurrence(day)
        }
    }

    // MARK: - 4. Streak continuity across Saturday/Sunday boundary

    @Test func saturdaySundayBoundaryDoesNotResetStreak() {
        // Full week Sun Oct 26 2025 ... Sat Nov 1 (all complete), evaluated Sat 12:00.
        let saturday = date(2025, 11, 1, hour: 12)
        let occurrences = rollDays(saturday, count: 7)
        let satResult = eval(occurrences, now: saturday)
        #expect(satResult.currentStreak == 7)

        // Same data evaluated Sun 00:01 next day (week actually closed) must still show 7.
        let sunday = date(2025, 11, 2, hour: 0)
        let sunResult = eval(occurrences, now: sunday)
        #expect(sunResult.currentStreak == 7)
    }

    // MARK: - 5. BST end 2026-10-25 no duplicated/skipped day

    @Test func bstBoundaryWalksExactlyOneDayPer() {
        // Britain leaves DST on 2026-10-25. Walk through the boundary with every day
        // completed and assert we credit every day once.
        let saturday = date(2026, 10, 25)
        let occurrences = rollDays(saturday, count: 14)
        let result = eval(occurrences, now: saturday)
        #expect(result.currentStreak == 14)
        #expect(result.longestStreak == 14)
    }

    // MARK: - 6. Daily habit, one miss + freeze available -> frozen, streak preserved

    @Test func oneMissWithFreezeSpentPreservesStreak() {
        // 6 consecutive completed days ending Wednesday. Thursday missed-but-frozen.
        // Friday completed. Today Saturday pending. Run should be 7 (6 + frozen + Fri).
        let today = date(2025, 11, 8)  // Saturday
        var occurrences: [HabitOccurrenceDTO] = []
        for offset in 3...8 {
            if let day = calendar.date(byAdding: .day, value: -offset, to: today) {
                occurrences.append(occurrence(day))
            }
        }
        // Frozen miss on t-2 (Thursday)
        if let thursday = calendar.date(byAdding: .day, value: -2, to: today) {
            occurrences.append(occurrence(thursday, completed: false, freezeUsed: true))
        }
        // Completed yesterday (Friday)
        if let friday = calendar.date(byAdding: .day, value: -1, to: today) {
            occurrences.append(occurrence(friday))
        }
        let result = eval(occurrences, freezesSpent: 1, now: today)
        // 6 completed + 1 frozen + 1 completed = 8-day run going back from yesterday;
        // today pending adds 0 because nothing is completed yet.
        #expect(result.currentStreak == 8)
        #expect(result.atRisk == false)
    }

    // MARK: - 7. Daily habit, one miss, no freeze -> current resets, longest kept

    @Test func oneMissWithoutFreezeResetsCurrentButKeepsLongest() {
        // 7 consecutive completed days ending last Saturday. Then last Sunday missed.
        // Today Saturday pending. Current resets to 0; longest is 7.
        let today = date(2025, 11, 8)
        var occurrences: [HabitOccurrenceDTO] = []
        for offset in 1...7 {
            if let day = calendar.date(byAdding: .day, value: -offset - 1, to: today) {
                occurrences.append(occurrence(day))
            }
        }
        let result = eval(occurrences, freezesSpent: 0, now: today)
        #expect(result.currentStreak == 0)
        #expect(result.longestStreak == 7)
        // Strength is a 13-day half-life EMA; after only 7 completions it sits below 0.5,
        // and the single miss multiplies by ~0.948 — it must not reset and must still be
        // substantially above 0.
        #expect(result.strength > 0.0)
        #expect(result.strength < 1.0)
    }

    // MARK: - 8. 5-of-7 habit tolerates two misses in window

    @Test func fiveOfSevenToleratesIsolatedMisses() {
        let today = date(2025, 11, 8)
        // Window of last 7 days: two days missed but 5 completed => still on track.
        var occurrences: [HabitOccurrenceDTO] = []
        for offset in 1...7 {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else {
                continue
            }
            if offset == 3 || offset == 6 {
                // skip -> missed
            } else {
                occurrences.append(occurrence(day))
            }
        }
        let result = eval(
            occurrences, targetDaysPerWindow: 5,
            now: today
        )
        // Yesterday is on track because trailing window has 5 credits.
        #expect(result.currentStreak >= 1)
    }

    // MARK: - 9. Partial credit

    @Test func partialCreditContribution() {
        let today = date(2025, 11, 8)
        let occurrences = [
            occurrence(today, completed: false, amount: 720)
        ]
        let result = eval(occurrences, dailyTarget: 2500, now: today)
        #expect(abs(result.windowCredit - 720.0 / 2500.0) < 0.0001)
        #expect(result.currentStreak == 0)  // Today pending, not yet completed
    }

    // MARK: - 10. Freeze earning

    @Test func sevenCompletedDaysEarnOneFreeze() {
        let today = date(2025, 11, 8)
        // Spread out 7 completed days across the past 14 days.
        var occurrences: [HabitOccurrenceDTO] = []
        for offset in [13, 11, 9, 7, 5, 3, 1] {
            if let day = calendar.date(byAdding: .day, value: -offset, to: today) {
                occurrences.append(occurrence(day))
            }
        }
        let result = eval(occurrences, targetDaysPerWindow: 3, now: today)
        #expect(result.freezesAvailable == 1)
    }

    @Test func streakResetNeverLowersFreezes() {
        // Even with a recent miss breaking the streak, the earned total derived from
        // completed-day history is preserved.
        let today = date(2025, 11, 8)
        var occurrences: [HabitOccurrenceDTO] = []
        // 14 completed days in the past (skip day -3 to break the chain).
        for offset in 1...14 {
            if let day = calendar.date(byAdding: .day, value: -offset - 1, to: today), offset != 3 {
                occurrences.append(occurrence(day))
            }
        }
        // Yesterday is missed (no occurrence).
        let result = eval(occurrences, now: today)
        #expect(result.currentStreak == 0)
        #expect(result.longestStreak >= 10)
        // 13 completed days >= 7, plus perfect-window bonuses for windows fully covered.
        // The exact total isn't the point — what matters is the balance is preserved
        // even though currentStreak == 0.
        #expect(result.freezesAvailable > 0)
    }

    @Test func freezesCapAtThree() {
        let today = date(2025, 11, 8)
        let occurrences = rollDays(today, count: 30)
        let result = eval(occurrences, now: today)
        // 30 completed days earns 4 freezes raw (30/7 = 4 with perfect-window bonuses),
        // but the engine caps at HabitConfig.maxFreezes (3).
        #expect(result.freezesAvailable == HabitConfig.maxFreezes)
    }

    // MARK: - 11. Pause range neutral

    @Test func pauseRangeIsNeutral() throws {
        // Five completed days t-7 ... t-3, two paused days t-2, t-1, today completed t.
        let today = date(2025, 11, 8)
        var occurrences: [HabitOccurrenceDTO] = []
        for offset in 3...7 {
            if let day = calendar.date(byAdding: .day, value: -offset, to: today) {
                occurrences.append(occurrence(day))
            }
        }
        let twoDaysAgo = try #require(calendar.date(byAdding: .day, value: -2, to: today))
        let yesterday = try #require(calendar.date(byAdding: .day, value: -1, to: today))
        let pause: ClosedRange<Date> = twoDaysAgo...yesterday
        occurrences.append(occurrence(today))
        let result = eval(occurrences, pauseRanges: [pause], now: today)
        // Streak walks back from today (completed) -> +1; yesterday & day-before paused
        // (on track); then 5 completed days. Total = 1 + 2 + 5 = 8.
        #expect(result.currentStreak == 8)
        // 6 completions = 6/7 of a freeze; cap respected, no spurious freeze from paused days.
        #expect(result.freezesAvailable == 0)
    }

    // MARK: - 12. Edge cases

    @Test func emptyHistoryYieldsZero() {
        let today = date(2025, 11, 8)
        let result = eval([], now: today)
        #expect(result.currentStreak == 0)
        #expect(result.longestStreak == 0)
        #expect(result.freezesAvailable == 0)
        #expect(result.atRisk == false)
        #expect(result.missedDay == nil)
    }

    @Test func futureDatedOccurrenceIgnored() throws {
        let today = date(2025, 11, 8)
        let tomorrow = try #require(calendar.date(byAdding: .day, value: 1, to: today))
        let occurrences = [occurrence(tomorrow)]
        let result = eval(occurrences, now: today)
        #expect(result.currentStreak == 0)
    }

    @Test func duplicateSameDayOccurrencesLatestWins() throws {
        let today = date(2025, 11, 8)
        let earlier = try #require(calendar.date(byAdding: .hour, value: -1, to: today))
        let later = today
        let occurrences = [
            occurrence(earlier, completed: true),
            HabitOccurrenceDTO(
                habitUUID: habitUUID,
                periodStart: later,
                currentAmount: 0,
                completed: false
            ),
        ]
        let result = eval(occurrences, now: today)
        // Latest is incomplete, so credit is not counted.
        #expect(result.windowCredit == 0)
    }

    // MARK: - 14. Performance sanity

    @Test func evaluatesThousandDaysQuickly() {
        let today = date(2025, 11, 8)
        var occurrences: [HabitOccurrenceDTO] = []
        for offset in 0..<1000 {
            if let day = calendar.date(byAdding: .day, value: -offset, to: today) {
                occurrences.append(occurrence(day))
            }
        }
        let start = Date()
        let result = eval(occurrences, now: today)
        let elapsed = Date().timeIntervalSince(start)
        #expect(
            elapsed < 0.5, "engine should evaluate 1000 days in well under 500 ms (\(elapsed)s)"
        )
        #expect(result.longestStreak >= 1000)
    }
}

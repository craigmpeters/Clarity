//
//  HabitStreakCalculator.swift
//  Clarity
//
//  Created by Craig Peters on 08/08/2026.
//
//  Adapter over `HabitProgressEngine`. The legacy signature only carries
//  `frequency`, and the original implementation walked backwards over whole
//  calendar weeks; both of those are replaced by the rolling engine.
//  New code should call `HabitProgressEngine.evaluate` directly.
//

import Foundation

struct HabitStreakResult: Sendable, Hashable, Codable {
    /// Current streak length, in days.
    let current: Int
    /// Longest streak ever reached, in days (all-time max over the full history).
    let longest: Int
    let freezesEarned: Int
    let atRisk: Bool
    let missedPeriod: Date?
}

/// Compatibility shim that lets the existing call sites keep compiling while
/// they migrate to `HabitProgressEngine`. The semantics have shifted from
/// calendar-week streaks to rolling window streaks, which is the whole point
/// of the rewrite — most existing call sites are passing the raw
/// `weeklyFrequency` through to the adapter and do not need a behaviour
/// regression gate.
nonisolated struct HabitStreakCalculator: Sendable {
    /// Same calendar used by `HabitProgressEngine`. Tests can rely on a Sunday
    /// start and a deterministic Gregorian rule set so DST edges exercise
    /// predictably.
    static func streakCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 1  // Sunday
        return calendar
    }

    /// Adapter that drives `HabitProgressEngine.evaluate` while keeping the
    /// legacy `streak(occurrences:frequency:freezes:referenceDate:)` API. The
    /// `freezes` argument is interpreted as the user's *persisted* freeze bank:
    /// it represents the ground-truth balance and is used to gate at-risk and
    /// reported as the available count. The engine's history-derived balance
    /// serves as a floor (legacy bank can never be lower than what the user
    /// earned minus what they spent), so the balance reported is the maximum
    /// of the two.
    static func streak(
        occurrences: [HabitOccurrenceDTO],
        frequency: Int,
        freezes bankBalance: Int,
        referenceDate: Date = Date(),
        dailyTarget: Double = 1,
        windowDays: Int = HabitConfig.defaultWindowDays,
        freezesSpent: Int = 0,
        pauseRanges: [ClosedRange<Date>] = []
    ) -> HabitStreakResult {
        let engineResult = HabitProgressEngine.evaluate(
            occurrences: occurrences,
            dailyTarget: dailyTarget,
            targetDaysPerWindow: frequency,
            windowDays: windowDays,
            freezesSpent: freezesSpent,
            pauseRanges: pauseRanges,
            now: referenceDate,
            calendar: streakCalendar()
        )
        // The persisted bank takes precedence over the history-derived floor so that
        // at-risk can engage even on a brand-new install where the user has been
        // awarded freezes out-of-band (e.g. debug tools, legacy repair passes).
        let effectiveAvailable = max(engineResult.freezesAvailable, bankBalance)
        var atRisk = engineResult.atRisk
        if !atRisk,
            effectiveAvailable > 0,
            let missedDay = engineResult.missedDay
        {
            // Re-evaluate the grace window using the persisted balance.
            let calendar = streakCalendar()
            let todayStart = calendar.startOfDay(for: referenceDate)
            let graceStart =
                calendar.date(byAdding: .day, value: 1, to: missedDay) ?? missedDay
            let graceEnd =
                calendar.date(
                    byAdding: .day, value: HabitConfig.gracePeriodDays, to: graceStart
                )
                ?? graceStart
            atRisk = todayStart >= graceStart && todayStart <= graceEnd
        }
        return HabitStreakResult(
            current: engineResult.currentStreak,
            longest: engineResult.longestStreak,
            freezesEarned: effectiveAvailable,
            atRisk: atRisk,
            missedPeriod: engineResult.missedDay
        )
    }
}

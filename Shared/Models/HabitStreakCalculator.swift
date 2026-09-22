//
//  HabitStreakCalculator.swift
//  Clarity
//
//  Created by Craig Peters on 08/08/2026.
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

/// Pure, nonisolated streak calculator over `HabitOccurrenceDTO` arrays.
/// A week succeeds if the number of completed/frozen days is >= `weeklyFrequency`.
/// A streak is expressed in days and can span multiple successful weeks:
/// each consecutive successful week contributes 7 days, and the in-progress
/// current week contributes its completed/frozen days so far. A failed week
/// breaks the chain. Freezes are auto-earned at a rate of 1 per 7 days of
/// streak, capped in the model at 3. The grace window for spending a freeze is
/// the end of the next period.
nonisolated struct HabitStreakCalculator: Sendable {

    /// Streak periods are always 7-day calendar weeks starting on Sunday so that streaks
    /// are deterministic across locales and the freeze grace window is unambiguous.
    static func streakCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 1 // Sunday
        return calendar
    }

    static func streak(
        occurrences: [HabitOccurrenceDTO],
        frequency: Int,
        freezes: Int,
        referenceDate: Date = Date()
    ) -> HabitStreakResult {
        let calendar = streakCalendar()
        let effectiveFrequency = max(1, min(7, frequency))
        let periodDays = HabitConfig.periodDays

        // Bucket occurrences by day, keeping the most recent if duplicates exist.
        var days: [Date: HabitOccurrenceDTO] = [:]
        for occurrence in occurrences {
            let day = calendar.startOfDay(for: occurrence.periodStart)
            if let existing = days[day] {
                if occurrence.periodStart > existing.periodStart {
                    days[day] = occurrence
                }
            } else {
                days[day] = occurrence
            }
        }

        func weekInterval(for date: Date) -> (start: Date, end: Date) {
            let start = calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date
            let end = calendar.date(byAdding: .day, value: periodDays, to: start)?.addingTimeInterval(-1) ?? start
            return (start, end)
        }

        func daysCounted(in weekStart: Date) -> Int {
            var count = 0
            for offset in 0..<periodDays {
                if let day = calendar.date(byAdding: .day, value: offset, to: weekStart) {
                    let occurrence = days[calendar.startOfDay(for: day)]
                    if occurrence?.completed ?? false || occurrence?.freezeUsed ?? false {
                        count += 1
                    }
                }
            }
            return count
        }

        func weekSucceeded(_ weekStart: Date) -> Bool {
            daysCounted(in: weekStart) >= effectiveFrequency
        }

        func isLastDayOfWeek(_ date: Date) -> Bool {
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: date) else { return false }
            return calendar.dateInterval(of: .weekOfYear, for: date)?.start != calendar.dateInterval(of: .weekOfYear, for: nextDay)?.start
        }

        let (currentWeekStart, currentWeekEnd) = weekInterval(for: referenceDate)
        let currentWeekSucceeded = weekSucceeded(currentWeekStart)
        let currentWeekClosed = isLastDayOfWeek(referenceDate)

        // Current streak, in days.
        var currentStreak = 0
        var missedPeriod: Date?
        var lastWeekFailed = false

        if currentWeekClosed && !currentWeekSucceeded {
            // The current week has just ended and did not meet the target; the streak is broken.
            lastWeekFailed = true
            missedPeriod = currentWeekEnd
            currentStreak = 0
        } else {
            // Count consecutive successful weeks immediately before the current week.
            var weekStart = currentWeekStart
            while true {
                guard let previousWeekStart = calendar.date(byAdding: .weekOfYear, value: -1, to: weekStart) else {
                    break
                }
                weekStart = previousWeekStart
                if weekSucceeded(weekStart) {
                    currentStreak += periodDays
                } else {
                    missedPeriod = calendar.date(byAdding: .day, value: periodDays - 1, to: weekStart)
                    lastWeekFailed = true
                    break
                }
            }
            // The current week contributes 7 days once it has met its target, otherwise
            // only the days completed/frozen so far.
            currentStreak += currentWeekSucceeded ? periodDays : daysCounted(in: currentWeekStart)
        }

        // Longest streak ever, in days: scan every week from the earliest occurrence
        // forward, tracking the running chain (in days) and its all-time maximum.
        let longestStreak: Int = {
            guard let earliest = days.keys.min() else { return currentStreak }
            var weekStart = calendar.dateInterval(of: .weekOfYear, for: earliest)?.start ?? earliest
            var running = 0
            var longest = 0
            while weekStart <= currentWeekStart {
                if weekStart == currentWeekStart {
                    // Mirror the current-week rule used for the current streak.
                    running = currentWeekSucceeded ? running + periodDays : running + daysCounted(in: currentWeekStart)
                } else if weekSucceeded(weekStart) {
                    running += periodDays
                } else {
                    running = 0
                }
                longest = max(longest, running)
                guard let next = calendar.date(byAdding: .weekOfYear, value: 1, to: weekStart) else { break }
                weekStart = next
            }
            return max(longest, currentStreak)
        }()

        // 1 freeze per 7 days of streak, capped in the model.
        let freezesEarned = min(currentStreak / HabitConfig.freezeEarnIntervalDays, HabitConfig.maxFreezes)

        // At risk if the most recently completed period failed, we have freezes available,
        // and we are within the grace window that ends at the end of the next period.
        // The boundary itself is included: a freeze can be spent at the very end of the
        // missed period and any time before the next period closes.
        let atRisk: Bool = {
            guard lastWeekFailed, freezes > 0, let missedPeriod = missedPeriod else { return false }
            guard let graceEnd = calendar.date(byAdding: .day, value: HabitConfig.gracePeriodDays, to: missedPeriod) else { return false }
            return referenceDate >= missedPeriod && referenceDate <= graceEnd
        }()

        return HabitStreakResult(
            current: currentStreak,
            longest: longestStreak,
            freezesEarned: freezesEarned,
            atRisk: atRisk,
            missedPeriod: missedPeriod
        )
    }
}

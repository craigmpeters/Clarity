//
//  HabitStreakCalculator.swift
//  Clarity
//
//  Created by Craig Peters on 08/08/2026.
//

import Foundation

struct HabitStreakResult: Sendable, Hashable, Codable {
    let current: Int
    let longest: Int
    let freezesEarned: Int
    let atRisk: Bool
    let missedPeriod: Date?
}

/// Pure, nonisolated streak calculator over `HabitOccurrenceDTO` arrays.
/// A week succeeds if the number of completed/frozen days is >= `weeklyFrequency`.
/// A streak is the number of consecutive successful weeks ending at the current week.
/// In-progress weeks preserve the streak from prior weeks until they actually fail.
/// Freezes are auto-earned at a rate of 1 per 7 days of streak, capped in the model at 3.
nonisolated struct HabitStreakCalculator: Sendable {

    static func streak(
        occurrences: [HabitOccurrenceDTO],
        frequency: Int,
        freezes: Int,
        referenceDate: Date = Date()
    ) -> HabitStreakResult {
        let calendar = Calendar.current
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

        func isLastDayOfWeek(_ date: Date) -> Bool {
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: date) else { return false }
            return calendar.dateInterval(of: .weekOfYear, for: date)?.start != calendar.dateInterval(of: .weekOfYear, for: nextDay)?.start
        }

        let (currentWeekStart, currentWeekEnd) = weekInterval(for: referenceDate)
        let currentWeekSucceeded = daysCounted(in: currentWeekStart) >= effectiveFrequency
        let currentWeekClosed = isLastDayOfWeek(referenceDate)

        var streakSoFar = 0
        var missedPeriod: Date?
        var lastWeekFailed = false
        var currentStreak = 0
        var longestStreak = 0

        if currentWeekClosed && !currentWeekSucceeded {
            // The current week has ended and did not meet the target; the streak is broken.
            lastWeekFailed = true
            missedPeriod = currentWeekEnd
            currentStreak = 0
            longestStreak = 0
        } else {
            // Walk backward from the previous week, counting consecutive successful weeks.
            var weekStart = currentWeekStart
            while true {
                guard let previousWeekStart = calendar.date(byAdding: .weekOfYear, value: -1, to: weekStart) else {
                    break
                }
                weekStart = previousWeekStart
                let succeeded = daysCounted(in: weekStart) >= effectiveFrequency
                if succeeded {
                    streakSoFar += 1
                } else {
                    missedPeriod = calendar.date(byAdding: .day, value: periodDays - 1, to: weekStart)
                    lastWeekFailed = true
                    break
                }
            }
            currentStreak = streakSoFar + (currentWeekSucceeded ? 1 : 0)
            longestStreak = max(currentStreak, streakSoFar)
        }

        let freezesEarned = min(currentStreak * periodDays / HabitConfig.freezeEarnIntervalDays, HabitConfig.maxFreezes)

        // At risk if the last completed week failed, we are still in the grace window,
        // and we have freezes available.
        let atRisk: Bool = {
            guard lastWeekFailed, freezes > 0, let missedPeriod = missedPeriod else { return false }
            let graceEnd = calendar.date(byAdding: .day, value: HabitConfig.gracePeriodDays, to: missedPeriod) ?? missedPeriod
            return referenceDate <= graceEnd && referenceDate > missedPeriod
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

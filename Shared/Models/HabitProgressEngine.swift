//
//  HabitProgressEngine.swift
//  Clarity
//
//  Pure, nonisolated rolling-habit evaluation. Replaces the calendar-week
//  logic in `HabitStreakCalculator`. Day states are derived from
//  `HabitOccurrenceDTO`s and the streak / strength / freeze balance all
//  follow from a single day-by-day walk.
//

import Foundation

/// A single calendar day's state for a habit.
nonisolated struct HabitDayState: Sendable, Hashable, Codable {
    nonisolated enum Kind: Sendable, Hashable, Codable {
        case completed
        /// 0 < credit < 1.0 (i.e. some progress but not enough to meet the daily target)
        case partial(Double)
        /// Day ended with no completion
        case missed
        /// Day was marked frozen (a freeze was spent)
        case frozen
        /// Day is within an explicit pause range
        case paused
        /// Today, not yet complete. Never counts as missed.
        case pending
    }

    let day: Date
    let kind: Kind
}

/// Aggregated result of evaluating a habit's history over a rolling window.
nonisolated struct HabitProgressResult: Sendable, Hashable, Codable {
    /// Sum of credits over the trailing `windowDays` window. A completed day
    /// contributes 1.0; a partial day contributes its fraction.
    let windowCredit: Double
    /// The number of days in the window that count toward the denominator,
    /// i.e. `windowDays` minus days that were frozen or paused.
    let windowDenominator: Int
    /// Reinterpretation of `weeklyFrequency`: the number of days we want to
    /// hit in the trailing `windowDays` window.
    let windowTarget: Int
    /// Loop-style habit strength, 0.0 ... 1.0. Decays but never resets.
    let strength: Double
    /// Consecutive on-track days ending yesterday, +1 if today is completed.
    let currentStreak: Int
    /// All-time max streak; never decreases on break.
    let longestStreak: Int
    /// Currently spendable freezes (already capped at `HabitConfig.maxFreezes`).
    let freezesAvailable: Int
    /// Progress toward the next freeze, 0...6 days.
    let freezeProgressDays: Int
    /// True when yesterday was a true miss, no freeze has been applied there, a
    /// freeze is available, and we are within the grace window.
    let atRisk: Bool
    /// The most recent missed day within reach (for retroactive freeze spend).
    /// Always the start-of-day.
    let missedDay: Date?
}

/// Pure evaluator. All time comes from the caller via `now`; the calendar is
/// injected so the engine is deterministic across time zones and DST edges.
nonisolated enum HabitProgressEngine {
    /// Maximum day-walk horizon to bound the loop. Three years of daily data
    /// is well past any realistic habit history and keeps the loop predictable.
    private nonisolated static let maxHistoryDays = 365 * 3

    /// - Parameters:
    ///   - occurrences: every known occurrence, in any order. Same-day duplicates are
    ///     discarded keeping the latest `periodStart`.
    ///   - dailyTarget: amount required for a day to count as `completed`.
    ///   - targetDaysPerWindow: rolling-window target (was `weeklyFrequency`).
    ///   - windowDays: length of the trailing window. Must be > 0.
    ///   - freezesSpent: number of freezes the user has already spent (persisted).
    ///   - pauseRanges: day ranges during which the habit is paused. Frozen and
    ///     paused days carry strength forward but earn no credit.
    ///   - now: evaluation timestamp; never `Date()` inside this function.
    ///   - calendar: caller-provided calendar. Tests use a Sunday-start Gregorian
    ///     calendar matching `HabitStreakCalculator.streakCalendar()`.
    nonisolated static func evaluate(
        occurrences: [HabitOccurrenceDTO],
        dailyTarget: Double,
        targetDaysPerWindow: Int,
        windowDays: Int,
        freezesSpent: Int,
        pauseRanges: [ClosedRange<Date>],
        now: Date,
        calendar: Calendar
    ) -> HabitProgressResult {
        let target = max(1.0, dailyTarget)
        let windowDays = max(1, windowDays)
        let targetPerWindow = max(1, min(windowDays, targetDaysPerWindow))

        // Bucket occurrences by start-of-day, latest timestamp wins.
        let todayStart = calendar.startOfDay(for: now)
        let cappedStart = maxHistoryStart(todayStart: todayStart, calendar: calendar)
        var byDay: [Date: HabitOccurrenceDTO] = [:]
        for occurrence in occurrences {
            // Skip future-dated occurrences: they can appear transiently in tests but
            // should not blow up the day walk or imply a completed future.
            guard occurrence.periodStart <= now else { continue }
            let day = calendar.startOfDay(for: occurrence.periodStart)
            // Skip anything older than the cap to keep the walk bounded.
            if day < cappedStart {
                continue
            }
            if let existing = byDay[day] {
                if occurrence.periodStart > existing.periodStart {
                    byDay[day] = occurrence
                }
            } else {
                byDay[day] = occurrence
            }
        }

        // No history at all means there is nothing to walk; short-circuit with an empty
        // result so we never spuriously flag today as a "miss".
        guard let firstDay = byDay.keys.min() else {
            return HabitProgressResult(
                windowCredit: 0,
                windowDenominator: 0,
                windowTarget: max(1, min(windowDays, targetDaysPerWindow)),
                strength: 0,
                currentStreak: 0,
                longestStreak: 0,
                freezesAvailable: 0,
                freezeProgressDays: 0,
                atRisk: false,
                missedDay: nil
            )
        }

        // Pause ranges in startOfDay form for O(1) lookup
        let pausedDays: Set<Date> = Set(
            pauseRanges.flatMap { range in
                var days: [Date] = []
                var cursor = calendar.startOfDay(for: range.lowerBound)
                let end = calendar.startOfDay(for: range.upperBound)
                while cursor <= end {
                    days.append(cursor)
                    guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else {
                        break
                    }
                    cursor = next
                }
                return days
            }
        )

        // Walk day by day from firstDay through today, building state and updating
        // running metrics.
        var dayStates: [Date: HabitDayState.Kind] = [:]
        var strength: Double = 0
        let freq = Double(targetPerWindow) / Double(windowDays)
        let multiplier = pow(0.5, sqrt(freq) / 13.0)

        var cursor = firstDay
        while cursor <= todayStart {
            let kind = classify(
                day: cursor,
                occurrence: byDay[cursor],
                dailyTarget: target,
                todayStart: todayStart,
                pausedDays: pausedDays
            )
            dayStates[cursor] = kind
            switch kind {
            case .completed:
                strength = strength * multiplier + 1.0 * (1 - multiplier)
            case let .partial(credit):
                strength = strength * multiplier + credit * (1 - multiplier)
            case .missed:
                strength = strength * multiplier
            case .frozen, .paused:
                // Neutral days: carry the previous strength forward
                break
            case .pending:
                // Pending days are today that hasn't been completed. We don't decay
                // or strengthen them.
                break
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }

        // Rolling-window credit: sum over [todayStart - windowDays + 1 ... todayStart].
        let windowStartDay =
            calendar.date(byAdding: .day, value: -(windowDays - 1), to: todayStart) ?? todayStart
        var windowCredit: Double = 0
        var denominatorDays = 0
        var dayCursor = windowStartDay
        while dayCursor <= todayStart {
            if let kind = dayStates[dayCursor] {
                switch kind {
                case .completed:
                    windowCredit += 1.0
                    denominatorDays += 1
                case let .partial(credit):
                    windowCredit += credit
                    denominatorDays += 1
                case .missed, .pending:
                    denominatorDays += 1
                case .frozen, .paused:
                    // Removed from denominator entirely
                    break
                }
            } else {
                // No record for the day at all — it counts against the denominator
                // unless it was paused.
                if pausedDays.contains(dayCursor) {
                    // paused
                } else {
                    denominatorDays += 1
                }
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: dayCursor) else { break }
            dayCursor = next
        }

        // Streak: count consecutive on-track days ending yesterday, +1 if today
        // is completed (or frozen/paused, which are neutral and preserve the run).
        // "On track" for a past day D means: D is completed/frozen/paused, OR the
        // trailing window ending on D has credit >= targetPerWindow.
        var currentStreak = 0
        let yesterdayStart =
            calendar.date(byAdding: .day, value: -1, to: todayStart) ?? todayStart
        var streakCursor = yesterdayStart
        while streakCursor >= firstDay {
            if isOnTrackDay(
                day: streakCursor,
                dayStates: dayStates,
                windowDays: windowDays,
                targetPerWindow: targetPerWindow,
                calendar: calendar
            ) {
                currentStreak += 1
            } else {
                break
            }
            guard let prev = calendar.date(byAdding: .day, value: -1, to: streakCursor) else {
                break
            }
            streakCursor = prev
        }
        if let todayKind = dayStates[todayStart], todayKind == .completed {
            currentStreak += 1
        }

        // Longest streak: walk forward tracking consecutive on-track days.
        // The current day being completed extends the running chain temporarily;
        // a pending day is treated neutrally (doesn't break but doesn't extend).
        var running = 0
        var longest = 0
        cursor = firstDay
        while cursor <= todayStart {
            let kind = dayStates[cursor]!
            switch kind {
            case .completed:
                running += 1
                longest = max(longest, running)
            case .frozen, .paused:
                // Neutral: doesn't extend, doesn't break.
                break
            case .partial:
                // A partial day with enough trailing-window credit counts as on track;
                // otherwise it breaks the run.
                if isOnTrackDay(
                    day: cursor,
                    dayStates: dayStates,
                    windowDays: windowDays,
                    targetPerWindow: targetPerWindow,
                    calendar: calendar
                ) {
                    running += 1
                    longest = max(longest, running)
                } else {
                    running = 0
                }
            case .missed:
                running = 0
            case .pending:
                break
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        longest = max(longest, currentStreak)

        // Freeze accounting: +1/7 per completed day (consecutive or not); +1/7 bonus
        // once per window when the trailing window's credit hits windowDays. Spendable
        // balance subtracts `freezesSpent` and is capped at maxFreezes. Crucially,
        // the balance is derived from completed-day history, NEVER from the current
        // streak, so a streak reset cannot reduce it.
        // Count days as integers and divide at the end to avoid floating-point drift
        // (13 * (1.0/7.0) may be just under 1.857... and Int() would floor to 1).
        var completedDayCount = 0
        var bonusWindowCount = 0
        cursor = firstDay
        while cursor <= todayStart {
            let kind = dayStates[cursor]!
            if case .completed = kind {
                completedDayCount += 1
                if bonusApplies(
                    today: cursor,
                    dayStates: dayStates,
                    windowDays: windowDays,
                    calendar: calendar
                ) {
                    bonusWindowCount += HabitConfig.perfectWindowBonusDays
                }
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        let creditDays = completedDayCount + bonusWindowCount
        let freezesEarnedLifetime = creditDays / HabitConfig.freezeEarnDaysPerFreeze
        let freezesAvailable = max(
            0, min(HabitConfig.maxFreezes, freezesEarnedLifetime - freezesSpent)
        )
        let freezeProgressDays = creditDays % HabitConfig.freezeEarnDaysPerFreeze

        // At-risk: yesterday is missed (not completed/frozen/paused), no freeze was
        // applied to it, freezes are available, and we're within the grace window.
        // Today pending is never itself at risk. The scan is bounded by both
        // `gracePeriodDays` and the first recorded day — we never invent a miss
        // before the habit had any history.
        var atRisk = false
        var mostRecentMiss: Date? = nil
        let graceStartCutoff = max(
            firstDay,
            calendar.date(byAdding: .day, value: -HabitConfig.gracePeriodDays, to: todayStart)
                ?? todayStart
        )
        cursor = yesterdayStart
        while cursor >= graceStartCutoff {
            let kind = dayStates[cursor] ?? .missed
            if kind == .missed {
                mostRecentMiss = cursor
                break
            }
            guard let prev = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }
        if let miss = mostRecentMiss {
            let graceEnd =
                calendar.date(byAdding: .day, value: HabitConfig.gracePeriodDays, to: miss) ?? miss
            atRisk = freezesAvailable > 0 && todayStart >= miss && todayStart <= graceEnd
        }

        return HabitProgressResult(
            windowCredit: windowCredit,
            windowDenominator: denominatorDays,
            windowTarget: targetPerWindow,
            strength: min(1.0, max(0.0, strength)),
            currentStreak: currentStreak,
            longestStreak: longest,
            freezesAvailable: freezesAvailable,
            freezeProgressDays: freezeProgressDays,
            atRisk: atRisk,
            missedDay: mostRecentMiss
        )
    }

    private static func maxHistoryStart(todayStart: Date, calendar: Calendar) -> Date {
        calendar.date(byAdding: .day, value: -maxHistoryDays, to: todayStart) ?? todayStart
    }

    private static func classify(
        day: Date,
        occurrence: HabitOccurrenceDTO?,
        dailyTarget: Double,
        todayStart: Date,
        pausedDays: Set<Date>
    ) -> HabitDayState.Kind {
        if pausedDays.contains(day) {
            return .paused
        }
        guard let occurrence else {
            return day == todayStart ? .pending : .missed
        }
        if occurrence.freezeUsed {
            return .frozen
        }
        if occurrence.completed || occurrence.currentAmount >= dailyTarget {
            return .completed
        }
        if occurrence.currentAmount > 0 {
            return .partial(min(1.0, occurrence.currentAmount / dailyTarget))
        }
        return day == todayStart ? .pending : .missed
    }

    /// A past day is "on track" if it is completed/frozen/paused, OR if the
    /// trailing window ending on that day has `credit >= targetPerWindow`.
    private static func isOnTrackDay(
        day: Date,
        dayStates: [Date: HabitDayState.Kind],
        windowDays: Int,
        targetPerWindow: Int,
        calendar: Calendar
    ) -> Bool {
        guard let kind = dayStates[day] else { return false }
        switch kind {
        case .completed, .frozen, .paused:
            return true
        case .pending:
            return false
        case .partial, .missed:
            break
        }
        let windowStartDay =
            calendar.date(byAdding: .day, value: -(windowDays - 1), to: day) ?? day
        var credit: Double = 0
        var cursor = windowStartDay
        while cursor <= day {
            if let k = dayStates[cursor] {
                switch k {
                case .completed: credit += 1.0
                case let .partial(c): credit += c
                case .pending, .missed, .frozen, .paused: break
                }
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return credit >= Double(targetPerWindow)
    }

    /// Perfect-window bonus: granted when the trailing window ending on `today`
    /// is fully complete. The caller is responsible for day-level granularity (we
    /// never call this twice for the same day because the walk visits each day once).
    private static func bonusApplies(
        today: Date,
        dayStates: [Date: HabitDayState.Kind],
        windowDays: Int,
        calendar: Calendar
    ) -> Bool {
        let windowStartDay =
            calendar.date(byAdding: .day, value: -(windowDays - 1), to: today) ?? today
        var completedCount = 0
        var cursor = windowStartDay
        while cursor <= today {
            if let k = dayStates[cursor], case .completed = k {
                completedCount += 1
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return completedCount >= windowDays
    }
}

// ConsistencyScorer.swift
// Recency-weighted consistency scoring for companion task/habit context.

import Foundation

/// Natural-language label for a consistency score. Never expose raw numbers to the LLM.
enum ConsistencyBand: String, Sendable, CaseIterable {
    case veryConsistentLately
    case steady
    case uneven
    case fallingOff
    case notEnoughHistory

    var descriptor: String {
        switch self {
        case .veryConsistentLately:
            return "very consistent lately"
        case .steady:
            return "fairly steady"
        case .uneven:
            return "a bit uneven"
        case .fallingOff:
            return "falling off"
        case .notEnoughHistory:
            return "just getting started"
        }
    }
}

/// Pure, testable scorer for recency-weighted completion consistency.
///
/// A single missed period multiplies the running score by the decay factor (e.g. 0.92)
/// rather than causing a dramatic drop. This is the core behavioural requirement.
struct ConsistencyScorer: Sendable {
    /// Decay factor applied to the prior score when a new period is observed.
    /// Kept in the validated range 0.90 ... 0.95.
    var decay: Double {
        get { _decay }
        set { _decay = max(0.90, min(0.95, newValue)) }
    }

    private var _decay: Double = 0.92

    /// Minimum number of periods required before a score is meaningful.
    var minPeriods: Int = 3

    init(decay: Double = 0.92, minPeriods: Int = 3) {
        self._decay = max(0.90, min(0.95, decay))
        self.minPeriods = minPeriods
    }

    /// events: one value per period in chronological order; `true` means completed.
    /// Returns `nil` when fewer than `minPeriods` periods exist.
    func score(periods: [Bool]) -> Double? {
        guard periods.count >= minPeriods else { return nil }
        return periods.dropFirst().reduce(periods[0] ? 1.0 : 0.0) { score, done in
            score * decay + (1 - decay) * (done ? 1.0 : 0.0)
        }
    }

    /// Returns the human-readable band for a score.
    func band(for score: Double?) -> ConsistencyBand {
        guard let score else { return .notEnoughHistory }
        switch score {
        case 0.8...:
            return .veryConsistentLately
        case 0.55..<0.8:
            return .steady
        case 0.35..<0.55:
            return .uneven
        default:
            return .fallingOff
        }
    }
}

// MARK: - Period builders

extension ConsistencyScorer {
    /// Build a task consistency score from the days on which the task was completed
    /// within the last 90 days.
    ///
    /// - Parameters:
    ///   - completions: completion dates for one task UUID, ascending
    ///   - now: reference date for the rolling window
    ///   - firstDueDate: optional due date for scheduled tasks; only periods from this
    ///     date forward are counted, and the window is also bounded by `now`.
    static func taskPeriods(
        completions: [Date],
        now: Date = Date(),
        firstDueDate: Date? = nil
    ) -> [Bool] {
        let calendar = Calendar.current
        let windowStart = now.addingTimeInterval(-90 * 86_400)
        let start = firstDueDate.map { max($0, windowStart) } ?? windowStart
        guard start <= now else { return [] }

        var daysWithCompletions = Set<DateComponents>()
        for date in completions where date >= start && date <= now {
            daysWithCompletions.insert(calendar.dateComponents([.year, .month, .day], from: date))
        }

        var periods: [Bool] = []
        var cursor = calendar.startOfDay(for: start)
        let end = calendar.startOfDay(for: now)
        while cursor <= end {
            let components = calendar.dateComponents([.year, .month, .day], from: cursor)
            periods.append(daysWithCompletions.contains(components))
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return periods
    }

    /// Build a habit consistency score from completed weekly periods.
    ///
    /// - Parameters:
    ///   - occurrences: completed habit occurrences, in chronological order
    ///   - weeklyFrequency: required completions per week
    ///   - now: reference date for the rolling window
    static func habitPeriods(
        occurrences: [Date],
        weeklyFrequency: Int,
        now: Date = Date()
    ) -> [Bool] {
        // Use the same Sunday-start Gregorian calendar as HabitStreakCalculator so
        // consistency periods align with streak boundaries. If the calendar used here
        // drifts from HabitStreakCalculator.streakCalendar(), habit scores will be wrong.
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 1 // Sunday

        let windowStart = now.addingTimeInterval(-13 * 7 * 86_400)
        let start = calendar.startOfDay(for: windowStart)

        var completionsByWeek: [DateComponents: Int] = [:]
        for date in occurrences where date >= start && date <= now {
            let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
            completionsByWeek[components, default: 0] += 1
        }

        var periods: [Bool] = []
        var currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: start)?.start ?? start
        let endWeekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        while currentWeekStart <= now {
            let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: currentWeekStart)
            periods.append((completionsByWeek[components] ?? 0) >= weeklyFrequency)
            guard currentWeekStart < endWeekStart,
                  let nextWeek = calendar.date(byAdding: .weekOfYear, value: 1, to: currentWeekStart)
            else { break }
            currentWeekStart = nextWeek
        }
        return periods
    }
}

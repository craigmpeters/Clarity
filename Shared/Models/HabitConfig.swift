//
//  HabitConfig.swift
//  Clarity
//
//  Created by OpenCode on 08/08/2026.
//

import Foundation

enum HabitConfig: Sendable {
    nonisolated static let periodDays = 7
    nonisolated static let maxFreezes = 3
    nonisolated static let freezeEarnIntervalDays = 7
    // Grace window: a freeze can be spent on a missed period until the end of the NEXT period.
    nonisolated static let gracePeriodDays = 7
    nonisolated static let defaultWeeklyFrequency = 7

    // Rolling-window configuration (Step B). The streak itself is still computed
    // over the trailing `windowDays`; `weeklyFrequency` is reinterpreted as the
    // target days per window.
    nonisolated static let defaultWindowDays = 7
    nonisolated static let supportedWindowDays: [Int] = [7, 14, 30]
    /// Number of completed days required to earn one freeze. Used by
    /// `HabitProgressEngine` (and the additive `reconcileFreezes`).
    nonisolated static let freezeEarnDaysPerFreeze = 7
    /// Bonus credit (in days-equivalent) granted once per window when every day
    /// in the trailing window is completed.
    nonisolated static let perfectWindowBonusDays = 1

    nonisolated static let incrementStepRange: PartialRangeFrom<Double> = 0.1...
    nonisolated static let maxIncrementStep: Double = 10000

    /// Returns the valid daily target range for a habit, accounting for the canonical
    /// storage unit. Health-linked water is stored in mL (so 1000 would be only 1 L),
    /// steps in count, exercise/mindful in minutes, and general habits in arbitrary units.
    nonisolated static func dailyTargetRange(for healthKitIdentifier: String?) -> ClosedRange<
        Double
    > {
        switch healthKitIdentifier {
        case "water":
            return 1...30000
        case "steps":
            return 1...200_000
        case "workouts", "mindful":
            return 1...1440
        default:
            return 1...10000
        }
    }

    nonisolated static func validateTarget(_ target: Double, healthKitIdentifier: String?) -> Bool {
        dailyTargetRange(for: healthKitIdentifier).contains(target)
    }

    nonisolated static func validateIncrementStep(_ step: Double) -> Bool {
        step >= incrementStepRange.lowerBound && step <= maxIncrementStep
    }

    nonisolated static func validateIncrementStep(_ step: Double, healthKitIdentifier: String?)
        -> Bool
    {
        guard validateIncrementStep(step) else { return false }
        let range = dailyTargetRange(for: healthKitIdentifier)
        return step <= range.upperBound
    }
}

enum HabitError: Error, Sendable, Equatable {
    case notFound
    case archived
    case noFreezesAvailable
    case noFreezableMiss
    case persistenceFailed(underlying: Error)
    case invalidTarget

    static func == (lhs: HabitError, rhs: HabitError) -> Bool {
        switch (lhs, rhs) {
        case (.notFound, .notFound), (.archived, .archived),
            (.noFreezesAvailable, .noFreezesAvailable), (.noFreezableMiss, .noFreezableMiss),
            (.invalidTarget, .invalidTarget):
            return true
        case (.persistenceFailed(let l), .persistenceFailed(let r)):
            return l.localizedDescription == r.localizedDescription
        default:
            return false
        }
    }
}

extension HabitError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .notFound: return "Habit not found"
        case .archived: return "Habit is archived"
        case .noFreezesAvailable: return "No freezes available"
        case .noFreezableMiss: return "No freezable miss within the grace window"
        case .persistenceFailed(let underlying): return underlying.localizedDescription
        case .invalidTarget: return "Daily target is outside the allowed range for this type"
        }
    }
}

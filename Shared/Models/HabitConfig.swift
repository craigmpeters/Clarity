//
//  HabitConfig.swift
//  Clarity
//
//  Created by OpenCode on 08/08/2026.
//

import Foundation

enum HabitConfig: Sendable {
    static nonisolated let periodDays = 7
    static nonisolated let maxFreezes = 3
    static nonisolated let freezeEarnIntervalDays = 7
    static nonisolated let gracePeriodDays = 1
    static nonisolated let dailyTargetRange: ClosedRange<Double> = 1...1000
    static nonisolated let incrementStepRange: ClosedRange<Double> = 0.1...100
    static nonisolated let defaultWeeklyFrequency = 7
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
        case (.notFound, .notFound), (.archived, .archived), (.noFreezesAvailable, .noFreezesAvailable), (.noFreezableMiss, .noFreezableMiss), (.invalidTarget, .invalidTarget):
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
        case .invalidTarget: return "Daily target must be between 1 and 1000"
        }
    }
}

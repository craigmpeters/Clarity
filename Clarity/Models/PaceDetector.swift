// PaceDetector.swift
// Ad-hoc pace detection for companion task context.

import Foundation

/// Summary of a task's observed completion pace.
struct PaceSummary: Sendable, Equatable {
    var medianIntervalDays: Double
    var coefficientOfVariation: Double
    var daysSinceLastCompletion: Double
    var isOverdueRelativeToPace: Bool
    var regularity: Regularity

    enum Regularity: String, Sendable {
        case regular
        case somewhatRegular
        case erratic
    }
}

/// Pure, testable pace detector for completion intervals.
///
/// Grouping is performed by the caller: usually one UUID per call, with a category-cluster
/// fallback when a UUID has too few completions to establish a stable pace.
struct PaceDetector: Sendable {
    /// completions: completion dates for one logical group (UUID or category cluster), ascending.
    /// Needs at least 3 intervals (4 completions) to return a non-nil summary.
    func pace(completions: [Date], now: Date = Date()) -> PaceSummary? {
        let intervals = zip(completions, completions.dropFirst())
            .map { $1.timeIntervalSince($0) / 86_400 }
        guard intervals.count >= 3 else { return nil }

        let sorted = intervals.sorted()
        let median: Double
        if sorted.count % 2 == 1 {
            median = sorted[sorted.count / 2]
        } else {
            median = (sorted[sorted.count / 2 - 1] + sorted[sorted.count / 2]) / 2
        }

        let mean = intervals.reduce(0, +) / Double(intervals.count)
        let variance = intervals.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(intervals.count)
        let cv = mean > 0 ? variance.squareRoot() / mean : 0
        let daysSince = now.timeIntervalSince(completions.last ?? now) / 86_400
        return PaceSummary(
            medianIntervalDays: median,
            coefficientOfVariation: cv,
            daysSinceLastCompletion: daysSince,
            isOverdueRelativeToPace: daysSince > median * (1 + cv),
            regularity: cv < 0.35 ? .regular : cv < 0.7 ? .somewhatRegular : .erratic
        )
    }
}

// MARK: - Human-readable formatting helpers

extension PaceSummary {
    /// A natural-language phrase describing the pace, e.g. "usually every ~5 days".
    var intervalPhrase: String {
        let rounded = Int(round(medianIntervalDays))
        let unit = rounded == 1 ? "day" : "days"
        return "usually every ~\(rounded) \(unit)"
    }

    /// A phrase describing the overdue state relative to the user's own pace, e.g. "it's been 9".
    var overduePhrase: String {
        let days = Int(round(daysSinceLastCompletion))
        return "it's been \(days)"
    }
}

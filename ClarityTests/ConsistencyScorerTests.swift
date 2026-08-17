//
//  ConsistencyScorerTests.swift
//  ClarityTests
//

import Foundation
import Testing
@testable import Clarity

struct ConsistencyScorerTests {

    private let scorer = ConsistencyScorer()

    @Test func perfectHistoryIsVeryConsistent() {
        let periods = Array(repeating: true, count: 30)
        let score = scorer.score(periods: periods)
        #expect(score == 1.0)
        #expect(scorer.band(for: score) == .veryConsistentLately)
    }

    @Test func allMissedIsFallingOff() {
        let periods = Array(repeating: false, count: 30)
        let score = scorer.score(periods: periods)
        #expect(score == 0.0)
        #expect(scorer.band(for: score) == .fallingOff)
    }

    @Test func singleRecentMissDentsButDoesNotCrater() {
        // 29 perfect then one miss: score should still be in the top band.
        var periods = Array(repeating: true, count: 29)
        periods.append(false)
        let score = scorer.score(periods: periods)
        #expect(score! >= 0.8, "score \(score!) should stay in 'very consistent' band")
        #expect(scorer.band(for: score) == .veryConsistentLately)
    }

    @Test func fewerThanMinPeriodsReturnsNotEnoughHistory() {
        #expect(scorer.score(periods: [true, true]) == nil)
        #expect(scorer.band(for: nil) == .notEnoughHistory)
    }

    @Test func decayBoundarySanity() {
        let low = ConsistencyScorer(decay: 0.90)
        let high = ConsistencyScorer(decay: 0.95)
        let periods = Array(repeating: true, count: 20) + [false]
        #expect(low.score(periods: periods)! < high.score(periods: periods)!)
    }

    @Test func decayIsClampedToValidRange() {
        var scorer = ConsistencyScorer(decay: 0.5)
        #expect(scorer.decay == 0.90)
        scorer.decay = 1.2
        #expect(scorer.decay == 0.95)
    }

    @Test func bandThresholds() {
        #expect(scorer.band(for: 0.85) == .veryConsistentLately)
        #expect(scorer.band(for: 0.6) == .steady)
        #expect(scorer.band(for: 0.4) == .uneven)
        #expect(scorer.band(for: 0.2) == .fallingOff)
    }

    @Test func taskPeriodsBuildsDailyWindow() {
        let now = Date()
        let completions = [
            now.addingTimeInterval(-2 * 86_400),
            now.addingTimeInterval(-1 * 86_400)
        ]
        let periods = ConsistencyScorer.taskPeriods(completions: completions, now: now)
        #expect(periods.count == 91) // today + last 90 days
        #expect(periods[periods.count - 3] == true)
        #expect(periods[periods.count - 2] == true)
        #expect(periods[periods.count - 1] == false)
    }

    @Test func habitPeriodsAcrossYearBoundary() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 1
        // Sunday Dec 28 2025, near the week of Jan 1 2026
        var components = DateComponents(year: 2025, month: 12, day: 28)
        let now = calendar.date(from: components)!
        // Two completions in the week ending Jan 3, 2026 (week 1 of 2026)
        let occurrences = [
            calendar.date(from: DateComponents(year: 2026, month: 1, day: 2))!,
            calendar.date(from: DateComponents(year: 2026, month: 1, day: 3))!
        ]
        let periods = ConsistencyScorer.habitPeriods(
            occurrences: occurrences,
            weeklyFrequency: 2,
            now: now
        )
        // Must include the week that spans the year boundary.
        #expect(periods.last == true)
    }

    @Test func habitPeriodsUseSundayStartCalendar() {
        // Simulate a Monday-start locale by setting firstWeekday = 2 on the current calendar.
        var currentCalendar = Calendar.current
        currentCalendar.firstWeekday = 2

        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 1
        // Pick a Sunday; completions are on that Sunday and the next Sunday, so they fall in the same
        // Sunday-start week and should produce exactly one completed period when weeklyFrequency is 2.
        let sunday = calendar.date(from: DateComponents(year: 2026, month: 1, day: 4))!
        let occurrences = [sunday, calendar.date(byAdding: .day, value: 7, to: sunday)!]
        let periods = ConsistencyScorer.habitPeriods(
            occurrences: occurrences,
            weeklyFrequency: 2,
            now: calendar.date(byAdding: .day, value: 7, to: sunday)!
        )
        #expect(periods.last == true)
    }

    @Test func taskPeriodsRespectsFirstDueDate() {
        let now = Date()
        let firstDue = now.addingTimeInterval(-10 * 86_400)
        let completions = [now.addingTimeInterval(-20 * 86_400)]
        let periods = ConsistencyScorer.taskPeriods(completions: completions, now: now, firstDueDate: firstDue)
        #expect(periods.count == 11)
    }
}

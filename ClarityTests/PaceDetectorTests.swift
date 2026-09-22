//
//  PaceDetectorTests.swift
//  ClarityTests
//

import Foundation
import Testing
@testable import Clarity

struct PaceDetectorTests {

    private let detector = PaceDetector()
    private let secondsPerDay: TimeInterval = 86_400

    @Test func knownIntervalsProduceCorrectMedian() {
        let now = Date()
        let completions = (0..<5).map { now.addingTimeInterval(TimeInterval($0) * 5 * secondsPerDay) }
        let summary = detector.pace(completions: completions, now: now.addingTimeInterval(5 * secondsPerDay))!
        #expect(summary.medianIntervalDays == 5.0)
    }

    @Test func regularPaceHasLowCV() {
        let now = Date()
        let completions = (0..<5).map { now.addingTimeInterval(TimeInterval($0) * 5 * secondsPerDay) }
        let summary = detector.pace(completions: completions, now: now.addingTimeInterval(5 * secondsPerDay))!
        #expect(summary.regularity == .regular)
        #expect(summary.coefficientOfVariation < 0.35)
    }

    @Test func erraticPaceHasHighCV() {
        let now = Date()
        let completions = [
            now,
            now.addingTimeInterval(2 * secondsPerDay),
            now.addingTimeInterval(10 * secondsPerDay),
            now.addingTimeInterval(12 * secondsPerDay)
        ]
        let summary = detector.pace(completions: completions, now: now.addingTimeInterval(12 * secondsPerDay))!
        #expect(summary.regularity == .erratic)
    }

    @Test func isOverdueTrueWhenBeyondMedianAndCV() {
        let now = Date()
        let completions = [
            now.addingTimeInterval(-20 * secondsPerDay),
            now.addingTimeInterval(-10 * secondsPerDay),
            now.addingTimeInterval(-5 * secondsPerDay),
            now
        ]
        let summary = detector.pace(completions: completions, now: now.addingTimeInterval(8 * secondsPerDay))!
        #expect(summary.isOverdueRelativeToPace == true)
    }

    @Test func isOverdueFalseWithinGraceWindow() {
        let now = Date()
        let completions = [
            now.addingTimeInterval(-10 * secondsPerDay),
            now.addingTimeInterval(-5 * secondsPerDay),
            now.addingTimeInterval(-2 * secondsPerDay),
            now
        ]
        let summary = detector.pace(completions: completions, now: now.addingTimeInterval(2 * secondsPerDay))!
        #expect(summary.isOverdueRelativeToPace == false)
    }

    @Test func fewerThanFourCompletionsReturnsNil() {
        let now = Date()
        let completions = [
            now.addingTimeInterval(-5 * secondsPerDay),
            now.addingTimeInterval(-2 * secondsPerDay),
            now
        ]
        #expect(detector.pace(completions: completions, now: now) == nil)
    }

    @Test func categoryClusterGroupsSparseUUIDs() {
        let now = Date()
        // Pool completions from multiple names into a single category cluster.
        let cluster = [
            now.addingTimeInterval(-20 * secondsPerDay),
            now.addingTimeInterval(-10 * secondsPerDay),
            now.addingTimeInterval(-5 * secondsPerDay),
            now
        ]
        let summary = detector.pace(completions: cluster, now: now.addingTimeInterval(5 * secondsPerDay))!
        // Intervals: 10, 5, 5 → sorted [5, 5, 10] → median 5
        #expect(summary.medianIntervalDays == 5.0)
    }

    @Test func intervalPhraseRounding() {
        let summary = PaceSummary(
            medianIntervalDays: 5.4,
            coefficientOfVariation: 0.2,
            daysSinceLastCompletion: 9.2,
            isOverdueRelativeToPace: true,
            regularity: .somewhatRegular
        )
        #expect(summary.intervalPhrase == "usually every ~5 days")
        #expect(summary.overduePhrase == "it's been 9")
    }
}

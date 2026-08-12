//
//  HabitConfigTests.swift
//  ClarityTests
//
//  Created by OpenCode on 09/08/2026.
//

import Foundation
import Testing
@testable import Clarity

struct HabitConfigTests {

    @Test func dailyTargetRangeForWater() {
        let range = HabitConfig.dailyTargetRange(for: "water")
        #expect(range == 1.0...30_000.0)
    }

    @Test func dailyTargetRangeForSteps() {
        let range = HabitConfig.dailyTargetRange(for: "steps")
        #expect(range == 1.0...200_000.0)
    }

    @Test func dailyTargetRangeForWorkoutsAndMindful() {
        let workouts = HabitConfig.dailyTargetRange(for: "workouts")
        let mindful = HabitConfig.dailyTargetRange(for: "mindful")
        #expect(workouts == 1.0...1_440.0)
        #expect(mindful == 1.0...1_440.0)
    }

    @Test func dailyTargetRangeForUnknownAndNilIdentifier() {
        let unknown = HabitConfig.dailyTargetRange(for: "unknown")
        let nilIdentifier = HabitConfig.dailyTargetRange(for: nil)
        #expect(unknown == 1.0...10_000.0)
        #expect(nilIdentifier == 1.0...10_000.0)
    }

    @Test func validateTargetAtBoundaries() {
        #expect(HabitConfig.validateTarget(1.0, healthKitIdentifier: nil) == true)
        #expect(HabitConfig.validateTarget(10_000.0, healthKitIdentifier: nil) == true)
    }

    @Test func validateTargetRejectsZeroAndNegativeAndNaN() {
        #expect(HabitConfig.validateTarget(0.0, healthKitIdentifier: nil) == false)
        #expect(HabitConfig.validateTarget(-1.0, healthKitIdentifier: nil) == false)
        // PINNED: ClosedRange.contains(Double.nan) is false, so NaN is rejected.
        #expect(HabitConfig.validateTarget(Double.nan, healthKitIdentifier: nil) == false)
    }

    @Test func validateTargetRespectsIdentifierSpecificUpperBound() {
        #expect(HabitConfig.validateTarget(30_000.0, healthKitIdentifier: "water") == true)
        #expect(HabitConfig.validateTarget(30_001.0, healthKitIdentifier: "water") == false)
        #expect(HabitConfig.validateTarget(200_000.0, healthKitIdentifier: "steps") == true)
        #expect(HabitConfig.validateTarget(200_001.0, healthKitIdentifier: "steps") == false)
        #expect(HabitConfig.validateTarget(1_440.0, healthKitIdentifier: "workouts") == true)
        #expect(HabitConfig.validateTarget(1_441.0, healthKitIdentifier: "workouts") == false)
    }

    @Test func validateIncrementStepAtBoundaries() {
        #expect(HabitConfig.validateIncrementStep(0.1) == true)
        #expect(HabitConfig.validateIncrementStep(10_000.0) == true)
    }

    @Test func validateIncrementStepRejectsOutOfRange() {
        #expect(HabitConfig.validateIncrementStep(0.0) == false)
        #expect(HabitConfig.validateIncrementStep(0.05) == false)
        #expect(HabitConfig.validateIncrementStep(10_001.0) == false)
    }

    @Test func validateIncrementStepWithIdentifierCappedAtGlobalMax() {
        // The identifier-specific overload first runs the global validator, so the
        // effective upper bound is min(HabitConfig.maxIncrementStep, range.upperBound).
        #expect(HabitConfig.validateIncrementStep(10_000.0, healthKitIdentifier: "water") == true)
        #expect(HabitConfig.validateIncrementStep(10_000.0, healthKitIdentifier: "steps") == true)
        // PINNED: possible bug — a 30_000 step for water is rejected by the global 10_000 cap
        // even though the water target range allows targets up to 30_000.
        #expect(HabitConfig.validateIncrementStep(30_000.0, healthKitIdentifier: "water") == false)
        #expect(HabitConfig.validateIncrementStep(10_001.0, healthKitIdentifier: nil) == false)
    }

    @Test func validateIncrementStepWithIdentifierStillEnforcesMinimum() {
        #expect(HabitConfig.validateIncrementStep(0.05, healthKitIdentifier: "water") == false)
    }

    @Test func constantsAreAsExpected() {
        #expect(HabitConfig.periodDays == 7)
        #expect(HabitConfig.maxFreezes == 3)
        #expect(HabitConfig.freezeEarnIntervalDays == 7)
        #expect(HabitConfig.gracePeriodDays == 7)
        #expect(HabitConfig.defaultWeeklyFrequency == 7)
        #expect(HabitConfig.maxIncrementStep == 10_000)
    }
}

struct HabitErrorTests {

    @Test func simpleCasesAreEqual() {
        #expect(HabitError.notFound == HabitError.notFound)
        #expect(HabitError.archived == HabitError.archived)
        #expect(HabitError.noFreezesAvailable == HabitError.noFreezesAvailable)
        #expect(HabitError.noFreezableMiss == HabitError.noFreezableMiss)
        #expect(HabitError.invalidTarget == HabitError.invalidTarget)
    }

    @Test func differentSimpleCasesAreNotEqual() {
        #expect(HabitError.notFound != HabitError.archived)
        #expect(HabitError.noFreezesAvailable != HabitError.invalidTarget)
    }

    @Test func persistenceFailedEqualityUsesLocalizedDescription() {
        let left = HabitError.persistenceFailed(underlying: NSError(domain: "a", code: 1, userInfo: [NSLocalizedDescriptionKey: "boom"]))
        let right = HabitError.persistenceFailed(underlying: NSError(domain: "b", code: 2, userInfo: [NSLocalizedDescriptionKey: "boom"]))
        #expect(left == right)
    }

    @Test func persistenceFailedInequalityWhenDescriptionsDiffer() {
        let left = HabitError.persistenceFailed(underlying: NSError(domain: "a", code: 1, userInfo: [NSLocalizedDescriptionKey: "boom"]))
        let right = HabitError.persistenceFailed(underlying: NSError(domain: "a", code: 1, userInfo: [NSLocalizedDescriptionKey: "different"]))
        #expect(left != right)
    }

    @Test func persistenceFailedNotEqualToSimpleCases() {
        let error = HabitError.persistenceFailed(underlying: NSError(domain: "a", code: 1))
        #expect(error != HabitError.notFound)
        #expect(HabitError.notFound != error)
    }

    @Test func errorDescriptionIsNonNilForAllCases() {
        let errors: [HabitError] = [
            .notFound,
            .archived,
            .noFreezesAvailable,
            .noFreezableMiss,
            .persistenceFailed(underlying: NSError(domain: "a", code: 1)),
            .invalidTarget
        ]
        for error in errors {
            #expect(error.errorDescription != nil)
            #expect(error.errorDescription?.isEmpty == false)
        }
    }

    @Test func persistenceFailedDescriptionMirrorsUnderlying() {
        let underlying = NSError(domain: "test", code: 42, userInfo: [NSLocalizedDescriptionKey: "custom message"])
        let error = HabitError.persistenceFailed(underlying: underlying)
        #expect(error.errorDescription == "custom message")
    }
}

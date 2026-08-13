//
//  HabitFormStateTests.swift
//  ClarityTests
//
//  Unit tests for the habit creation/editing form state.
//

import Foundation
import Testing
@testable import Clarity

@MainActor
struct HabitFormStateTests {

    private func state() -> HabitFormState {
        HabitFormState()
    }

    private func healthState(identifier: String) -> HabitFormState {
        let s = HabitFormState()
        s.habitType = .health
        s.healthKitIdentifier = identifier
        s.name = "Health Habit"
        return s
    }

    @Test func defaultsAreInvalidWithoutName() {
        let s = state()
        #expect(s.name.isEmpty)
        #expect(s.isValid == false)
    }

    @Test func validWhenNameAndDefaultTargetsPresent() {
        let s = state()
        s.name = "Read"
        s.incrementStep = 1
        s.incrementCount = 1
        #expect(s.isValid == true)
        #expect(s.isTargetOutOfRange == false)
        #expect(s.isIncrementOutOfRange == false)
    }

    @Test func dailyTargetEqualsStepTimesCount() {
        let s = state()
        s.incrementStep = 2.5
        s.incrementCount = 4
        #expect(s.dailyTarget == 10.0)
    }

    @Test func targetOutOfRangeWhenExceedsHealthKitCap() {
        let s = healthState(identifier: "water")
        s.incrementStep = 10_000
        s.incrementCount = 10
        #expect(s.dailyTarget == 100_000)
        #expect(s.isTargetOutOfRange == true)
        #expect(s.isValid == false)
    }

    @Test func incrementOutOfRangeWhenBelowMinimum() {
        let s = state()
        s.name = "Read"
        s.incrementStep = 0.05
        s.incrementCount = 1
        #expect(s.isIncrementOutOfRange == true)
        #expect(s.isValid == false)
    }

    @Test func loadExistingHabitInvertsTargetMath() {
        let s = state()
        let existing = HabitDTO(
            name: "Existing",
            dailyTarget: 30,
            incrementStep: 5
        )
        s.load(habit: existing)
        #expect(s.name == "Existing")
        #expect(s.incrementStep == 5)
        #expect(s.incrementCount == 6)
        #expect(s.dailyTarget == 30)
    }

    @Test func loadClampsCountToOneWhenStepIsZero() {
        let s = state()
        let existing = HabitDTO(
            name: "Zero Step",
            dailyTarget: 10,
            incrementStep: 0
        )
        s.load(habit: existing)
        #expect(s.incrementCount >= 1)
    }

    @Test func applyHealthKitDefaultsSetsWaterStep() {
        let s = healthState(identifier: "water")
        s.applyHealthKitDefaultsIfNeeded()
        #expect(s.incrementStep == 250)
    }

    @Test func applyHealthKitDefaultsSetsStepsStep() {
        let s = healthState(identifier: "steps")
        s.applyHealthKitDefaultsIfNeeded()
        #expect(s.incrementStep == 500)
    }

    @Test func applyHealthKitDefaultsSetsWorkoutsAndMindfulStep() {
        let s = healthState(identifier: "workouts")
        s.applyHealthKitDefaultsIfNeeded()
        #expect(s.incrementStep == 5)

        let mindful = healthState(identifier: "mindful")
        mindful.applyHealthKitDefaultsIfNeeded()
        #expect(mindful.incrementStep == 5)
    }

    @Test func applyHealthKitDefaultsRespectsUserEditedStep() {
        let s = healthState(identifier: "water")
        s.didEditIncrement = true
        s.incrementStep = 123
        s.applyHealthKitDefaultsIfNeeded()
        #expect(s.incrementStep == 123)
    }

    @Test func makeDTOClampsTargetAndStep() {
        let s = state()
        s.name = "Clamp Test"
        s.incrementStep = 50_000
        s.incrementCount = 1
        let dto = s.makeDTO(existing: nil)
        #expect(dto.dailyTarget == 10_000)
        #expect(dto.incrementStep == 10_000)
    }

    @Test func makeDTONilsUnitLabelForHealthLinkedHabit() {
        let s = healthState(identifier: "water")
        s.name = "Water"
        s.unitLabel = "mL"
        let dto = s.makeDTO(existing: nil)
        #expect(dto.unitLabel == nil)
    }

    @Test func makeDTOPreservesOverriddenHealthUnit() {
        let s = healthState(identifier: "water")
        s.name = "Water"
        s.unitLabel = "litres"
        let dto = s.makeDTO(existing: nil)
        #expect(dto.unitLabel == "litres")
    }

    @Test func makeDTOPreservesNonHealthUnitLabel() {
        let s = state()
        s.name = "Read"
        s.unitLabel = "pages"
        let dto = s.makeDTO(existing: nil)
        #expect(dto.unitLabel == "pages")
    }

    @Test func makeDTOInheritsExistingUUID() {
        let existing = HabitDTO(name: "Existing", dailyTarget: 1)
        let s = state()
        s.name = "Renamed"
        let dto = s.makeDTO(existing: existing)
        #expect(dto.uuid == existing.uuid)
    }
}

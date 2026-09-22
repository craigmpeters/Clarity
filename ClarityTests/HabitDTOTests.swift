//
//  HabitDTOTests.swift
//  ClarityTests
//
//  Created by OpenCode on 09/08/2026.
//

import Foundation
import Testing
@testable import Clarity

struct HabitDTOTests {

    private func habitDTO(
        dailyTarget: Double = 10.0,
        currentAmount: Double = 0.0,
        unitLabel: String? = nil,
        healthKitIdentifier: String? = nil
    ) -> HabitDTO {
        var dto = HabitDTO(
            name: "Test Habit",
            unitLabel: unitLabel,
            dailyTarget: dailyTarget,
            healthKitIdentifier: healthKitIdentifier
        )
        dto.currentAmount = currentAmount
        return dto
    }

    @Test func isTargetReachedWhenAmountEqualsTarget() {
        let habit = habitDTO(dailyTarget: 10.0, currentAmount: 10.0)
        #expect(habit.isTargetReached == true)
    }

    @Test func isTargetReachedWhenAmountBelowTarget() {
        let habit = habitDTO(dailyTarget: 10.0, currentAmount: 9.9)
        #expect(habit.isTargetReached == false)
    }

    @Test func progressFractionAtTarget() {
        let habit = habitDTO(dailyTarget: 10.0, currentAmount: 10.0)
        #expect(habit.progressFraction == 1.0)
    }

    @Test func progressFractionOverTargetIsCappedAtOne() {
        let habit = habitDTO(dailyTarget: 10.0, currentAmount: 20.0)
        #expect(habit.progressFraction == 1.0)
    }

    @Test func progressFractionZeroTargetIsCappedAtOne() {
        // With dailyTarget == 0, the divisor is clamped to 1 and the result is capped at 1.0.
        let habit = habitDTO(dailyTarget: 0.0, currentAmount: 5.0)
        #expect(habit.progressFraction == 1.0)
    }

    @Test func progressFractionNegativeAmount() {
        // PINNED: progressFraction is not floored at 0 when currentAmount is negative.
        let habit = habitDTO(dailyTarget: 10.0, currentAmount: -5.0)
        #expect(habit.progressFraction == -0.5)
    }

    @Test func roundTripCodable() throws {
        let original = habitDTO(dailyTarget: 50.0, currentAmount: 25.0, unitLabel: "pages")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(HabitDTO.self, from: data)
        #expect(decoded.uuid == original.uuid)
        #expect(decoded.name == original.name)
        #expect(decoded.dailyTarget == original.dailyTarget)
        #expect(decoded.unitLabel == original.unitLabel)
    }

    @Test func decodeWithMissingKeysUsesDefaults() throws {
        let json = """
        {
            "uuid": "550e8400-e29b-41d4-a716-446655440000",
            "name": "Minimal"
        }
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(HabitDTO.self, from: json)
        #expect(decoded.name == "Minimal")
        #expect(decoded.dailyTarget == 1.0)
        #expect(decoded.incrementStep == 1.0)
        #expect(decoded.weeklyFrequency == 7)
        #expect(decoded.streakFreezes == 0)
        #expect(decoded.freezesSpent == 0)
        #expect(decoded.isArchived == false)
        #expect(decoded.categories.isEmpty)
    }

    @Test func periodDescriptionUsesUnitLabel() {
        let habit = habitDTO(dailyTarget: 10.0, currentAmount: 5.0, unitLabel: "pages")
        #expect(habit.periodDescription.contains("pages"))
    }

    @Test func periodDescriptionWithHealthIdentifierFallsBackToHKUnit() {
        let habit = habitDTO(dailyTarget: 10.0, currentAmount: 5.0, healthKitIdentifier: "steps")
        #expect(habit.periodDescription.contains("steps"))
    }
}

struct HabitOccurrenceDTOTests {

    private let habitUUID = UUID()

    private func occurrenceDTO() -> HabitOccurrenceDTO {
        HabitOccurrenceDTO(
            uuid: UUID(),
            habitUUID: habitUUID,
            periodStart: Date(),
            currentAmount: 5.0,
            completed: true
        )
    }

    @Test func roundTripCodable() throws {
        let original = occurrenceDTO()
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(HabitOccurrenceDTO.self, from: data)
        #expect(decoded.uuid == original.uuid)
        #expect(decoded.habitUUID == original.habitUUID)
        #expect(decoded.currentAmount == original.currentAmount)
        #expect(decoded.completed == original.completed)
    }

    @Test func decodeWithMissingKeysUsesDefaults() throws {
        let json = "{}".data(using: .utf8)!
        let decoded = try JSONDecoder().decode(HabitOccurrenceDTO.self, from: json)
        #expect(decoded.currentAmount == 0.0)
        #expect(decoded.completed == false)
        #expect(decoded.freezeUsed == false)
    }
}

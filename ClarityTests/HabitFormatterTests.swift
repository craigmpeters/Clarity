//
//  HabitFormatterTests.swift
//  ClarityTests
//
//  Created by OpenCode on 09/08/2026.
//

import Foundation
import Testing
@testable import Clarity

struct HabitFormatterTests {

    @Test func formattedRoundsAndTrimsFractions() {
        #expect(HabitFormatter.formatted(1.0) == "1")
        #expect(HabitFormatter.formatted(1.234) == "1.23")
        #expect(HabitFormatter.formatted(0.0) == "0")
    }

    @Test func healthKitUnitStringForWaterIsVolumeUnit() {
        let symbol = HabitFormatter.healthKitUnitString(for: "water")
        let validSymbols = ["mL", "ml", "fl oz", "fl. oz.", "fl oz US", "oz fl"]
        #expect(validSymbols.contains(where: { symbol.contains($0) }) == true)
    }

    @Test func healthKitUnitStringForSteps() {
        #expect(HabitFormatter.healthKitUnitString(for: "steps").contains("steps"))
    }

    @Test func healthKitUnitStringForWorkoutsAndMindful() {
        #expect(HabitFormatter.healthKitUnitString(for: "workouts").contains("min"))
        #expect(HabitFormatter.healthKitUnitString(for: "mindful").contains("min"))
    }

    @Test func healthKitUnitStringForUnknownIdentifier() {
        #expect(HabitFormatter.healthKitUnitString(for: "unknown").contains("count"))
    }

    @Test func formattedHealthKitMeasurementForSteps() {
        #expect(HabitFormatter.formattedHealthKitMeasurement(value: 1000.0, identifier: "steps").contains("steps"))
    }

    @Test func formattedHealthKitMeasurementForWorkoutsAndMindful() {
        #expect(HabitFormatter.formattedHealthKitMeasurement(value: 30.0, identifier: "workouts").contains("min"))
        #expect(HabitFormatter.formattedHealthKitMeasurement(value: 15.0, identifier: "mindful").contains("min"))
    }

    @Test func formattedHealthKitMeasurementForWaterIsVolume() {
        let result = HabitFormatter.formattedHealthKitMeasurement(value: 250.0, identifier: "water")
        // The output depends on the host locale's measurement system (e.g., "0.25 l" or "8.45 fl oz").
        // It must not be a bare number and must include a unit character.
        #expect(result != HabitFormatter.formatted(250.0))
        #expect(result.contains { !$0.isNumber && !$0.isWhitespace && $0 != "." && $0 != "," })
    }

    @Test func formattedHealthKitMeasurementForUnknownIdentifierReturnsBareNumber() {
        let result = HabitFormatter.formattedHealthKitMeasurement(value: 42.0, identifier: "unknown")
        #expect(result == HabitFormatter.formatted(42.0))
    }

    @Test func progressDescriptionWithUnit() {
        let result = HabitFormatter.progressDescription(amount: 500.0, target: 1000.0, unit: "glasses")
        #expect(result == "500 / 1,000 glasses" || result == "500 / 1000 glasses")
    }

    @Test func progressDescriptionWithNilUnitAndHealthIdentifierUsesHKFormatting() {
        let result = HabitFormatter.progressDescription(amount: 30.0, target: 60.0, unit: nil, healthKitIdentifier: "workouts")
        #expect(result.contains("min"))
    }

    @Test func progressDescriptionUnitTakesPrecedenceOverHealthIdentifier() {
        // PINNED: when both unit and healthKitIdentifier are supplied, the explicit unit wins.
        let result = HabitFormatter.progressDescription(amount: 30.0, target: 60.0, unit: "glasses", healthKitIdentifier: "workouts")
        #expect(result.contains("glasses"))
        #expect(result.contains("min") == false)
    }
}

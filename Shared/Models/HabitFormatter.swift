//
//  HabitFormatter.swift
//  Clarity
//
//  Created by OpenCode on 08/08/2026.
//

import Foundation

enum HabitFormatter {
    private static func makeNumberFormatter() -> NumberFormatter {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 2
        f.minimumFractionDigits = 0
        f.locale = Locale.current
        return f
    }

    private static func makeMeasurementFormatter() -> MeasurementFormatter {
        let f = MeasurementFormatter()
        f.locale = Locale.current
        f.unitStyle = .short
        return f
    }

    static func formatted(_ value: Double) -> String {
        makeNumberFormatter().string(from: NSNumber(value: value)) ?? "\(value)"
    }

    /// Locale-natural unit symbol for a HealthKit-linked habit identifier.
    static func healthKitUnitString(for identifier: String) -> String {
        makeMeasurementFormatter().string(from: healthKitUnit(for: identifier))
    }

    /// Locale-natural unit for a HealthKit identifier. The unit type is selected from the
    /// user's locale measurement system; the symbol itself comes from `MeasurementFormatter`.
    static func healthKitUnit(for identifier: String) -> Unit {
        switch identifier {
        case "water":
            return preferredWaterUnit
        case "steps":
            // Count units are not locale-dependent; use a plain dimensionless unit.
            return Unit(symbol: "steps")
        case "workouts", "mindful":
            return UnitDuration.minutes
        default:
            return Unit(symbol: "count")
        }
    }

    private static var preferredWaterUnit: UnitVolume {
        let usMeasurementSystem: Bool = {
            if #available(iOS 16.0, watchOS 9.0, *) {
                return Locale.current.measurementSystem == .us
            } else {
                return !Locale.current.usesMetricSystem
            }
        }()
        return usMeasurementSystem ? UnitVolume.fluidOunces : UnitVolume.milliliters
    }

    /// Converts a canonical value (in the HealthKit base unit) to a locale-natural measurement
    /// and formats it as a value + unit string. Non-water identifiers are not converted.
    static func formattedHealthKitMeasurement(value: Double, identifier: String) -> String {
        switch identifier {
        case "water":
            let measurement = Measurement(value: value, unit: UnitVolume.milliliters).converted(to: preferredWaterUnit)
            return makeMeasurementFormatter().string(from: measurement)
        case "steps":
            return "\(formatted(value)) steps"
        case "workouts", "mindful":
            return "\(formatted(value)) \(makeMeasurementFormatter().string(from: UnitDuration.minutes))"
        default:
            return formatted(value)
        }
    }

    static func progressDescription(amount: Double, target: Double, unit: String?) -> String {
        let unitSuffix = unit.map { " \($0)" } ?? ""
        return "\(formatted(amount)) / \(formatted(target))\(unitSuffix)"
    }

    static func progressDescription(amount: Double, target: Double, unit: String?, healthKitIdentifier: String?) -> String {
        if let identifier = healthKitIdentifier, unit == nil {
            return "\(formattedHealthKitMeasurement(value: amount, identifier: identifier)) / \(formattedHealthKitMeasurement(value: target, identifier: identifier))"
        }
        return progressDescription(amount: amount, target: target, unit: unit)
    }
}

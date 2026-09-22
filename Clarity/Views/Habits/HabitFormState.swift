import SwiftUI
import SwiftData
import Combine

@MainActor
@Observable
final class HabitFormState {
    enum HabitType: String, CaseIterable, Identifiable {
        case health = "health"
        case nonHealth = "non-health"

        var id: String { rawValue }

        var localizedTitle: String {
            switch self {
            case .health: return "Health"
            case .nonHealth: return "General"
            }
        }

        var localizedIcon: String {
            switch self {
            case .health: return "heart.fill"
            case .nonHealth: return "star.fill"
            }
        }
    }

    struct HealthKitTypeOption: Identifiable, Hashable, Sendable {
        let id: String // the healthKitIdentifier
        let title: String
        let icon: String

        static let all: [HealthKitTypeOption] = [
            HealthKitTypeOption(id: "water", title: "Water", icon: "drop.fill"),
            HealthKitTypeOption(id: "steps", title: "Steps", icon: "figure.walk"),
            HealthKitTypeOption(id: "workouts", title: "Exercise Minutes", icon: "flame.fill"),
            HealthKitTypeOption(id: "mindful", title: "Mindful Minutes", icon: "brain.head.profile")
        ]
    }

    var habitType: HabitType = .nonHealth
    var name: String = ""
    var unitLabel: String = ""
    var incrementStep: Double = 1
    var incrementCount: Int = 1
    var weeklyFrequency: Int = 7
    var selectedCategories: [CategoryDTO] = []
    var healthKitIdentifier: String? = nil

    var didEditUnit = false
    var didEditIncrement = false
    var didEditCount = false

    var isValid: Bool {
        let target = dailyTarget
        let identifier = healthKitIdentifier
        return !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && HabitConfig.validateIncrementStep(incrementStep, healthKitIdentifier: identifier)
            && HabitConfig.validateTarget(target, healthKitIdentifier: identifier)
            && incrementCount > 0
    }

    var isTargetOutOfRange: Bool {
        !HabitConfig.validateTarget(dailyTarget, healthKitIdentifier: healthKitIdentifier)
    }

    var isIncrementOutOfRange: Bool {
        !HabitConfig.validateIncrementStep(incrementStep, healthKitIdentifier: healthKitIdentifier)
    }

    var healthKitOptions: [String] {
        HealthKitTypeOption.all.map(\.id)
    }

    var healthKitTypeOptions: [HealthKitTypeOption] {
        HealthKitTypeOption.all
    }

    var selectedHealthKitTypeOption: HealthKitTypeOption? {
        guard let identifier = healthKitIdentifier else { return nil }
        return HealthKitTypeOption.all.first { $0.id == identifier }
    }

    var localeNaturalUnit: String? {
        guard let identifier = healthKitIdentifier else { return nil }
        return HabitFormatter.healthKitUnitString(for: identifier)
    }

    var displayUnit: String {
        if !unitLabel.isEmpty { return unitLabel }
        return localeNaturalUnit ?? ""
    }

    var dailyTarget: Double {
        incrementStep * Double(incrementCount)
    }

    var formattedTotal: String {
        if let identifier = healthKitIdentifier {
            return HabitFormatter.formattedHealthKitMeasurement(value: dailyTarget, identifier: identifier)
        }
        if !unitLabel.isEmpty {
            return "\(HabitFormatter.formatted(dailyTarget)) \(unitLabel)"
        }
        return HabitFormatter.formatted(dailyTarget)
    }

    var availableUnits: [String] {
        switch habitType {
        case .health:
            if let natural = localeNaturalUnit {
                return [natural]
            }
            return ["count"]
        case .nonHealth:
            return ["glasses", "pages", "minutes", "km", "steps", "count"]
        }
    }

    func load(habit: HabitDTO?) {
        guard let habit = habit else { return }
        name = habit.name
        unitLabel = habit.unitLabel ?? localeNaturalUnit ?? ""
        incrementStep = habit.incrementStep
        incrementCount = Int(round(habit.dailyTarget / max(habit.incrementStep, 1)))
        incrementCount = max(incrementCount, 1)
        weeklyFrequency = habit.weeklyFrequency
        selectedCategories = habit.categories
        healthKitIdentifier = habit.healthKitIdentifier
        habitType = habit.healthKitIdentifier == nil ? .nonHealth : .health
        didEditUnit = true
        didEditIncrement = true
        didEditCount = true
    }

    func applyHealthKitDefaultsIfNeeded() {
        guard let identifier = healthKitIdentifier else { return }
        if !didEditUnit || unitLabel.isEmpty {
            unitLabel = localeNaturalUnit ?? ""
        }
        if !didEditIncrement || incrementStep == 1 {
            switch identifier {
            case "water":
                incrementStep = 250
            case "steps":
                incrementStep = 500
            case "workouts", "mindful":
                incrementStep = 5
            default:
                break
            }
        }
    }

    func makeDTO(existing: HabitDTO?) -> HabitDTO {
        let target = clampedTarget(dailyTarget, identifier: healthKitIdentifier)
        let step = max(min(incrementStep, HabitConfig.maxIncrementStep), HabitConfig.incrementStepRange.lowerBound)
        let trimmedUnit = unitLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        // For Health-linked habits, store unitLabel only when the user has explicitly
        // overridden the locale-natural unit. Otherwise leave it nil so the UI renders
        // the locale-natural symbol derived from the identifier.
        let storedUnitLabel: String? = {
            guard habitType == .health, let identifier = healthKitIdentifier else {
                return trimmedUnit.isEmpty ? nil : trimmedUnit
            }
            let natural = HabitFormatter.healthKitUnitString(for: identifier).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let candidate = trimmedUnit.lowercased()
            return candidate.isEmpty || candidate == natural ? nil : trimmedUnit
        }()
        return HabitDTO(
            id: existing?.id,
            uuid: existing?.uuid ?? UUID(),
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            unitLabel: storedUnitLabel,
            dailyTarget: target,
            incrementStep: step,
            weeklyFrequency: weeklyFrequency,
            healthKitIdentifier: healthKitIdentifier,
            categories: selectedCategories
        )
    }

    private func clampedTarget(_ value: Double, identifier: String?) -> Double {
        let range = HabitConfig.dailyTargetRange(for: identifier)
        return min(max(value, range.lowerBound), range.upperBound)
    }
}

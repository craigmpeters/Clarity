import Foundation
import XCGLogger
#if canImport(HealthKit)
import HealthKit
#endif

/// Manages HealthKit authorization, writing of HKStateOfMind samples, and reading of
/// habit-linked quantities (water, steps, exercise time, mindful minutes).
/// All public methods are safe to call regardless of HealthKit availability.
@MainActor
final class HealthKitService {
    static let shared = HealthKitService()

#if canImport(HealthKit)
    private let store = HKHealthStore()
    private let stateOfMindType = HKObjectType.stateOfMindType()
#endif

    // MARK: - Availability

    var isAvailable: Bool {
#if canImport(HealthKit)
        HKHealthStore.isHealthDataAvailable()
#else
        false
#endif
    }

    /// Whether the user has granted write permission for state-of-mind samples.
    var isAuthorized: Bool {
#if canImport(HealthKit)
        store.authorizationStatus(for: stateOfMindType) == .sharingAuthorized
#else
        false
#endif
    }

    // MARK: - Authorization

    func requestAuthorization() async {
        guard isAvailable else { return }
#if canImport(HealthKit)
        do {
            try await store.requestAuthorization(
                toShare: [stateOfMindType],
                read: [stateOfMindType]
            )
        } catch {
            LogManager.shared.log.error("HealthKit authorization failed: \(error.localizedDescription)")
        }
#endif
    }

    func requestAuthorization(for identifiers: [String]) async {
        guard isAvailable else { return }
#if canImport(HealthKit)
        let readTypes = identifiers.compactMap { objectType(for: $0) }
        let writeTypes = identifiers.compactMap { sampleType(for: $0) }
        guard !readTypes.isEmpty || !writeTypes.isEmpty else { return }
        do {
            try await store.requestAuthorization(
                toShare: Set(writeTypes + [stateOfMindType]),
                read: Set(readTypes + [stateOfMindType])
            )
        } catch {
            LogManager.shared.log.error("HealthKit authorization failed: \(error.localizedDescription)")
        }
#endif
    }

    // MARK: - Writing

    /// Saves a momentary-emotion HKStateOfMind sample at `date` for a completed Pomodoro.
    func logStateOfMind(label: HKStateOfMind.Label, valence: Double, date: Date = Date(), taskName: String? = nil) async {
        guard isAvailable, isAuthorized else {
            LogManager.shared.log.debug("HealthKit not available or not authorized — skipping state-of-mind log")
            return
        }
#if canImport(HealthKit)
        var metadata: [String: Any] = [:]
        if let taskName, !taskName.isEmpty {
            metadata["Habit Name"] = taskName
        }
        let sample = HKStateOfMind(
            date: date,
            kind: .momentaryEmotion,
            valence: valence,
            labels: [label],
            associations: [.tasks],
            metadata: metadata.isEmpty ? nil : metadata
        )
        do {
            try await store.save(sample)
            LogManager.shared.log.debug("Saved HKStateOfMind sample: \(label) valence=\(valence) task=\(taskName ?? "none")")
        } catch {
            LogManager.shared.log.error("Failed to save HKStateOfMind: \(error.localizedDescription)")
        }
#endif
    }

    /// Saves a quantity sample for a habit-linked HealthKit type.
    /// Used when the user manually logs progress on a HealthKit-linked habit.
    func saveHabitSample(identifier: String, value: Double, date: Date = Date()) async {
        guard isAvailable else {
            LogManager.shared.log.debug("HealthKit not available — skipping habit sample save")
            return
        }
#if canImport(HealthKit)
        guard let type = objectType(for: identifier) else {
            LogManager.shared.log.error("Unknown HealthKit identifier: \(identifier)")
            return
        }

        do {
            if let quantityType = type as? HKQuantityType {
                let unit = unit(for: identifier)
                let quantity = HKQuantity(unit: unit, doubleValue: value)
                let sample = HKQuantitySample(type: quantityType, quantity: quantity, start: date, end: date)
                try await store.save(sample)
                LogManager.shared.log.debug("Saved HKQuantitySample: \(identifier) value=\(value) unit=\(unit.unitString)")
            } else if let categoryType = type as? HKCategoryType {
                // For category types (mindful), create a short-duration sample
                let end = date.addingTimeInterval(value * 60) // value is in minutes
                let sample = HKCategorySample(type: categoryType, value: 0, start: date, end: end)
                try await store.save(sample)
                LogManager.shared.log.debug("Saved HKCategorySample: \(identifier) duration=\(value)min")
            }
        } catch {
            LogManager.shared.log.error("Failed to save HealthKit sample for \(identifier): \(error.localizedDescription)")
        }
#endif
    }

    // MARK: - Habit-linked quantities

    func cumulativeToday(for identifier: String) async -> Double? {
        await cumulativeValue(for: identifier, on: Date())
    }

    /// Returns the cumulative value of a habit-linked HealthKit type for the whole
    /// calendar day containing `date`. Used to backfill days when the app was not opened.
    func cumulativeValue(for identifier: String, on date: Date) async -> Double? {
        guard isAvailable else { return nil }
#if canImport(HealthKit)
        guard let type = objectType(for: identifier) else { return nil }
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return nil }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            if let quantityType = type as? HKQuantityType {
                let query = HKStatisticsQuery(
                    quantityType: quantityType,
                    quantitySamplePredicate: predicate,
                    options: .cumulativeSum
                ) { _, result, _ in
                    let unit = self.unit(for: identifier)
                    let value = result?.sumQuantity()?.doubleValue(for: unit) ?? 0
                    continuation.resume(returning: value)
                }
                store.execute(query)
            } else if let categoryType = type as? HKCategoryType {
                let query = HKSampleQuery(
                    sampleType: categoryType,
                    predicate: predicate,
                    limit: HKObjectQueryNoLimit,
                    sortDescriptors: nil
                ) { [weak self] _, samples, _ in
                    guard let self = self else {
                        continuation.resume(returning: 0)
                        return
                    }
                    let minutes = self.cumulativeMinutes(for: samples as? [HKCategorySample], identifier: identifier)
                    continuation.resume(returning: minutes)
                }
                store.execute(query)
            } else {
                continuation.resume(returning: nil)
            }
        }
#else
        return nil
#endif
    }

#if canImport(HealthKit)
    private func objectType(for identifier: String) -> HKObjectType? {
        switch identifier {
        case "water":
            return HKQuantityType.quantityType(forIdentifier: .dietaryWater)
        case "steps":
            return HKQuantityType.quantityType(forIdentifier: .stepCount)
        case "workouts":
            return HKQuantityType.quantityType(forIdentifier: .appleExerciseTime)
        case "mindful":
            return HKCategoryType.categoryType(forIdentifier: .mindfulSession)
        default:
            return nil
        }
    }

    private func sampleType(for identifier: String) -> HKSampleType? {
        switch identifier {
        case "water":
            return HKQuantityType.quantityType(forIdentifier: .dietaryWater)
        case "steps":
            return HKQuantityType.quantityType(forIdentifier: .stepCount)
        case "workouts":
            return HKQuantityType.quantityType(forIdentifier: .appleExerciseTime)
        case "mindful":
            return HKCategoryType.categoryType(forIdentifier: .mindfulSession)
        default:
            return nil
        }
    }

    private func unit(for identifier: String) -> HKUnit {
        switch identifier {
        case "water": return HKUnit.literUnit(with: .milli)
        case "steps": return HKUnit.count()
        case "workouts": return HKUnit.minute()
        case "mindful": return HKUnit.minute()
        default: return HKUnit.count()
        }
    }

    private func cumulativeMinutes(for samples: [HKCategorySample]?, identifier: String) -> Double {
        guard let samples = samples else { return 0 }
        return samples.reduce(0) { total, sample in
            total + sample.endDate.timeIntervalSince(sample.startDate) / 60
        }
    }
#endif
}

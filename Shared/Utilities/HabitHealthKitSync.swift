import Foundation
import XCGLogger
#if canImport(HealthKit)
import HealthKit
#endif

/// Foreground sync of HealthKit quantities into habit occurrences.
/// V1: runs on app foreground / Habits tab refresh. No background observer.
@MainActor
final class HabitHealthKitSync {
    static let shared = HabitHealthKitSync()

    private init() {}

    /// Sync today's HealthKit data for all active habits with a `healthKitIdentifier`.
    /// Returns the updated occurrences so callers can react to newly completed habits.
    func syncAllHabits() async -> [HabitOccurrenceDTO] {
        #if !canImport(HealthKit)
        return []
        #else
        guard HealthKitService.shared.isAvailable else { return [] }
        guard let store = try? await ClarityServices.store() else { return [] }
        guard let habits = try? await store.fetchHabits() else { return [] }

        var updated: [HabitOccurrenceDTO] = []

        for habit in habits where habit.healthKitIdentifier != nil {
            guard let identifier = habit.healthKitIdentifier else { continue }
            guard let value = await HealthKitService.shared.cumulativeToday(for: identifier) else { continue }
            guard value > 0 else { continue }
            do {
                let dto = try await store.applyHealthKitProgress(habit.uuid, value: value)
                updated.append(dto)
            } catch {
                LogManager.shared.log.error("HealthKit sync failed for \(habit.name): \(error)")
            }
        }
        return updated
        #endif
    }

    /// Request authorization for a habit identifier the first time it is linked.
    func requestAuthorizationIfNeeded(for identifier: String?) {
        guard let identifier = identifier, !identifier.isEmpty else { return }
        Task {
            await HealthKitService.shared.requestAuthorization(for: [identifier])
        }
    }

    /// Write a single habit sample to HealthKit from any target that can import HealthKit.
    /// Call sites should only invoke this on iOS; watchOS and extensions should not write.
    func writeHabitSampleIfNeeded(habitUUID: UUID, identifier: String, value: Double) async {
        await HealthKitService.shared.saveHabitSample(identifier: identifier, value: value)
    }
}

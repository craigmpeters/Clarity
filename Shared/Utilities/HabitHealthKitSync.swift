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
    /// Returns the number of habits updated.
    func syncAllHabits() async -> Int {
        #if !canImport(HealthKit)
        return 0
        #else
        guard HealthKitService.shared.isAvailable else { return 0 }
        guard let store = try? await ClarityServices.store() else { return 0 }
        guard let habits = try? await store.fetchHabits() else { return 0 }

        var updated = 0

        for habit in habits where habit.healthKitIdentifier != nil {
            guard let identifier = habit.healthKitIdentifier else { continue }
            guard let value = await HealthKitService.shared.cumulativeToday(for: identifier) else { continue }
            guard value > 0 else { continue }
            do {
                _ = try await store.applyHealthKitProgress(habit.uuid, value: value)
                updated += 1
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

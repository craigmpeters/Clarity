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

    /// UserDefaults key for the last day HealthKit data was applied for a habit.
    /// Used to backfill occurrences for days when the app was not opened.
    private let lastSyncDatesKey = "habitHealthKitLastSyncDates"

    /// Maximum number of past days to backfill per sync, as a safety bound.
    private let maxBackfillDays = 30

    private init() {}

    /// Sync HealthKit data for all active habits with a `healthKitIdentifier`.
    /// Applies today's value and backfills any days missed since the last sync,
    /// so occurrences exist for days when the app was never opened.
    /// Returns the updated occurrences so callers can react to newly completed habits.
    func syncAllHabits() async -> [HabitOccurrenceDTO] {
        #if !canImport(HealthKit)
        return []
        #else
        guard HealthKitService.shared.isAvailable else { return [] }
        guard let store = try? await ClarityServices.store() else { return [] }
        guard let habits = try? await store.fetchHabits() else { return [] }

        let calendar = Calendar.current
        let now = Date()
        let today = calendar.startOfDay(for: now)
        var lastSyncDates = UserDefaults.standard.dictionary(forKey: lastSyncDatesKey) as? [String: TimeInterval] ?? [:]

        var updated: [HabitOccurrenceDTO] = []

        for habit in habits where habit.healthKitIdentifier != nil {
            guard let identifier = habit.healthKitIdentifier else { continue }

            // Determine which days need data: from the day after the last successful sync
            // (or habit creation, bounded by maxBackfillDays) through today.
            let habitKey = habit.uuid.uuidString
            let lastSync = lastSyncDates[habitKey].map(Date.init(timeIntervalSince1970:))
            let earliestStart = calendar.date(byAdding: .day, value: -maxBackfillDays, to: today) ?? today
            let fallbackStart = max(calendar.startOfDay(for: habit.created), earliestStart)
            var day: Date
            if let lastSync {
                let lastSyncDay = calendar.startOfDay(for: lastSync)
                // Re-apply the last synced day too, in case that sync ran mid-day and
                // HealthKit recorded more data later in the day.
                day = max(lastSyncDay, fallbackStart)
            } else {
                day = fallbackStart
            }

            var appliedAny = false
            while day <= today {
                if let value = await HealthKitService.shared.cumulativeValue(for: identifier, on: day), value > 0 {
                    do {
                        let dto = try await store.applyHealthKitProgress(habit.uuid, value: value, date: day)
                        updated.append(dto)
                        appliedAny = true
                    } catch {
                        LogManager.shared.log.error("HealthKit sync failed for \(habit.name): \(error)")
                    }
                }
                guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
                day = next
            }

            if appliedAny {
                lastSyncDates[habitKey] = now.timeIntervalSince1970
            }
        }

        UserDefaults.standard.set(lastSyncDates, forKey: lastSyncDatesKey)
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

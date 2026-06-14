import Foundation
import HealthKit

/// Manages HealthKit authorization and writing of HKStateOfMind samples.
/// All public methods are safe to call regardless of HealthKit availability.
@MainActor
final class HealthKitService {
    static let shared = HealthKitService()

    private let store = HKHealthStore()
    private let stateOfMindType = HKObjectType.stateOfMindType()

    // MARK: - Availability

    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    /// Whether the user has granted write permission for state-of-mind samples.
    var isAuthorized: Bool {
        store.authorizationStatus(for: stateOfMindType) == .sharingAuthorized
    }

    // MARK: - Authorization

    func requestAuthorization() async {
        guard isAvailable else { return }
        do {
            try await store.requestAuthorization(
                toShare: [stateOfMindType],
                read: [stateOfMindType]
            )
        } catch {
            LogManager.shared.log.error("HealthKit authorization failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Writing

    /// Saves a momentary-emotion HKStateOfMind sample at `date` for a completed Pomodoro.
    /// - Parameters:
    ///   - label: The emotion label selected by the user.
    ///   - valence: Score from -1.0 (very negative) to +1.0 (very positive).
    ///   - date: When the Pomodoro ended (defaults to now).
    func logStateOfMind(label: HKStateOfMind.Label, valence: Double, date: Date = Date()) async {
        guard isAvailable, isAuthorized else {
            LogManager.shared.log.debug("HealthKit not available or not authorized — skipping state-of-mind log")
            return
        }
        let sample = HKStateOfMind(
            date: date,
            kind: .momentaryEmotion,
            valence: valence,
            labels: [label],
            associations: [.tasks]
        )
        do {
            try await store.save(sample)
            LogManager.shared.log.debug("Saved HKStateOfMind sample: \(label) valence=\(valence)")
        } catch {
            LogManager.shared.log.error("Failed to save HKStateOfMind: \(error.localizedDescription)")
        }
    }
}

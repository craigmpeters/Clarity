import ActivityKit
import AppIntents
import Foundation
import XCGLogger

/// Stops the active Pomodoro session, ends the Live Activity, completes the task,
/// records the session for the history list, and flags the main app to reset its state.
/// `openAppWhenRun: true` causes the main app to be foregrounded after the intent runs.
struct StopPomodoroIntent: AppIntent {
    static let title: LocalizedStringResource = "Stop Pomodoro"
    static let description = IntentDescription("Stop the active Pomodoro timer and complete the task")
    static let openAppWhenRun: Bool = true

    private let appGroup = "group.me.craigpeters.clarity"
    private let persistKey = "activePomodoroState"
    private let sessionHistoryKey = "completedPomodoroSessions"
    private let externalStopFlagKey = "pomodoroWasStoppedExternally"

    init() {}

    func perform() async throws -> some IntentResult & OpensIntent {
        let defaults = UserDefaults(suiteName: appGroup)

        // Decode the persisted session once before we clear it.
        let persisted: PersistedPomodoro? = {
            guard let data = defaults?.data(forKey: persistKey) else { return nil }
            return try? JSONDecoder().decode(PersistedPomodoro.self, from: data)
        }()
        let taskUUID = persisted?.taskUUID
        let taskName = persisted?.taskName
        let taskStartedAt = persisted?.startTime

        // End all active Live Activities.
        for activity in Activity<PomodoroAttributes>.activities {
            await activity.end(
                ActivityContent(state: activity.content.state, staleDate: nil),
                dismissalPolicy: .immediate
            )
        }

        // Clear the persisted session so the app doesn't try to restore it.
        defaults?.removeObject(forKey: persistKey)

        // Complete the task with the original started time.
        if let uuid = taskUUID {
            do {
                let store = try await ClarityServices.store()
                try await store.completeTask(uuid, startedAt: taskStartedAt)
                if let started = taskStartedAt {
                    let elapsed = Date().timeIntervalSince(started)
                    LogManager.shared.log.debug("StopPomodoroIntent: completed task \(uuid.uuidString) (elapsed: \(elapsed)s)")
                } else {
                    LogManager.shared.log.debug("StopPomodoroIntent: completed task \(uuid.uuidString)")
                }
            } catch {
                LogManager.shared.log.error("StopPomodoroIntent: failed to complete task \(error)")
            }
        }

        // Record the completed session so the history list is up-to-date even if the
        // main app process was killed when the Live Activity button was tapped.
        let endTime = Date()
        let startTime = taskStartedAt ?? endTime
        recordCompletedSession(
            taskName: taskName ?? "Unknown Task",
            taskUUID: taskUUID,
            startTime: startTime,
            endTime: endTime,
            in: defaults
        )

        // Flag the main app to reset its in-memory PomodoroService singleton state.
        defaults?.set(true, forKey: externalStopFlagKey)

        ClarityServices.reloadWidgets(kind: "ClarityWidget")
        return .result()
    }

    private func recordCompletedSession(
        taskName: String,
        taskUUID: UUID?,
        startTime: Date,
        endTime: Date,
        in defaults: UserDefaults?
    ) {
        var sessions: [CompletedSession] = []
        if let data = defaults?.data(forKey: sessionHistoryKey),
           let existing = try? JSONDecoder().decode([CompletedSession].self, from: data) {
            sessions = existing
        }
        let session = CompletedSession(
            id: UUID(),
            taskName: taskName,
            taskUUID: taskUUID,
            startTime: startTime,
            endTime: endTime
        )
        sessions.insert(session, at: 0)
        let cutoff = Date().addingTimeInterval(-12 * 3600)
        sessions = sessions.filter { $0.endTime >= cutoff }
        if let data = try? JSONEncoder().encode(sessions) {
            defaults?.set(data, forKey: sessionHistoryKey)
        }
        LogManager.shared.log.debug("StopPomodoroIntent: recorded completed session")
    }
}

/// Mirror of PomodoroService.CompletedSession — must stay in sync with PomodoroService.swift.
private struct CompletedSession: Codable {
    let id: UUID
    let taskName: String
    let taskUUID: UUID?
    let startTime: Date
    let endTime: Date
    var moodLogged: Bool = false
    var moodEmoji: String? = nil
}

/// Mirror of PomodoroService.PersistedPomodoro — must stay in sync with PomodoroService.swift.
private struct PersistedPomodoro: Codable {
    let taskUUID: UUID?
    let taskName: String?
    let startTime: Date
    let endTime: Date
    let startedDevice: String
}

import ActivityKit
import AppIntents
import Foundation
import XCGLogger

/// Stops the active Pomodoro session, ends the Live Activity, and completes the task.
/// Runs without opening the app — safe to call from Lock Screen / Dynamic Island buttons.
struct StopPomodoroIntent: AppIntent {
    static let title: LocalizedStringResource = "Stop Pomodoro"
    static let description = IntentDescription("Stop the active Pomodoro timer and complete the task")
    static let openAppWhenRun: Bool = false

    init() {}

    func perform() async throws -> some IntentResult {
        let appGroup = "group.me.craigpeters.clarity"
        let persistKey = "activePomodoroState"

        // Decode persisted session to get the task UUID and started time
        let defaults = UserDefaults(suiteName: appGroup)
        let (taskUUID, taskStartedAt): (UUID?, Date?) = {
            guard let data = defaults?.data(forKey: persistKey),
                  let persisted = try? JSONDecoder().decode(PersistedPomodoro.self, from: data)
            else { return (nil, nil) }
            return (persisted.taskUUID, persisted.startTime)
        }()

        // End all active Live Activities
        for activity in Activity<PomodoroAttributes>.activities {
            await activity.end(
                ActivityContent(state: activity.content.state, staleDate: nil),
                dismissalPolicy: .immediate
            )
        }

        // Clear the persisted session so the app doesn't try to restore it
        defaults?.removeObject(forKey: persistKey)

        // Complete the task with started time
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

        ClarityServices.reloadWidgets(kind: "ClarityWidget")
        return .result()
    }
}

/// Mirror of PomodoroService.PersistedPomodoro — must stay in sync with PomodoroService.swift.
private struct PersistedPomodoro: Codable {
    let taskUUID: UUID?
    let taskName: String?
    let startTime: Date
    let endTime: Date
    let startedDevice: String
}

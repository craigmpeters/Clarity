//
//  PomodoroService.swift
//  Clarity
//
//  Created by Craig Peters on 11/10/2025.
//

@preconcurrency import ActivityKit
import Combine
import Foundation
import SwiftData
import UserNotifications
import AppIntents
import XCGLogger

@MainActor final class PomodoroService: ObservableObject {
    static let shared = PomodoroService()
    
    @Published var isActive: Bool = false
    var toDoTask: ToDoTaskDTO?
    var startedDevice: DeviceType = .iPhone
    @Published var endTime: Date?
    @Published var startTime: Date?
    @Published var remainingTime: TimeInterval = 0
    @Published var progress: Double = 0

    /// Derived identifier for the completion notification so it survives process restarts.
    var notificationIdentifier: String {
        if let uuid = toDoTask?.uuid {
            return "pomodoro-\(uuid.uuidString)"
        }
        return "pomodoro-generic"
    }
    
    var formattedTime: String {
        let time = remainingTime
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private var activity: Activity<PomodoroAttributes>?
    private var cancellables = Set<AnyCancellable>()
    private var timer: Timer?
    private var container: ModelContainer?
    private var calculatedRemainingTime: TimeInterval? {
        guard let endTime = endTime else { return nil }
        let remaining = endTime.timeIntervalSinceNow
        return max(0, remaining)
    }

    private var calculatedProgress: Double {
        guard remainingTime > 0 else { return 0 }
        let totalTime: TimeInterval? = {
            if let t = toDoTask?.pomodoroTime  { return t }
            if let s = startTime, let e = endTime { return e.timeIntervalSince(s) }
            return nil
        }()
        guard let total = totalTime, total > 0 else { return 0 }
        return 1.0 - (remainingTime / total)
    }
    
    /// A single completed Pomodoro session, stored for display in the history list.
    struct CompletedSession: Codable, Identifiable {
        let id: UUID
        let taskName: String
        let taskUUID: UUID?
        let startTime: Date
        let endTime: Date   // actual end (may be early)
        var moodLogged: Bool = false
        var moodEmoji: String? = nil
    }

    @Published var recentSessions: [CompletedSession] = []

    private let pomodoroPersistKey = "activePomodoroState"
    private let sessionHistoryKey = "completedPomodoroSessions"
    private let externalStopFlagKey = "pomodoroWasStoppedExternally"
    private let appGroupID = "group.me.craigpeters.clarity"
    
    private struct PersistedPomodoro: Codable {
        let taskUUID: UUID?
        let taskName: String?
        let startTime: Date
        let endTime: Date
        let startedDevice: String
    }
    
    private func appGroupDefaults() -> UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }
    
    enum DeviceType {
        case iPhone
        case watchOS
    }
    
    // MARK: Preview Support

#if DEBUG
    /// Creates a `PomodoroService` with a running timer pre-seeded for SwiftUI previews.
    /// Bypasses Live Activities, notifications, and persistence entirely.
    @MainActor
    static func makePreview(taskName: String = "SwiftUI documentation reading",
                            totalMinutes: Int = 25,
                            elapsedMinutes: Int = 10) -> PomodoroService {
        let svc = PomodoroService()
        let totalSeconds = TimeInterval(totalMinutes * 60)
        let elapsed = TimeInterval(elapsedMinutes * 60)
        let now = Date()
        svc.toDoTask = ToDoTaskDTO(
            name: taskName,
            pomodoroTime: totalSeconds,
            due: now,
            completed: false
        )
        svc.startTime = now.addingTimeInterval(-elapsed)
        svc.endTime   = now.addingTimeInterval(totalSeconds - elapsed)
        svc.remainingTime = totalSeconds - elapsed
        svc.progress  = elapsed / totalSeconds
        svc.isActive  = true
        return svc
    }
#endif

    // MARK: Public Functions
    
    @MainActor
    func startPomodoro(for toDoTask: ToDoTaskDTO, container: ModelContainer, device: DeviceType) {
        LogManager.shared.log.info("Starting Pomodoro for \(toDoTask.name)")
        startedDevice = device
        self.container = container
        self.toDoTask = toDoTask
        let now = Date()
        startTime = now
        endTime = Date(timeInterval: toDoTask.pomodoroTime, since: now)
        isActive = true
        startTimer()
        startLiveActivity()
        persistState()
        if let end = endTime {
            let alarmSound = PomodoroAlarmSound.from(persistenceID: UserDefaults.pomodoroAlarmSoundID)
            let notif = NotificationContent(
                title: "Pomodoro Finished",
                body: "Task '\(toDoTask.name)' is done!",
                sound: alarmSound.notificationSound
            )
            scheduleNotification(date: end, notification: notif)
        }
        NotificationCenter.default.post(name: .pomodoroStarted, object: nil)
    }
    
    func endPomodoro() async {
        // Always attempt to clean up system resources even if the in-memory state is
        // already inactive. A process restart or external stop can leave the persisted
        // flag out of sync while the Live Activity / notification still exist.
        let wasActive = isActive
        let currentActivityCount = Activity<PomodoroAttributes>.activities.count
        LogManager.shared.log.debug(
            "endPomodoro: wasActive=\(wasActive) remainingTime=\(remainingTime) liveActivities=\(currentActivityCount)"
        )
        if !wasActive {
            LogManager.shared.log.debug("Pomodoro already inactive; running cleanup only")
        }

        // Capture session details before clearing state
        let sessionTaskName = toDoTask?.name ?? "Unknown Task"
        let sessionStart = startTime ?? Date()
        let sessionEnd = Date()

        // Determine if the timer ran out naturally (vs. manual early stop)
        let completedNaturally = remainingTime <= 0

        // Capture the task UUID before clearing the in-memory session state
        let completedTaskUUID = toDoTask?.uuid

        // Mark inactive and clean up timer/activity/notification
        isActive = false

        if let t = timer {
            t.invalidate()
        }
        timer = nil

        stopLiveActivity(naturally: completedNaturally)
        cancelNotification()
        clearPersistedState()

        guard wasActive else { return }

        // Record the completed session for the history list
        recordCompletedSession(taskName: sessionTaskName, taskUUID: toDoTask?.uuid, startTime: sessionStart, endTime: sessionEnd, pomodoroTime: toDoTask?.pomodoroTime ?? 0)

        // Post a single completion notification with the task UUID so observers
        // don't have to rely on the now-cleared in-memory task state.
        let userInfo: [AnyHashable: Any] = completedTaskUUID.map { [Notification.Name.taskUUIDKey: $0] } ?? [:]
        NotificationCenter.default.post(name: .pomodoroCompleted, object: nil, userInfo: userInfo)
    }
    
    @MainActor
    func restoreIfNeeded(container: ModelContainer, device: DeviceType) async {
        loadSessionHistory()
        // UI tests launch fresh each time; avoid restoring a timer that leaks across test launches.
        if ProcessInfo.processInfo.arguments.contains("--uitesting") {
            clearPersistedState()
            return
        }
        guard let data = appGroupDefaults()?.data(forKey: pomodoroPersistKey) else {
            LogManager.shared.log.debug("restoreIfNeeded: no Pomodoro state to restore")
            // No persisted timer, but there could still be orphaned system UI.
            reconcileSystemStateIfNeeded()
            return
        }
        do {
            let persisted = try JSONDecoder().decode(PersistedPomodoro.self, from: data)
            LogManager.shared.log.debug("Restoring Pomodoro with task: \(persisted.taskName ?? "Task Unknown")")
            guard persisted.endTime > Date() else {
                LogManager.shared.log.debug("Pomodoro already completed, not restoring")
                let store = ClarityModelActor(modelContainer: container)
                let lastCompleted = await store.fetchLastCompletedTask()
                if let uuid = persisted.taskUUID {
                    let alreadyCompleted = lastCompleted?.uuid == uuid
                        && (lastCompleted?.completedAt ?? .distantPast) > persisted.startTime
                    if alreadyCompleted {
                        LogManager.shared.log.debug("Task already completed")
                    } else {
                        LogManager.shared.log.debug("Completing task after restoring UUID: \(uuid.uuidString)")
                        try await store.completeTask(uuid, startedAt: persisted.startTime)
                    }
                }
                clearPersistedState()
                stopLiveActivity()
                cancelNotification()
                LogManager.shared.log.debug("restoreIfNeeded: expired pomodoro cleaned up")
                return
            }
            
            // rebuild state
            self.container = container
            self.isActive = true
            self.startedDevice = (persisted.startedDevice == "watchOS") ? .watchOS : .iPhone
            self.startTime = persisted.startTime
            self.endTime = persisted.endTime
            
            // Find Task
            if let uuid = persisted.taskUUID {
                let store = ClarityModelActor(modelContainer: container)
                if let dto = try? await store.fetchTaskByUuid(uuid) {
                    self.toDoTask = dto
                } else {
                    self.toDoTask = nil
                    LogManager.shared.log.debug("Failed to find task with UUID: \(uuid)")
                }
            }
            
            // Attach to Activity
            let existingActivities = Activity<PomodoroAttributes>.activities
            LogManager.shared.log.debug("restoreIfNeeded: found \(existingActivities.count) existing Live Activities")
            if let existing = existingActivities.first {
                self.activity = existing
                LogManager.shared.log.debug("restoreIfNeeded: attached to existing Live Activity id=\(existing.id) state=\(existing.activityState)")
            } else {
                LogManager.shared.log.debug("restoreIfNeeded: no Live Activity found, creating new one")
                startLiveActivity()
            }
            
            // Recompute time/progress and resume timer
            self.remainingTime = max(0, self.endTime?.timeIntervalSinceNow ?? 0)
            self.progress = self.calculatedProgress
            startTimer()

            // Update UI
            NotificationCenter.default.post(name: .pomodoroStarted, object: nil)
            LogManager.shared.log.info("Restored active pomodoro from persisted state")
            
        } catch {
            LogManager.shared.log.error("Failed to decode Pomodoro state: \(error)")
            clearPersistedState()
        }
        
    }
    
    // MARK: Live Activities
    
    private func startLiveActivity() {
        let attributes = PomodoroAttributes(sessionId: UUID().uuidString)
        guard let task = toDoTask else {
            LogManager.shared.log.warning("startLiveActivity: no task set, skipping")
            return
        }
        guard let start = startTime, let end = endTime else {
            LogManager.shared.log.warning("startLiveActivity: missing start/end time, skipping")
            return
        }

        // Clean up any pre-existing activities before requesting a new one.
        let existing = Activity<PomodoroAttributes>.activities
        if !existing.isEmpty {
            LogManager.shared.log.debug("startLiveActivity: \(existing.count) pre-existing Live Activities found, ending them first")
            for old in existing {
                Task {
                    try? await old.end(
                        ActivityContent(state: old.content.state, staleDate: nil),
                        dismissalPolicy: .immediate
                    )
                }
            }
        }

        let contentState = PomodoroAttributes.ContentState(
            taskName: task.name,
            startTime: start,
            endTime: end
        )
        let activityContent = ActivityContent(state: contentState, staleDate: end)
        do {
            activity = try Activity.request(
                attributes: attributes,
                content: activityContent,
                pushType: nil
            )
            LogManager.shared.log.debug("startLiveActivity: started Live Activity id=\(activity?.id ?? "nil") for task: \(task.name)")
        } catch {
            LogManager.shared.log.error("startLiveActivity: failed to start Live Activity: \(error.localizedDescription)")
        }
    }
    
    private func stopLiveActivity(naturally: Bool = false) {
        let all = Activity<PomodoroAttributes>.activities
        LogManager.shared.log.debug("stopLiveActivity(naturally: \(naturally)): found \(all.count) Live Activities")

        guard !all.isEmpty else {
            LogManager.shared.log.debug("stopLiveActivity: no Live Activity to stop")
            activity = nil
            return
        }

        // Log each activity's state up front so we can diagnose stuck activities.
        for (index, activity) in all.enumerated() {
            LogManager.shared.log.debug(
                "stopLiveActivity: activity[\(index)] id=\(activity.id) state=\(activity.activityState) staleDate=\(activity.content.staleDate?.description ?? "nil")"
            )
        }

        Task {
            var endedAny = false
            for activity in all {
                let stateDescription = "\(activity.activityState)"
                LogManager.shared.log.debug(
                    "stopLiveActivity: attempting to end activity id=\(activity.id) state=\(stateDescription) naturally=\(naturally)"
                )

                do {
                    if naturally {
                        // Leave the activity visible (stale) so the user can tap a mood button.
                        // Use .after to auto-dismiss after 5 minutes if no mood is tapped.
                        try await activity.end(
                            ActivityContent(state: activity.content.state, staleDate: Date()),
                            dismissalPolicy: .after(Date().addingTimeInterval(5 * 60))
                        )
                    } else {
                        try await activity.end(
                            ActivityContent(state: activity.content.state, staleDate: nil),
                            dismissalPolicy: .immediate
                        )
                    }
                    endedAny = true
                    LogManager.shared.log.debug(
                        "stopLiveActivity: ended activity id=\(activity.id) (naturally: \(naturally))"
                    )
                } catch {
                    LogManager.shared.log.error(
                        "stopLiveActivity: failed to end activity id=\(activity.id) state=\(stateDescription): \(error.localizedDescription)"
                    )
                }
            }

            if !endedAny {
                LogManager.shared.log.error(
                    "stopLiveActivity: could not stop any Live Activity (attempted \(all.count))"
                )
            }

            // Always clear our stored reference, even if ending failed.
            self.activity = nil
        }
    }
    
    // #MARK: Notifications
    
    struct NotificationContent {
        var title: String
        var body: String
        var sound: UNNotificationSound = .default
    }
    
    func scheduleNotification(date: Date, notification: NotificationContent) {
        let content = UNMutableNotificationContent()
        let identifier = notificationIdentifier
        content.title = notification.title
        content.body = notification.body
        content.sound = notification.sound
        content.userInfo = ["pomodoro": identifier]

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date), repeats: false
        )

        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                LogManager.shared.log.error("Error scheduling notification: \(error)")
            } else {
                LogManager.shared.log.debug("Notification scheduled successfully for \(date.ISO8601Format())")
            }
        }
    }

    func cancelNotification() {
        LogManager.shared.log.debug("Cancelling Notification")
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [notificationIdentifier])
    }
    
    // MARK: Pomodoro Timer Function

    private func startTimer() {
        LogManager.shared.log.debug("Starting Pomodoro Timer")
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                // Ensure main-actor access to state
                let remaining = self.calculatedRemainingTime ?? 0
                self.remainingTime = remaining
                self.progress = self.calculatedProgress
                if self.remainingTime <= 0 {
                    self.timer?.invalidate()
                    self.timer = nil
                    await self.endPomodoro()
                }
            }
        }
        RunLoop.main.add(timer!, forMode: .common)
    }
    
    // MARK: Persistence
    @MainActor
    private func persistState() {
        guard isActive, let start = startTime, let end = endTime else {
            clearPersistedState()
            return
        }
        let payload = PersistedPomodoro(
            taskUUID: toDoTask?.uuid,
            taskName: toDoTask?.name,
            startTime: start,
            endTime: end,
            startedDevice: (startedDevice == .iPhone) ? "iPhone" : "watchOS"
        )
        do {
            let data = try JSONEncoder().encode(payload)
            appGroupDefaults()?.set(data, forKey: pomodoroPersistKey)
            LogManager.shared.log.debug("Persisted active pomodoro to defaults")
        } catch {
            LogManager.shared.log.error("Failed to persist pomodoro: \(error.localizedDescription)")
        }
    }

    @MainActor
    private func clearPersistedState() {
        appGroupDefaults()?.removeObject(forKey: pomodoroPersistKey)
        LogManager.shared.log.debug("Cleared persisted pomodoro")
    }

    /// Loads any session history recorded by the widget extension and, if the service still
    /// believes a timer is active, resets it so the UI matches the externally-stopped state.
    @MainActor
    func syncIfStoppedExternally() {
        reconcileSystemStateIfNeeded()
        guard appGroupDefaults()?.bool(forKey: externalStopFlagKey) == true else { return }
        appGroupDefaults()?.removeObject(forKey: externalStopFlagKey)
        let activityCount = Activity<PomodoroAttributes>.activities.count
        LogManager.shared.log.debug(
            "PomodoroService: external stop flag detected (isActive=\(isActive) liveActivities=\(activityCount))"
        )

        if isActive {
            timer?.invalidate()
            timer = nil
            isActive = false
            cancelNotification()
            clearPersistedState()
            // Explicitly end any Live Activities that the widget intent may have missed.
            stopLiveActivity()
            activity = nil
            toDoTask = nil
            startTime = nil
            endTime = nil
            remainingTime = 0
            progress = 0
            loadSessionHistory()
            let userInfo: [AnyHashable: Any] = recentSessions.first?.taskUUID.map {
                [
                    Notification.Name.taskUUIDKey: $0,
                    Notification.Name.completionHandledExternallyKey: true
                ]
            } ?? [:]
            NotificationCenter.default.post(name: .pomodoroCompleted, object: nil, userInfo: userInfo)
            LogManager.shared.log.debug("PomodoroService: reset after external stop (was active)")
        } else {
            loadSessionHistory()
            // The session was completed by the Live Activity intent while the app process
            // was not active; surface the mood sheet so the user can log how it went.
            let userInfo: [AnyHashable: Any] = recentSessions.first?.taskUUID.map {
                [
                    Notification.Name.taskUUIDKey: $0,
                    Notification.Name.completionHandledExternallyKey: true
                ]
            } ?? [:]
            NotificationCenter.default.post(name: .pomodoroCompleted, object: nil, userInfo: userInfo)
            LogManager.shared.log.debug("PomodoroService: loaded history and posted completion after external stop")
        }
    }

    // MARK: - Session History

    /// Marks the session with the given id as having its mood logged, then persists.
    @MainActor
    func markMoodLogged(for sessionID: UUID, emoji: String) {
        guard let index = recentSessions.firstIndex(where: { $0.id == sessionID }) else { return }
        recentSessions[index].moodLogged = true
        recentSessions[index].moodEmoji = emoji
        saveSessionHistory()
    }

    /// Appends a newly completed session and persists the updated list.
    @MainActor
    func recordCompletedSession(taskName: String, taskUUID: UUID?, startTime: Date, endTime: Date, pomodoroTime: TimeInterval) {
        let recordedEndTime = {
            if startTime.addingTimeInterval(pomodoroTime) > endTime {
                return endTime
            } else {
                return startTime.addingTimeInterval(pomodoroTime)
            }
        }
        let session = CompletedSession(
            id: UUID(),
            taskName: taskName,
            taskUUID: taskUUID,
            startTime: startTime,
            endTime: recordedEndTime()
        )
        recentSessions.insert(session, at: 0)
        pruneOldSessions()
        saveSessionHistory()
    }

    /// Loads the session history from app-group storage, pruning entries older than 12 hours.
    @MainActor
    func loadSessionHistory() {
        guard let data = appGroupDefaults()?.data(forKey: sessionHistoryKey),
              let sessions = try? JSONDecoder().decode([CompletedSession].self, from: data)
        else { return }
        let cutoff = Date().addingTimeInterval(-12 * 3600)
        recentSessions = sessions.filter { $0.endTime >= cutoff }
    }

    private func pruneOldSessions() {
        let cutoff = Date().addingTimeInterval(-12 * 3600)
        recentSessions = recentSessions.filter { $0.endTime >= cutoff }
    }

    private func saveSessionHistory() {
        guard let data = try? JSONEncoder().encode(recentSessions) else { return }
        appGroupDefaults()?.set(data, forKey: sessionHistoryKey)
    }

    /// If no timer is persisted as active, ensures no orphaned Live Activity or pending
    /// notification remains. This catches cases where a previous cleanup attempt failed
    /// silently (e.g. process killed mid-stop, or an `Activity.end` call threw).
    @MainActor
    private func reconcileSystemStateIfNeeded() {
        guard !isActive else { return }
        let hasPersistedState = appGroupDefaults()?.data(forKey: pomodoroPersistKey) != nil
        let activityCount = Activity<PomodoroAttributes>.activities.count
        LogManager.shared.log.debug(
            "reconcileSystemStateIfNeeded: isActive=false hasPersistedState=\(hasPersistedState) liveActivities=\(activityCount)"
        )
        if !hasPersistedState {
            if activityCount > 0 {
                LogManager.shared.log.debug("reconcileSystemStateIfNeeded: cleaning up orphaned Live Activities")
            }
            stopLiveActivity()
            cancelNotification()
        }
    }

}

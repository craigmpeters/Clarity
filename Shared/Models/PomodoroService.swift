//
//  PomodoroService.swift
//  Clarity
//
//  Created by Craig Peters on 11/10/2025.
//

import ActivityKit
import Combine
import Foundation
import SwiftData
import UserNotifications
import AppIntents
import XCGLogger

@MainActor final class PomodoroService: ObservableObject {
    static let shared = PomodoroService()
    
    var isActive: Bool = false
    var toDoTask: ToDoTaskDTO?
    var startedDevice: DeviceType = .iPhone
    @Published var endTime: Date?
    @Published var startTime: Date?
    @Published var remainingTime: TimeInterval = 0
    @Published var progress: Double = 0
    
    var formattedTime: String {
        let time = remainingTime
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private var activity: Activity<PomodoroAttributes>?
    private var cancellables = Set<AnyCancellable>()
    private var notificationid: String = ""
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
    
    private let pomodoroPersistKey = "activePomodoroState"
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
            let notif = NotificationContent(
                title: "Pomodoro Finished",
                body: "Task '\(toDoTask.name)' is done!"
            )
            scheduleNotification(date: end, notification: notif)
        }
        NotificationCenter.default.post(name: .pomodoroStarted, object: nil)
        let dto = PomodoroDTO(
            startTime: startTime, endTime: endTime, toDoTask: toDoTask
        )
        ClarityWatchConnectivity.shared.sendPomodoroStarted(dto)
    }
    
    func endPomodoro() async {
        // Make idempotent: if already inactive, do nothing
        guard isActive else {
            LogManager.shared.log.error("Pomodoro is not active")
            return
        }

        // Mark inactive and clean up timer/activity/notification
        isActive = false

        if let t = timer {
            t.invalidate()
        }
        timer = nil

        stopLiveActivity()
        cancelNotification()
        clearPersistedState()
        
        // Post a single completion notification
        NotificationCenter.default.post(name: .pomodoroCompleted, object: nil)
        if startedDevice == .watchOS {
            if let task = toDoTask {
                LogManager.shared.log.debug("Sending Pomodoro Stopped with Task")
                await ClarityWatchConnectivity.shared.sendPomodoroStopped(task)
            }
        } else {
            LogManager.shared.log.debug("Sending Pomodoro Stopped without Task")
            await ClarityWatchConnectivity.shared.sendPomodoroStopped()
        }
    }
    
    @MainActor
    func restoreIfNeeded(container: ModelContainer, device: DeviceType) async {
        guard let data = appGroupDefaults()?.data(forKey: "pomodoroState") else {
            LogManager.shared.log.debug("No Pomodoro state to restore")
            return
        }
        do {
            let persisted = try JSONDecoder().decode(PersistedPomodoro.self, from: data)
            LogManager.shared.log.debug("Restoring Pomodoro with task: \(persisted.taskName ?? "Task Unknown")")
            guard persisted.endTime > Date() else {
                LogManager.shared.log.debug("Pomodoro already completed, not restoring")
                let store = ClarityModelActor(modelContainer: container)
                if let uuid = persisted.taskUUID {
                    try await store.completeTask(uuid)
                }
                clearPersistedState()
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
            if let existing = Activity<PomodoroAttributes>.activities.first {
                self.activity = existing
                LogManager.shared.log.debug("Attached to existing Live Activity")
            } else {
                LogManager.shared.log.debug("Could not find Live Activity, creating new one")
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
        guard let task = toDoTask else { return }
        guard let start = startTime, let end = endTime else { return }
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
            LogManager.shared.log.debug("SUCCESS: Live Activity started for task: \(task.name)")
        } catch {
            LogManager.shared.log.error("ERROR: Failed to start Live Activity: \(error.localizedDescription)")
        }
    }
    
    private func stopLiveActivity() {
        guard let activity = activity else { return }
        Task {
            await activity.end(ActivityContent(state: activity.content.state, staleDate: nil), dismissalPolicy: .immediate)
            LogManager.shared.log.debug("Stopped Live Activity")
        }
        self.activity = nil
    }
    
    // #MARK: Notifications
    
    private struct NotificationContent {
        var title: String
        var body: String
        var sound: UNNotificationSound = .default
    }
    
    private func scheduleNotification(date: Date, notification: NotificationContent) {
        let content = UNMutableNotificationContent()
        notificationid = UUID().uuidString
        content.title = notification.title
        content.body = notification.body
        content.sound = notification.sound
        content.userInfo = ["pomodoro": notificationid]
        
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date), repeats: false
        )
        
        let request = UNNotificationRequest(identifier: notificationid, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                LogManager.shared.log.error("Error scheduling notification: \(error)")
            } else {
                LogManager.shared.log.debug("Notification scheduled successfully for \(date.ISO8601Format())")
            }
        }
    }
    
    private func cancelNotification() {
        LogManager.shared.log.debug("Cancelling Notification")
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [notificationid])
        notificationid = ""
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

}

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
        guard let totalTime = toDoTask?.pomodoroTime else { return 0 }
        return 1.0 - (remainingTime / totalTime)
    }
    
    enum DeviceType {
        case iPhone
        case watchOS
    }
    
    // MARK: Public Functions
    
    func startPomodoro(for toDoTask: ToDoTaskDTO, container: ModelContainer, device: DeviceType) {
        startedDevice = device
        self.container = container
        self.toDoTask = toDoTask
        let now = Date()
        startTime = now
        endTime = Date(timeInterval: toDoTask.pomodoroTime, since: now)
        isActive = true
        startTimer()
        startLiveActivity()
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
            print("Pomodoro is not active")
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
        
        // Post a single completion notification
        NotificationCenter.default.post(name: .pomodoroCompleted, object: nil)
        if startedDevice == .watchOS {
            if let task = toDoTask {
                print("Sending Pomodoro Stopped with Task")
                ClarityWatchConnectivity.shared.sendPomodoroStopped(task)
            }
        } else {
            print("Sending Pomodoro Stopped without Task")
            ClarityWatchConnectivity.shared.sendPomodoroStopped()
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
            print("SUCCESS: Live Activity started for task: \(task.name)")
        } catch {
            print("ERROR: Failed to start Live Activity: \(error.localizedDescription)")
        }
    }
    
    private func stopLiveActivity() {
        guard let activity = activity else { return }
        Task {
            await activity.end(ActivityContent(state: activity.content.state, staleDate: nil), dismissalPolicy: .immediate)
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
                print("Error scheduling notification: \(error)")
            } else {
                print("Notification scheduled successfully")
            }
        }
    }
    
    private func cancelNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [notificationid])
        notificationid = ""
    }
    
    // MARK: Pomodoro Timer Function

    private func startTimer() {
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
}

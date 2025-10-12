//
//  PomodoroService.swift
//  Clarity
//
//  Created by Craig Peters on 11/10/2025.
//

import Foundation
import Combine
import ActivityKit
import UserNotifications
import SwiftData

final class PomodoroService: ObservableObject {
    static let shared = PomodoroService()
    
    var isActive: Bool = false
    @Published var endTime: Date?
    @Published var startTime: Date?
    @Published var toDoTask: ToDoTaskDTO?
    @Published var remainingTime: TimeInterval = 0
    @Published var progress: Double = 0
    
    public var formattedTime: String {
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
    private lazy var storeTask = Task.detached { [container] in
            await ClarityModelActorFactory.makeBackground(container: container!)
        }
    
    // MARK: Public Functions
    
    public func startPomodoro(for toDoTask: ToDoTaskDTO) {
        self.toDoTask = toDoTask
        let now = Date()
        self.startTime = now
        self.endTime = Date(timeInterval: toDoTask.pomodoroTime, since: now)
        self.isActive = true
        startTimer()
        startLiveActivity()
        if let end = self.endTime {
            let notif = NotificationContent(
                title: "Pomodoro Finished",
                body: "Task '\(toDoTask.name)' is done!"
            )
            scheduleNotification(date: end, notification: notif)
        }
        NotificationCenter.default.post(name: .pomodoroStarted, object: nil)
    }
    
    public func endPomodoro(container: ModelContainer) async {
        self.container = container
        let store = await storeTask.value
        guard let taskID = toDoTask?.id else { return }
        do {
            try await store.completeTask(taskID)
        } catch {
            // Handle or log the error so the app can continue cleanup gracefully
            print("ERROR: Failed to complete task with id \(taskID): \(error)")
        }
        NotificationCenter.default.post(name: .pomodoroCompleted, object: nil)
        stopLiveActivity()
        cancelNotification()

        // Clear local state
        self.isActive = false

    }
    
    // MARK: Live Activities
    
    private func startLiveActivity() {
        let attributes = PomodoroAttributes(sessionId: UUID().uuidString)
        guard let task = toDoTask else { return }
        guard let start = self.startTime, let end = self.endTime else { return }
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
        var sound: UNNotificationSound = UNNotificationSound.default
    }
    
    private func scheduleNotification(date: Date, notification: NotificationContent) {
        let content = UNMutableNotificationContent()
        self.notificationid = UUID().uuidString
        content.title = notification.title
        content.body = notification.body
        content.sound = notification.sound
        content.userInfo = ["pomodoro" : self.notificationid]
        
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date), repeats: false
        )
        
        let request = UNNotificationRequest(identifier: self.notificationid, content: content, trigger: trigger)
        
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
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            guard let remaining = self.calculatedRemainingTime else { return }
            self.remainingTime = remaining 
            self.progress = calculatedProgress
            
            if self.remainingTime <= 0 {
                self.isActive = false
                self.timer?.invalidate()
                NotificationCenter.default.post(name: .pomodoroCompleted, object: nil)
            }
            
            self.objectWillChange.send()
        }
    }
}

extension Notification.Name {
    static let pomodoroCompleted = Notification.Name("pomodoroCompleted")
    static let pomodoroStarted = Notification.Name("pomodoroStarted")
}


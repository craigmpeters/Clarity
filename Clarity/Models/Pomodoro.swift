//
//  Pomodoro.swift
//  Clarity
//
//  Created by Craig Peters on 17/08/2025.
//

import Foundation
import UserNotifications

class Pomodoro: ObservableObject {
    var endTime: Date?
    var interval: TimeInterval = 25 * 60 // TODO: Passed by task at some point
    @Published var taskTitle: String
    @Published var isRunning: Bool = false
    
    private var timer: Timer?
    private var notificationIdentifier: String?
    
    /// Provides the remaining time for the pomodoro task
    var remainingTime: TimeInterval {
        guard let endTime = endTime else { return interval }
        let remaining = endTime.timeIntervalSinceNow
        return max(0, remaining)
    }
    
    /// Percentage complete of the pomodoro
    var progress: Double {
        guard interval > 0 else { return 0 }
        return 1.0 - (remainingTime / interval)
    }
    
    /// Remaining time in Pomodoro in a human readable format
    var formattedTime: String {
        let time = remainingTime
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    init() {
        taskTitle = "Task Title not set"
    }
    
    /// Starts a pomodoro with tasKtitle being the title and description being notification description
    func startPomodoro(taskTitle: String, description: String) {
        // Stop any existing Pomodoro
        stopPomodoro()
        
        let notificationIdentifier = UUID().uuidString
        endTime = Date().addingTimeInterval(interval)
        isRunning = true
        
        // Content
        let content = UNMutableNotificationContent()
        content.title = taskTitle
        content.body = description
        content.sound = UNNotificationSound.default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(identifier: notificationIdentifier, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error)")
            } else {
                print("Notification scheduled successfully")
            }
        }
        
        startUITimer()
    }
    
    func stopPomodoro() {
        isRunning = false
        timer?.invalidate()
        endTime = nil
        if let identifier = notificationIdentifier {
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
        }
    }
    
    private func startUITimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            if self.remainingTime <= 0 {
                self.isRunning = false
                self.timer?.invalidate()
                self.endTime = nil
            }
            
            // This will trigger UI updates via @Published
            self.objectWillChange.send()
        }
    }
}

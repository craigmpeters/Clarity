//
//  Pomodoro.swift
//  Clarity
//
//  Created by Craig Peters on 17/08/2025.
//

import Foundation
import UserNotifications

class Pomodoro  : ObservableObject {
    
    var endTime : Date?
    var interval : TimeInterval = 25 * 60
    @Published var taskTitle : String
    
    init() {
        taskTitle = "Task Title not set"
    }
    
    func startPomodoro(title : String, description: String) {
        let taskTitle = title
        let uuidString = UUID().uuidString
        endTime = Date().addingTimeInterval(interval)
        
        // Content
        let content = UNMutableNotificationContent()
        content.title = taskTitle
        content.body = description
        content.sound = UNNotificationSound.default
        
        // Todo: Change to 25 Minutes
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        
        let request = UNNotificationRequest(identifier: uuidString, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error)")
            } else {
                print("Notification scheduled successfully")
            }
        }
        
    }
}

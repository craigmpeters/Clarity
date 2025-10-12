//// ============================================
//// Pomodoro.swift - Fixed notification issue
//// ============================================
//
//import Foundation
//import UserNotifications
//
//class Pomodoro: ObservableObject {
//    var endTime: Date?
//    var interval: TimeInterval
//    @Published var taskTitle: String
//    @Published var isRunning: Bool = false
//    @Published var currentRemainingTime: TimeInterval = 0  // Add this
//    @Published var currentProgress: Double = 0            // Add this
//    
//    private var timer: Timer?
//    private var notificationIdentifier: String?
//    
//    /// Provides the remaining time for the pomodoro task
//    var remainingTime: TimeInterval {
//        guard let endTime = endTime else { return interval }
//        let remaining = endTime.timeIntervalSinceNow
//        return max(0, remaining)
//    }
//    
//    /// Percentage complete of the pomodoro
//    var progress: Double {
//        guard interval > 0 else { return 0 }
//        return 1.0 - (remainingTime / interval)
//    }
//    
//    /// Remaining time in Pomodoro in a human readable format
//    var formattedTime: String {
//        let time = remainingTime
//        let minutes = Int(time) / 60
//        let seconds = Int(time) % 60
//        
//        return String(format: "%02d:%02d", minutes, seconds)
//    }
//    
//    init() {
//        taskTitle = "Task Title not set"
//        interval = 25 * 60
//    }
//    
//    /// Starts a pomodoro with taskTitle being the title and description being notification description
//    func startPomodoro(task: ToDoTaskDTO, description: String, interval: TimeInterval) { // To Do: Description on Task
//        guard (task.name != nil) else { return }
//        print("Pomodoro for task \(String(describing: task.name)) started (interval: \(interval))")
//        // Stop any existing Pomodoro
//        stopPomodoro()
//        
//        // FIX: Store the identifier in the instance variable
//        let identifier = UUID().uuidString
//        self.interval = interval
//        self.notificationIdentifier = identifier  // Store in instance variable
//        self.taskTitle = task.name  // Also update the task title
//        endTime = Date().addingTimeInterval(interval)
//        isRunning = true
//        
//        // Content
//        let content = UNMutableNotificationContent()
//        content.title = taskTitle
//        content.body = description
//        content.sound = UNNotificationSound.default
//        content.userInfo = ["pomodoro": true]
//        
//        let trigger = UNCalendarNotificationTrigger(
//            dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second],
//                                                          from: endTime!),
//            repeats: false
//        )
//        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
//        
//        UNUserNotificationCenter.current().add(request) { error in
//            if let error = error {
//                print("Error scheduling notification: \(error)")
//            } else {
//                print("Notification scheduled successfully")
//            }
//        }
//        startUITimer()
//    }
//    
//    func stopPomodoro() {
//        isRunning = false
//        timer?.invalidate()
//        endTime = nil
//        if let identifier = notificationIdentifier {
//            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
//        }
//        notificationIdentifier = nil  // Clear the identifier
//        
//    }
//    
//    private func startUITimer() {
//        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
//            guard let self = self else { return }
//            
//            let remaining = self.remainingTime
//            self.currentRemainingTime = remaining  // Update published property
//            self.currentProgress = self.progress  
//            
//            if self.remainingTime <= 0 {
//                self.isRunning = false
//                self.timer?.invalidate()
//                // DON'T set endTime = nil here
//                
//                // Post completion notification
//                //NotificationCenter.default.post(name: .pomodoroCompleted, object: nil)
//            }
//            
//            self.objectWillChange.send()
//        }
//    }
//}
//
//
//
//

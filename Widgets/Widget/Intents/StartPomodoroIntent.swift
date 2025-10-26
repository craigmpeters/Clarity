//
//  StartPomodoroIntent.swift
//  Clarity
//
//  Created by Craig Peters on 03/09/2025.
//

import Foundation
import AppIntents
import SwiftData

struct StartPomodoroIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Pomodoro"
    static var description = IntentDescription("Start a pomodoro timer for a task")
    static var openAppWhenRun: Bool = true // We want to open the app to show the timer
    
    @Parameter(title: "Task ID")
    var taskId: String
    
    // Initialize with taskId for widget usage
    init(taskId: String) {
        self.taskId = taskId
    }
    
    // Default initializer required by AppIntent
    init() {
        self.taskId = ""
    }
    
    func perform() async throws -> some IntentResult & OpensIntent {
        print("Widget: Starting pomodoro for task ID: \(taskId)")
        
        // Store the task ID for the app to pick up when it opens
        UserDefaults.shared.set(taskId, forKey: "pendingPomodoroTaskId")
        UserDefaults.shared.set(true, forKey: "shouldStartPomodoroFromWidget")
        
        // Return an intent that opens the app
        return .result(opensIntent: OpenAppIntent())
    }
}

// Extension to use App Groups for sharing data
extension UserDefaults {
    static let shared = UserDefaults(suiteName: "group.me.craigpeters.clarity")!
}

// Simple intent to open the app
struct OpenAppIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Clarity"
    
    func perform() async throws -> some IntentResult {
        return .result()
    }
}

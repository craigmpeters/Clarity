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
    static var title: LocalizedStringResource = "Start Timer"
    static var description = IntentDescription("Start a timer for a task")
    static var openAppWhenRun: Bool = true // Foreground the app; navigation handled by intent-driven routing
    private var taskUuid: String?

    @Parameter(title: "Task")
    var task: TaskEntity

    init() {} // required
    
    init(id: UUID) {
        self.taskUuid = id.uuidString
    }

    @MainActor
    func perform() async throws -> some IntentResult & OpensIntent {
        
        // group.me.craigpeters.clarity
        print("Debug Start Pomodoro")
        // Resolve the task ID from either the initializer override or the bound parameter
        let taskId: UUID? = {
            if let taskUuid, let u = UUID(uuidString: taskUuid) {
                return u
            }
            return UUID(uuidString: task.id)
        }()
        
        print("\(taskId?.uuidString ?? "No UUID found")")
        

        guard let taskId else {
            throw NSError(domain: "StartTimerIntent", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid task id"])
        }
        let defaults = UserDefaults(suiteName: "group.me.craigpeters.clarity")
        defaults?.set(taskId.uuidString, forKey: "pendingStartTimerTaskId")

        // The app should read the incoming AppIntent parameters to navigate to the Timer screen
        return .result()
    }
}

// Simple intent to open the app
struct OpenAppIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Clarity"
    
    func perform() async throws -> some IntentResult {
        return .result()
    }
}


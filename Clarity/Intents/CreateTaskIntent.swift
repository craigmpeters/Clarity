//
//  CreateTaskIntent.swift
//  Clarity
//
//  Created by Craig Peters on 30/08/2025.
//

import Foundation
import AppIntents

struct CreateTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "Create Task"
    static var description = IntentDescription("Create a new task in Clarity")
    static var openAppWhenRun: Bool = false
    
    @Parameter(title: "Task Name")
    var taskName : String
    
    // ToDo: Settings
    @Parameter(title: "Duration (Minutes)", default: 5)
    var duration : Int
    
    @Parameter(title: "Repeating Task?", default: false)
    var isRepeating: Bool
    
    func perform() async throws -> some IntentResult {
        let newTask = ToDoTask(name: taskName)
        newTask.pomodoroTime = TimeInterval(duration * 60)
        newTask.repeating = isRepeating
        
        return .result()
    }
    
}

struct ClarityShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CreateTaskIntent(),
            phrases: [
                "Create a task in \(.applicationName)",
                "Add a new task in \(.applicationName)",
                "New task in \(.applicationName)"
            ],
            shortTitle: "New Task",
            systemImageName: "plus.circle"
        )
    }
}

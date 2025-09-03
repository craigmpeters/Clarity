//
//  CompleteTaskIntents.swift
//  Clarity
//
//  Created by Craig Peters on 03/09/2025.
//

//
//  CompleteTaskIntent.swift
//  Clarity
//
//  Created by Craig Peters on 03/09/2025.
//

import Foundation
import AppIntents
import SwiftData

struct CompleteTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "Complete Task"
    static var description = IntentDescription("Mark a task as completed")
    static var openAppWhenRun: Bool = false
    
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
    
    func perform() async throws -> some IntentResult {
        print("Widget: Attempting to complete task with ID: \(taskId)")
        
        // Use the WidgetDataActor to complete the task
        await WidgetDataActor.shared.completeTask(taskId: taskId)
        
        return .result()
    }
}

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
import OSLog

struct CompleteTaskIntent: AppIntent {
    private let log = Logger(subsystem: "me.craigpeters.clarity", category: "Widget")
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
    
    func perform() async throws -> some IntentResult & ProvidesDialog {
        log.debug("Widget: Attempting to complete task with ID: \(taskId)")
        
        // Use the WidgetDataActor to complete the task
        guard let task = try await StaticDataStore.shared.fetchTaskById(taskId) else {
            return .result(dialog: "Task not found")
        }
        await StaticDataStore.shared.completeTask(task)
        
        return .result(dialog: "Task completed")
    }
}

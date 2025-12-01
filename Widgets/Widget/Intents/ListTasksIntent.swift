//
//  ListTasksIntent.swift
//  Clarity
//
//  Created by Craig Peters on 01/12/2025.
//

import Foundation
import AppIntents


// MARK: - The Intent that lists tasks
struct ListTasksIntent: AppIntent {
    static var title: LocalizedStringResource = "List Tasks"
    static var description = IntentDescription("Returns a list of your tasks")

    
    @Parameter(title: "Only Repeating Tasks", default: false)
    var repeatingOnly: Bool
    
    @Parameter(title: "Only Overdue", default: false)
    var onlyOverdue: Bool


    func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<[TaskEntity]> {
        let now = Date()
        let tasks = try await TaskQuery().allEntities()
        var filtered = tasks
        if repeatingOnly {
            filtered = filtered.filter { $0.repeating }
        }
        if onlyOverdue {
            filtered = filtered.filter { task in
                return task.date < now
            }
        }
        return .result(value: filtered, dialog: "Clarity Tasks")
    }
}

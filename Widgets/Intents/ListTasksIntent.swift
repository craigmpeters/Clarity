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
    
    @Parameter(title: "Filter", default: .today)
    var filter: ToDoTask.TaskFilterOption


    func perform() async throws -> some IntentResult & ReturnsValue<[TaskEntity]> {
        let tasks = try await TaskQuery().entities(matching: filter)
        var filtered = tasks
        if repeatingOnly {
            filtered = filtered.filter { $0.repeating }
        }
        return .result(value: filtered)
    }
}

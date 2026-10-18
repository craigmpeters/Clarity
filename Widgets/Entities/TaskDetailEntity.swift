//
//  TaskDetailEntity.swift
//  Clarity
//
//  Created by Craig Peters on 05/04/2026.
//

import AppIntents
import Foundation

struct TaskDetailEntity: TransientAppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Task Detail"

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }

    @Property(title: "ID") var id: String
    @Property(title: "Name") var name: String
    @Property(title: "Due Date") var due: Date
    @Property(title: "Created") var created: Date
    @Property(title: "Repeating") var repeating: Bool
    @Property(title: "Recurrence") var recurrence: String?
    @Property(title: "Pomodoro Duration (seconds)") var pomodoroTime: Double
    @Property(title: "Categories") var categories: [String]
    @Property(title: "Last Completed At") var lastCompletedAt: Date?

    init() {}

    init(from dto: ToDoTaskDTO, lastCompletedAt: Date? = nil) {
        id = dto.uuid.uuidString
        name = dto.name
        due = dto.due
        created = dto.created
        repeating = dto.repeating
        recurrence = dto.recurrenceInterval?.displayName
        pomodoroTime = dto.pomodoroTime
        categories = dto.categories.map { $0.name }
        self.lastCompletedAt = lastCompletedAt
    }
}

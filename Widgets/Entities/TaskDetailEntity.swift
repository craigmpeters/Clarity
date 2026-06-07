//
//  TaskDetailEntity.swift
//  Clarity
//
//  Created by Craig Peters on 05/04/2026.
//

import AppIntents
import Foundation

struct TaskDetailEntity: TransientAppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Task Detail"

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
        self.id = dto.uuid.uuidString
        self.name = dto.name
        self.due = dto.due
        self.created = dto.created
        self.repeating = dto.repeating
        self.recurrence = dto.recurrenceInterval?.displayName
        self.pomodoroTime = dto.pomodoroTime
        self.categories = dto.categories.map { $0.name }
        self.lastCompletedAt = lastCompletedAt
    }
}

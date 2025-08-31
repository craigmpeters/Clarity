//
//  Todo.swift
//  Clarity
//
//  Created by Craig Peters on 17/08/2025.
//

import Foundation
import SwiftData

@Model
class ToDoTask {
    var name: String
    var created: Date
    var due: Date
    var pomodoro: Bool
    var pomodoroTime: TimeInterval
    var repeating: Bool
    @Relationship var categories: [Category] = []
    
    // TODO: Tags
    
    func friendlyDue() -> String {
        switch due {
        case let date where Calendar.current.isDateInToday(date):
            return "Today"
        case let date where Calendar.current.isDateInTomorrow(date):
            return "Tomorrow"
        case let date where Calendar.current.isDateInYesterday(date):
            return "Yesterday"
        default:
            let dateFormatter = DateFormatter()
            dateFormatter.setLocalizedDateFormatFromTemplate("MMMMd")
            return dateFormatter.string(from: due)
        }
    }
    
    init(name: String, pomodoro: Bool = true, pomodoroTime: TimeInterval = 25 * 60, repeating: Bool = false, due: Date = Date.now, categories: [Category] = []) {
        self.name = name
        self.created = Date.now
        self.due = due
        self.pomodoro = true // No longer an option
        self.pomodoroTime = pomodoroTime
        self.repeating = repeating
        self.categories = categories
    }
}

@Observable
class ToDoStore {
    private var modelContext: ModelContext
    var toDoTasks: [ToDoTask] = []
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        loadToDoTasks()
    }
    
    func addTodoTask(toDoTask: ToDoTask) {
        guard !toDoTask.name.isEmpty else { return }
        modelContext.insert(toDoTask)
        saveContext()
        loadToDoTasks()
    }
    
    func scheduleTomorrow(toDoTask: ToDoTask) {
        guard !toDoTask.name.isEmpty else { return }
        toDoTask.due =  Date.now.addingTimeInterval(60 * 60 * 24)
        saveContext()
        loadToDoTasks()
    }
    
    func deleteToDoTask(toDoTask: ToDoTask) {
        modelContext.delete(toDoTask)
        saveContext()
        loadToDoTasks()
    }
    
    func loadToDoTasks() {
        do {
            let descriptor = FetchDescriptor<ToDoTask>(
                sortBy: [SortDescriptor(\.created, order:.reverse)]
            )
            toDoTasks = try modelContext.fetch(descriptor)
        } catch {
            print("Failed to load tasks: \(error.localizedDescription)")
        }
    }
    
    func saveContext() {
        do {
            try modelContext.save()
        } catch {
            print("Failed to save context: \(error.localizedDescription)")
        }
    }
    
    
    
}

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
    
    // TODO: Created, Due, Type, Tags
    
    var friendlyDue: String {
        // Today
        if Calendar.current.isDateInToday(due) {
            return "Today"
        } else {
            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale(identifier: Locale.current.identifier)
            dateFormatter.setLocalizedDateFormatFromTemplate("MMMMd")
            return dateFormatter.string(from: due)
        }
     }
    
    init(name: String, pomodoro: Bool, pomodoroTime: TimeInterval) {
        self.name = name
        self.created = Date.now
        self.due = Date.now
        self.pomodoro = pomodoro
        self.pomodoroTime = pomodoroTime
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
    
    func deleteToDoTask(toDoTask: ToDoTask) {
        modelContext.delete(toDoTask)
        saveContext()
        loadToDoTasks()
    }
    
    private func loadToDoTasks() {
        do {
            let descriptor = FetchDescriptor<ToDoTask>(
                sortBy: [SortDescriptor(\.created, order:.reverse)]
            )
            toDoTasks = try modelContext.fetch(descriptor)
        } catch {
            print("Failed to load tasks: \(error.localizedDescription)")
        }
    }
    
    private func saveContext() {
        do {
            try modelContext.save()
        } catch {
            print("Failed to save context: \(error.localizedDescription)")
        }
    }
    
    
    
}

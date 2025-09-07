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
    var completed: Bool
    var completedAt: Date?
    var recurrenceInterval: RecurrenceInterval?
    var customRecurrenceDays: Int = 1
    
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
    
    var recurrenceDescription: String? {
        guard repeating, let interval = recurrenceInterval else { return nil }
        
        if interval == .custom {
            if customRecurrenceDays == 1 {
                return "Daily"
            } else {
                return "Every \(customRecurrenceDays) days"
            }
        }
        return interval.displayName
    }
    
    init(name: String, pomodoro: Bool = true, pomodoroTime: TimeInterval = 25 * 60, repeating: Bool = false, recurrenceInterval: RecurrenceInterval? = nil, customRecurrenceDays: Int = 1, due: Date = Date.now, categories: [Category] = []) {
        self.name = name
        self.created = Date.now
        self.due = due
        self.pomodoro = true // No longer an option
        self.pomodoroTime = pomodoroTime
        self.repeating = repeating
        self.categories = categories
        self.completed = false
        self.recurrenceInterval = recurrenceInterval
        self.customRecurrenceDays = customRecurrenceDays
    }
    
    enum RecurrenceInterval: String, CaseIterable, Codable {
        case daily = "Daily"
        case everyOtherDay = "Every Other Day"
        case weekly = "Weekly"
        case biweekly = "Biweekly"
        case monthly = "Monthly"
        case custom = "Custom"
        
        var displayName: String {
            return rawValue
        }
        
        func nextDate(from date: Date) -> Date {
            let calendar = Calendar.current
            switch self {
            case .daily:
                return calendar.date(byAdding: .day, value: 1, to: date) ?? date
            case .everyOtherDay:
                return calendar.date(byAdding: .day, value: 2, to: date) ?? date
            case .weekly:
                return calendar.date(byAdding: .weekOfYear, value: 1, to: date) ?? date
            case .biweekly:
                return calendar.date(byAdding: .weekOfYear, value: 2, to: date) ?? date
            case .monthly:
                return calendar.date(byAdding: .month, value: 1, to: date) ?? date
            case .custom:
                // For custom, we'll use the customRecurrenceDays property
                return date
            }
        }
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
    
    func createNextOccurrence(from task: ToDoTask) -> ToDoTask {
        let nextDueDate: Date
        
        if let interval = task.recurrenceInterval {
            if interval == .custom {
                nextDueDate = Calendar.current.date(
                    byAdding: .day,
                    value: task.customRecurrenceDays,
                    to: Date.now
                ) ?? task.due
            } else {
                nextDueDate = interval.nextDate(from: Date.now)
            }
        } else {
            // Fallback to daily if no interval set
            nextDueDate = Calendar.current.date(byAdding: .day, value: 1, to: task.due) ?? task.due
        }
        
        let newTask = ToDoTask(
            name: task.name,
            pomodoroTime: task.pomodoroTime,
            repeating: true,
            recurrenceInterval: task.recurrenceInterval,
            customRecurrenceDays: task.customRecurrenceDays,
            due: nextDueDate,
            categories: task.categories
        )
        
        return newTask
    }
    
    // Complete ToDoTask when it is something where it is done
    func completeToDoTask(toDoTask: ToDoTask) {
        toDoTask.completed = true
        toDoTask.completedAt = Date.now
        if toDoTask.repeating {
            let nextTask = createNextOccurrence(from: toDoTask)
            modelContext.insert(nextTask)
        }
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
                predicate: #Predicate { !$0.completed },
                sortBy: [SortDescriptor(\.due, order: .forward)]
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
    
    let descriptor = FetchDescriptor<ToDoTask>(
        predicate: #Predicate { !$0.completed },
        sortBy: [SortDescriptor(\.due, order: .forward)]
    )
    
    enum TaskFilter: String, CaseIterable {
        case all = "All Tasks"
        case overdue = "Overdue"
        case today = "Today"
        case tomorrow = "Tomorrow"
        case thisWeek = "This Week"
        
        func matches(task: ToDoTask) -> Bool {
            switch self {
            case .all:
                return true
            case .overdue:
                return task.due < Calendar.current.startOfDay(for: Date())
            case .today:
                return Calendar.current.isDateInToday(task.due)
            case .tomorrow:
                return Calendar.current.isDateInTomorrow(task.due)
            case .thisWeek:
                let startOfWeek = Calendar.current.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
                let endOfWeek = Calendar.current.dateInterval(of: .weekOfYear, for: Date())?.end ?? Date()
                return task.due >= startOfWeek && task.due <= endOfWeek
            }
        }
    }
}

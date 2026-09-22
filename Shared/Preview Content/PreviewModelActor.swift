//
//  PreviewContainer.swift
//  Clarity
//
//  Created by Craig Peters on 22/09/2025.
//
import SwiftData
import Foundation

@MainActor
final class PreviewData {
    
    static let shared = PreviewData()
    
    let previewContainer = try! Containers.inMemory()
    
    var previewContext: ModelContext {
        previewContainer.mainContext
    }
    
    private init() {
        UITestDataSeeder.seed(in: previewContainer)
    }
    
    // MARK: Public Functions
    
    func getCategories() -> [Category] {
        do {
            let descriptor = FetchDescriptor<Category>()
            return try previewContext.fetch(descriptor)
        } catch {
            print("Failed to fetch categories: \(error)")
            return []
        }
    }
    
    func getCategoriesDTO() -> [CategoryDTO] {
        let categories = getCategories()
        return categories.map { CategoryDTO(from: $0) }
    }
    
    func getCategory() -> Category {
        return getCategories().first!
    }
    
    func getToDoTasks() -> [ToDoTask] {
        do {
            let descriptor = FetchDescriptor<ToDoTask>(
                predicate: #Predicate { !$0.completed },
                sortBy: [SortDescriptor(\.due, order: .forward)]
            )
            return try previewContext.fetch(descriptor)
        } catch {
            print("Failed to fetch tasks: \(error)")
            return []
        }
    }
    
    func getHabits() -> [Habit] {
        do {
            let descriptor = FetchDescriptor<Habit>()
            return try previewContext.fetch(descriptor)
        } catch {
            print("Failed to fetch habits: \(error)")
            return []
        }
    }
    
    func getCompletedTasks(filter: ToDoTask.CompletedTaskFilter = .Month) -> [ToDoTask] {
        do {
            let descriptor = FetchDescriptor<ToDoTask>(
                predicate: #Predicate { $0.completed },
                sortBy: [SortDescriptor(\.due, order: .forward)]
            )
            let allTasks = try previewContext.fetch(descriptor)
            return allTasks.filter { $0.completed }
        } catch {
            print("Failed to fetch tasks: \(error)")
            return []
        }
    }
    
    // MARK: Individual Task Functions
    
    func getToDoTask() -> ToDoTask {
        return getToDoTasks().first!
    }
    
    func getOverDueToDoTask() -> ToDoTask {
        let task = getToDoTasks().first!
        task.due = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        return task
    }
    
    func getTaskWithManyCategories() -> ToDoTask {
        let task = getToDoTask()
        task.categories = getCategories()
        return task
    }
    
    // MARK: Preview Helper Functions
    
    func makeEveryMonday(_ task: ToDoTask) -> ToDoTask {
        task.repeating = true
        task.recurrenceInterval = .specific
        task.everySpecificDayDay = 1
        return task
    }
    
    func toToDoTaskDTO(from task: ToDoTask) -> ToDoTaskDTO {
        return ToDoTaskDTO(from: task)
    }
    
    func getToDoTaskDTO() -> ToDoTaskDTO {
        return ToDoTaskDTO(from: getToDoTasks().first!)
    }
    
    func getPreviewTaskWidgetEntry() -> TaskWidgetEntry {
        let tasks = getToDoTasks()
        let dtos: [ToDoTaskDTO] = tasks.map { ToDoTaskDTO(from: $0) }
        let target = returnPreviewWeeklyProgress()
        let option: ToDoTask.TaskFilterOption = .all
        let showWeeklyTarget = Bool.random()
        return TaskWidgetEntry(date: Date.now, todos: dtos, progress: target, filter: option, showWeeklyProgress: showWeeklyTarget)
    }
    
    func getPreviewLimitedTasksEntry() -> TaskWidgetEntry {
        var entry = getPreviewTaskWidgetEntry()
        entry.todos = Array(entry.todos.prefix(3))
        return entry
    }
    
    func getPreviewWatchWidgetDueEntry() -> WatchDueEntry {
        let tasks = getToDoTasks().map { ToDoTaskDTO(from: $0) }
        return WatchDueEntry(date: .now, todos: tasks, filter: .all, progress: returnPreviewWeeklyProgress())
    }
    
    func getPreviewWatchWidgetCompleteEntry() -> WatchCompleteEntry {
        let tasks = getToDoTasks().map { ToDoTaskDTO(from: $0) }
        return WatchCompleteEntry(date: .now, todos: tasks, filter: .Today, progress: returnPreviewWeeklyProgress())
    }
    
    func getPreviewWatchWidgetCompleteNoTargetEntry() -> WatchCompleteEntry {
        let tasks = getToDoTasks().map { ToDoTaskDTO(from: $0) }
        return WatchCompleteEntry(date: .now, todos: tasks, filter: .PastWeek, progress: WeeklyProgress(completed: 2, target: 0, error: nil, categories: []))
    }
    
    /// Scattered completions across the last 60 days for heatmap widget previews.
    var sampleHeatmapTasks: [ToDoTaskDTO] {
        let now = Date()
        let calendar = Calendar.current
        let samples: [(daysAgo: Int, secondsLate: TimeInterval, recurrence: ToDoTask.RecurrenceInterval?)] = [
            (0,  0,           .daily),
            (0,  3600,        .daily),
            (1,  0,           .weekly),
            (2,  12 * 3600,   .daily),
            (4,  3.5 * 86400, .weekly),
            (5,  86400,       .daily),
            (7,  7 * 86400,   .weekly),
            (10, -3600,       nil),
            (12, 3 * 86400,   nil),
            (20, 0,           .monthly),
            (25, 5 * 86400,   .weekly),
            (30, 0,           .daily),
            (35, 86400,       .daily),
            (40, 0,           .weekly),
            (50, 0,           .daily),
            (55, 0,           .daily),
            (58, 12 * 3600,   .daily),
            (59, 0,           .daily)
        ]
        return samples.map { s in
            let due = calendar.date(byAdding: .day, value: -s.daysAgo, to: now) ?? now
            return ToDoTaskDTO(
                name: "Morning run",
                repeating: s.recurrence != nil,
                recurrenceInterval: s.recurrence,
                due: due,
                completed: true,
                completedAt: due.addingTimeInterval(s.secondsLate)
            )
        }
    }

    func getPreviewCompletedTaskEntry(filter: ToDoTask.CompletedTaskFilter) -> CompletedTaskEntry {
        let tasks = getCompletedTasks()
        let target = returnPreviewWeeklyProgress()
        let categories = getCategoriesDTO()
        let showWeeklyProgress = Bool.random()
        let dtos: [ToDoTaskDTO] = tasks.map { ToDoTaskDTO(from: $0) }
        let filtered = dtos.filter { filter.matches($0) }
        print("Total Tasks \(tasks.count)")
        print("Total Filtered: \(filtered.count)")
        print("Total DTOs \(dtos.count)")
        print("Filtered tasks: \(dtos.count)")
        return CompletedTaskEntry(date: Date.now, tasks: filtered, categories: categories, progress: target, filter: filter, showWeeklyProgress: showWeeklyProgress)
    }
    
    // MARK: Private Helpers
    
    private func returnPreviewWeeklyProgress() -> WeeklyProgress {
        return WeeklyProgress(completed: 2, target: 10, error: nil, categories: [])
    }
}

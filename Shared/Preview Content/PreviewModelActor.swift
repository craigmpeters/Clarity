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
    
    // Private Init as Singleton
    private init() {
        insertPreviewCategories()
        insertPreviewTasks()
        insertPreviewGlobalTarget()
        insertTaskSwipeAndTapOptions()
        insertPreviewAddStatistics()
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
    
    func getCompletedTasks(filter: ToDoTask.CompletedTaskFilter = .AllTime) -> [ToDoTask] {
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
    
    func getTargets() -> GlobalTargetSettings? {
        do {
            let descriptor = FetchDescriptor<GlobalTargetSettings>()
            return try previewContext.fetch(descriptor).first!
        } catch {
            return nil
        }
    }
    
    // #MARK: Individual Task Functions
    
    func getToDoTask() -> ToDoTask {
        return getToDoTasks().first!
    }
    
    func getOverDueToDoTask() -> ToDoTask{
        let task =  getToDoTasks().first!
        task.due =  Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        return task
    }
    
    func getTaskWithManyCategories() -> ToDoTask{
        let task = getToDoTask()
        task.categories = getCategories()
        return task
    }
    
    
    // #MARK: Preview Helper Functions
    
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
    
    func getPreviewCompletedTaskEntry(filter: ToDoTask.CompletedTaskFilter) -> CompletedTaskEntry {
        let tasks = getCompletedTasks()
        let target = returnPreviewWeeklyProgress()
        let showWeeklyProgress = Bool.random()
        print("Total Tasks \(tasks.count)")
        let dtos: [ToDoTaskDTO] = tasks.map { ToDoTaskDTO(from: $0)}
        var filtered : [ToDoTaskDTO]
        filtered = dtos.filter{ filter.matches($0)}
        print("Total Filtered: \(filtered.count)")
        print ("Total DTOs \(dtos.count)")
        print("Filtered tasks: \(dtos.count)")

        return CompletedTaskEntry(date: Date.now, tasks: filtered, progress: target, filter: filter, showWeeklyProgress: showWeeklyProgress)
    }
    
    // MARK: Functions to insert Preview Data
    
    private func returnPreviewWeeklyProgress() -> WeeklyProgress{
        return WeeklyProgress(completed: 2, target: 10, error: nil, categories: [])
    }
    
    private func insertPreviewCategories(){
        let categories = [
            Category(name: "Work", color: .Blue, weeklyTarget: 8),
            Category(name: "Personal", color: .Green, weeklyTarget: 5),
            Category(name: "Learning", color: .Purple, weeklyTarget: 3),
            Category(name: "Health", color: .Red, weeklyTarget: 7),
            Category(name: "Creative", color: .Orange, weeklyTarget: 2),
            Category(name: "Urgent", color: .Yellow, weeklyTarget: 0),
            Category(name: "Planning", color: .Cyan, weeklyTarget: 2)
        ]
        
        for category in categories {
            previewContext.insert(category)
        }
        
        saveContext()
    }
    
    private func insertPreviewTasks(){
        // Get existing categories or create basic ones
        let categories = getCategories()
        if categories.isEmpty {
            insertPreviewCategories()
        }

        let workCategory = categories.first { $0.name == "Work" }
        let personalCategory = categories.first { $0.name == "Personal" }
        let learningCategory = categories.first { $0.name == "Learning" }
        
        let sampleTasks = [
            // Overdue tasks
            ("Review quarterly reports", 5, Date().addingTimeInterval(-86400), [workCategory].compactMap { $0 }),
            
            // Today's tasks
            ("Team standup meeting prep", 5, Date(), [workCategory].compactMap { $0 }),
            ("Grocery shopping", 5, Date(), [personalCategory].compactMap { $0 }),
            ("SwiftUI documentation reading", 5, Date(), [learningCategory].compactMap { $0 }),
            
            // Tomorrow's tasks
            ("Client presentation slides", 5, Date().addingTimeInterval(86400), [workCategory].compactMap { $0 }),
            ("Doctor appointment", 5, Date().addingTimeInterval(86400), [personalCategory].compactMap { $0 }),
            
            // This week
            ("Code review session", 5, Date().addingTimeInterval(86400 * 2), [workCategory].compactMap { $0 }),
            ("Weekend hiking preparation", 5, Date().addingTimeInterval(86400 * 3), [personalCategory].compactMap { $0 }),
            ("iOS 18 features research", 5, Date().addingTimeInterval(86400 * 4), [learningCategory].compactMap { $0 }),
        ]
        
        for (name, minutes, dueDate, taskCategories) in sampleTasks {
            let task = ToDoTask(
                name: name,
                pomodoroTime: TimeInterval(minutes * 60),
                due: dueDate,
                everySpecificDayDay: nil,
                categories: taskCategories
            )
            previewContext.insert(task)
        }
        
        let task = ToDoTask(
            name: "Completed",
            pomodoroTime: TimeInterval(1000),
            due: Date(),
            everySpecificDayDay: nil,
            categories: []
        )
        task.completed = true
        task.completedAt = Date()
        previewContext.insert(task)
        saveContext()
    }
    
    private func insertPreviewGlobalTarget() {
        let settings = GlobalTargetSettings()
        settings.weeklyGlobalTarget = 10
        previewContext.insert(settings)
        saveContext()
    }
    
    private func insertPreviewAddStatistics() {
        let calendar = Calendar.current
        let now = Date()
        
        // Add completed tasks for the past week
        for dayOffset in 0..<30 {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: now) else { continue }
            
            let taskCount = Int.random(in: 1...3)
            for taskIndex in 0..<taskCount {
                let category = getCategories().randomElement()!
                let task = ToDoTask(
                    name: "Stats Task \(dayOffset)-\(taskIndex)",
                    pomodoroTime: TimeInterval(5 * 60),
                    due: date,
                    categories: [category]
                )
                task.completed = true
                task.completedAt = date.addingTimeInterval(Double.random(in: 0...86400))
                previewContext.insert(task)
            }
        }
        
        saveContext()
    }
    
    private func insertTaskSwipeAndTapOptions() {
        let swipeOptions = TaskSwipeAndTapOptions()
        previewContext.insert(swipeOptions)
    }
    
    
    private func saveContext() {
        do {
            try previewContext.save()
        } catch {
            print("Failed to save context: \(error)")
        }
    }
}


//
//  ClarityModelActor.swift
//  Clarity
//
//  Created by Craig Peters on 02/10/2025.
//

import SwiftData
import Foundation
import WidgetKit

@ModelActor
actor ClarityModelActor {
    
    // MARK: Category Functions
    
    func addCategory(_ dto: CategoryDTO) throws  -> CategoryDTO {
        let category = Category(
            name: dto.name,
            color: dto.color,
            weeklyTarget: dto.weeklyTarget)
        modelContext.insert(category)
        try modelContext.save()
        WidgetCenter.shared.reloadTimelines(ofKind: "TodoWidget")
        return CategoryDTO(from: category)
    }
    
    func updateCategory(_ dto: CategoryDTO) throws -> CategoryDTO {
        guard let id = dto.id else {
            throw NSError(domain: "ClarityActor", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing PersistentIdentifier"])
        }
        guard let model = modelContext.model(for: id) as? Category else {
            throw NSError(domain: "ClarityActor", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to cast to Category"])
        }
        model.name = dto.name
        model.color = dto.color
        model.weeklyTarget = dto.weeklyTarget
        try modelContext.save()
        WidgetCenter.shared.reloadTimelines(ofKind: "ClarityTaskWidget")
        return CategoryDTO(from: model)
    }
    
    func deleteCategory(_ id: PersistentIdentifier) throws {
        if let model = modelContext.model(for: id) as? Category {
            modelContext.delete(model)
            try modelContext.save()
        }
        WidgetCenter.shared.reloadTimelines(ofKind: "ClarityTaskWidget")
    }
    
    func getCategories() throws -> [CategoryDTO] {
        let descriptor = FetchDescriptor<Category>()
        let categories = try modelContext.fetch(descriptor)
        return categories.map(CategoryDTO.init(from:))
    }
    
    // MARK: Task Functions
    func fetchTasks(filter: ToDoTask.TaskFilter) throws -> [ToDoTaskDTO] {
        let descriptor = FetchDescriptor<ToDoTask>(
            predicate: #Predicate { !$0.completed },
            sortBy: [SortDescriptor(\.due, order: .forward)]
        )
        let tasks = try modelContext.fetch(descriptor)

        let now = Date()
        let filtered = tasks.filter { filter.matches(task: $0, at: now) }

        return filtered.map(ToDoTaskDTO.init(from:))
    }
    
    func updateTask(_ task: ToDoTaskDTO) throws -> ToDoTaskDTO {
        guard let id = task.id else {
            throw NSError(domain: "ClarityActor", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing PersistentIdentifier"])
        }
        guard let model = modelContext.model(for: id) as? ToDoTask else {
            throw NSError(domain: "ClarityActor", code: 2, userInfo: [NSLocalizedDescriptionKey: "Task not found"])
        }
        model.due = task.due
        model.name = task.name

        // Map CategoryDTOs to persisted Category models
        // Prefer matching by persistent identifier when available; fall back to name match
        let allCategories = try modelContext.fetch(FetchDescriptor<Category>())
        let mappedCategories: [Category] = task.categories.compactMap { dto in
            if let catId = dto.id, let existing = modelContext.model(for: catId) as? Category {
                return existing
            }
            // Fallback: match by name
            return allCategories.first(where: { $0.name == dto.name })
        }
        model.categories = mappedCategories
        model.pomodoroTime = task.pomodoroTime
        model.customRecurrenceDays = task.customRecurrenceDays
        model.recurrenceInterval = task.recurrenceInterval
        model.repeating = task.repeating
        model.pomodoro = task.pomodoro
        
        

        try modelContext.save()
        WidgetCenter.shared.reloadTimelines(ofKind: "ClarityTaskWidget")
        return ToDoTaskDTO(from: model)
    }
    
    func addTask(_ dto: ToDoTaskDTO) throws -> ToDoTaskDTO {
        // Safely fetch categories using the provided context
        let descriptor = FetchDescriptor<Category>()
        let allCategories = try modelContext.fetch(descriptor)
        // Filter to only the selected categories
        let categories = allCategories.filter { category in
            dto.categories.contains(where: { $0.name == category.name })
        }
        
        let toDoTask = ToDoTask(
            name: dto.name,
            pomodoro: dto.pomodoro,
            pomodoroTime: dto.pomodoroTime,
            repeating: dto.repeating,
            recurrenceInterval: dto.recurrenceInterval,
            customRecurrenceDays: dto.customRecurrenceDays,
            due: dto.due,
            categories: categories
        )
        
        modelContext.insert(toDoTask)
        
        try? modelContext.save()
        WidgetCenter.shared.reloadTimelines(ofKind: "ClarityTaskWidget")
        
        return ToDoTaskDTO(from: toDoTask)
    }
    
    func deleteTask(_ id: PersistentIdentifier) throws {
        if let model = modelContext.model(for: id) as? ToDoTask {
            modelContext.delete(model)
            try modelContext.save()
        }
        WidgetCenter.shared.reloadTimelines(ofKind: "ClarityTaskWidget")
    }
    
    func completeTask(_ id: PersistentIdentifier) throws {
        guard let model =  modelContext.model(for: id) as? ToDoTask else {
            throw NSError(domain: "ClarityActor", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing PersistentIdentifier"])
        }
        model.completed = true
        model.completedAt = Date.now
        if model.repeating == true {
            let nextTask = createNextOccurrence(id)
            _ = try addTask(nextTask)
        }
        try modelContext.save()
        WidgetCenter.shared.reloadTimelines(ofKind: "ClarityTaskWidget")
    }
    
    func fetchTaskById(_ id: PersistentIdentifier) throws -> ToDoTaskDTO? {
        if let model = modelContext.model(for: id) as? ToDoTask {
            return ToDoTaskDTO(from: model)
        }
        return nil
    }
    
    func createNextOccurrence(_ id: PersistentIdentifier) -> ToDoTaskDTO {
        let nextDueDate: Date
        
        // Safely attempt to fetch the task; if unavailable, return a sensible default DTO
        guard let task = modelContext.model(for: id) as? ToDoTask else {
            return ToDoTaskDTO(
                name: "",
                pomodoroTime: 0,
                repeating: false,
                recurrenceInterval: nil,
                customRecurrenceDays: 0,
                due: Date.now,
                categories: []
            )
        }
        
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
        
        let newTask = ToDoTaskDTO(
            name: task.name,
            pomodoroTime: task.pomodoroTime,
            repeating: true,
            recurrenceInterval: task.recurrenceInterval,
            customRecurrenceDays: task.customRecurrenceDays,
            due: nextDueDate,
            categories: (task.categories ?? []).map(CategoryDTO.init(from:))
        )
        return newTask
    }
    
    func fetchWeeklyProgress() throws -> WeeklyProgress {
        let globalDescriptor = FetchDescriptor<GlobalTargetSettings>()
        let globalSettings = try modelContext.fetch(globalDescriptor).first
        let globalTarget = globalSettings?.weeklyGlobalTarget ?? 0
        
        // Get current week start (Monday)
        let calendar = Calendar.current
        let now = Date()
        var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
        
        // TODO: Have the start day configurable
        components.weekday = 2 // Monday
        let weekStart = calendar.date(from: components) ?? now
        
        let taskDescriptor = FetchDescriptor<ToDoTask>(
            predicate: #Predicate {
                $0.completedAt != nil &&
                    $0.completedAt! > weekStart
            }
        )
        let tasks = try modelContext.fetch(taskDescriptor)
        
        let completedCount = tasks.count

        return WeeklyProgress(
            completed: completedCount,
            target: globalTarget,
            error: "",
            categories: []
        )
    }
}

enum ClarityModelActorFactory {
    static func makeBackground(container: ModelContainer) async -> ClarityModelActor {
        await withCheckedContinuation { cont in
            Task.detached(priority: .userInitiated) {
                let store = ClarityModelActor(modelContainer: container) // created off main queue
                cont.resume(returning: store)
            }
        }
    }
}
// Containers.swift
enum Containers {
    static func liveApp() throws -> ModelContainer {
        let schema = Schema([ToDoTask.self, Category.self, GlobalTargetSettings.self])
        let cfg = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true,
            groupContainer: .identifier("group.me.craigpeters.clarity"),
            cloudKitDatabase: .private("iCloud.me.craigpeters.clarity")   // CK ON
        )
        return try ModelContainer(for: schema, configurations: [cfg])
    }

    static func liveExtension() throws -> ModelContainer {
        let schema = Schema([ToDoTask.self, Category.self, GlobalTargetSettings.self])
        let cfg = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true,
            groupContainer: .identifier("group.me.craigpeters.clarity"),
     // CK OFF
        )
        return try ModelContainer(for: schema, configurations: [cfg])
    }

    static func inMemory() throws -> ModelContainer {
        let schema = Schema([ToDoTask.self, Category.self, GlobalTargetSettings.self])
        let cfg = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, allowsSave: true)
        return try ModelContainer(for: schema, configurations: [cfg])
    }
}

// AppContainer.swift (APP TARGET)
enum AppContainer {
    static let shared: ModelContainer = {
        print("🏗️ Creating CloudKit container (APP)")
        return try! Containers.liveApp()
    }()
}

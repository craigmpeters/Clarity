//
//  ClarityModelActor.swift
//  Clarity
//
//  Created by Craig Peters on 02/10/2025.
//

import Foundation
import os
import SwiftData
import WidgetKit

@ModelActor
actor ClarityModelActor {
    // MARK: Category Functions
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Clarity" , category: "ModelActor")
    
    func addCategory(_ dto: CategoryDTO) throws -> CategoryDTO {
        let category = Category(
            name: dto.name,
            color: dto.color,
            weeklyTarget: dto.weeklyTarget
        )
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
        model.everySpecificDayDay = task.everySpecificDayDay
        self.logger.debug("Update Task Day Day \(task.everySpecificDayDay, privacy: .public)")
        
        try modelContext.save()
        try WidgetFileCoordinator.shared.writeTasks(fetchTasks(filter: .all))
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
        self.logger.debug("Add Task Day Day \(dto.everySpecificDayDay, privacy: .public)")
        
        
        // Capture the UUID outside the predicate to avoid global function calls inside the predicate body
        let targetUUID: UUID? = dto.uuid
        let existingDescriptor = FetchDescriptor<ToDoTask>(
            predicate: #Predicate {
                $0.uuid == targetUUID &&
                !$0.completed
            }
        )
        
        let existing = try modelContext.fetch(existingDescriptor)

        if let existingTask = existing.first {
            logger.info("addTask deduped: active task already exists for UUID \(existingTask.uuid?.uuidString ?? "Unknown UUID", privacy: .public)")
            return ToDoTaskDTO(from: existingTask)
        }
        
        let toDoTask = ToDoTask(
            name: dto.name,
            pomodoro: dto.pomodoro,
            pomodoroTime: dto.pomodoroTime,
            repeating: dto.repeating,
            recurrenceInterval: dto.recurrenceInterval,
            customRecurrenceDays: dto.customRecurrenceDays,
            due: dto.due,
            everySpecificDayDay: dto.everySpecificDayDay,
            categories: categories,
            uuid: dto.uuid
        )
            modelContext.insert(toDoTask)
            
            try modelContext.save()
            try WidgetFileCoordinator.shared.writeTasks(fetchTasks(filter: .all))
            WidgetCenter.shared.reloadTimelines(ofKind: "ClarityTaskWidget")
            
            return ToDoTaskDTO(from: toDoTask)
    }
    
    func deleteTask(_ id: PersistentIdentifier) throws {
        if let model = modelContext.model(for: id) as? ToDoTask {
            modelContext.delete(model)
            try modelContext.save()
        }
        try WidgetFileCoordinator.shared.writeTasks(fetchTasks(filter: .all))
        WidgetCenter.shared.reloadTimelines(ofKind: "ClarityTaskWidget")
    }
    
    func completeTask(_ id: UUID) throws {
        var completed = false
        
        logger.info("Completing task with UUID \(id.uuidString, privacy: .public)")
        let taskUuid: UUID? = id
        let descriptor = FetchDescriptor<ToDoTask>(
            predicate: #Predicate {
                $0.uuid == taskUuid &&
                !$0.completed
            }
        )
        var tasks = try modelContext.fetch(descriptor)
        switch tasks.count {
        case 0: do { // No tasks found
            self.logger.error("No tasks found to complete for UUID \(id.uuidString, privacy: .public)")
            return
        }
        case 2...: do { // Multiple Tasks to complete
            self.logger.error("Multiple incomplete tasks found for UUID \(id.uuidString, privacy: .public) names \(tasks.map { $0.name ?? "No Task Name Found" }.joined(separator: ","), privacy: .public) ... completing all tasks")
        }
        default:
            self.logger.info("Task \(tasks.first!.name!, privacy: .public) found")
        }
        do {
            tasks = try tasks.map { task in
                task.completed = true
                task.completedAt = Date.now
                if task.repeating! && !completed {
                    let newTask = try addTask(createNextOccurrence(task.id)!)
                    self.logger.info("Created New Task for \(newTask.name, privacy: .public)")
                    completed = true
                }
                return task
            }
        } catch {
            self.logger.error("Error in completing task \(error.localizedDescription, privacy: .public)")
        }
        try modelContext.save()
        try WidgetFileCoordinator.shared.writeTasks(fetchTasks(filter: .all))
        WidgetCenter.shared.reloadTimelines(ofKind: "ClarityTaskWidget")
    }
    
    func fetchTaskByUuid(_ id: UUID) throws -> ToDoTaskDTO? {
        let taskUuid: UUID? = id
        let descriptor = FetchDescriptor<ToDoTask>(
            predicate: #Predicate {
                $0.uuid == taskUuid &&
                !$0.completed
            }
        )
        let tasks = try modelContext.fetch(descriptor)
        Logger.ClarityServices.info("fetchTaskByUuid: \(id) returned: \(tasks.count)")
        return tasks.first.map(ToDoTaskDTO.init(from:))
    }
    func fetchTaskById(_ id: PersistentIdentifier) throws -> ToDoTaskDTO? {
        if let model = modelContext.model(for: id) as? ToDoTask {
            return ToDoTaskDTO(from: model)
        }
        return nil
    }
    
    func createNextOccurrence(_ id: PersistentIdentifier) -> ToDoTaskDTO? {
        var nextDueDate: Date
        
        guard let task = modelContext.model(for: id) as? ToDoTask else {
            // Avoid interpolating PersistentIdentifier directly in logs
            Logger.ClarityServices.error("Task not found for provided PersistentIdentifier")
            return nil
        }
        
        if let interval = task.recurrenceInterval {
            if interval == .custom {
                nextDueDate = Calendar.current.date(
                    byAdding: .day,
                    value: task.customRecurrenceDays,
                    to: Date.now
                ) ?? task.due
            } else
            if interval == .specific {
                // Stored value already matches Calendar weekday (1...7). Clamp to be safe; default to Sunday (1) if nil.
                Logger.ClarityServices.debug("createNextOccurrence Day Day: \(task.everySpecificDayDay.map(String.init) ?? "None")")
                var com = DateComponents()
                // Map app's weekday index (where 3 = Wednesday) to Calendar's weekday (1 = Sunday ... 7 = Saturday)
                if let appWeekday = task.everySpecificDayDay {
                    // Normalize to 1...7 range first
                    let normalized = ((appWeekday - 1) % 7 + 7) % 7 + 1
                    // Shift so that app's 3 (Wednesday) becomes Calendar's 4 (Wednesday)
                    // Compute offset between app's Wednesday(3) and Calendar's Wednesday(4) => +1
                    let calendarWeekday = ((normalized + 1 - 1) % 7) + 1
                    com.weekday = calendarWeekday
                } else {
                    // Default to Sunday if missing
                    com.weekday = 1
                }

                let calendar = Calendar.current
                let startOfToday = calendar.startOfDay(for: Date())
                // let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? Date().addingTimeInterval(86_400)

                if let computed = calendar.nextDate(after: startOfToday,
                                                    matching: com,
                                                    matchingPolicy: .nextTimePreservingSmallerComponents,
                                                    direction: .forward)
                {
                    nextDueDate = computed
                } else {
                    Logger.ClarityServices.error("Failed to compute next specific weekday; falling back to interval.nextDate")
                    nextDueDate = interval.nextDate(from: Date.now)
                }
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
            everySpecificDayDay: task.everySpecificDayDay ?? 0,
            categories: (task.categories ?? []).map(CategoryDTO.init(from:)),
            uuid: task.uuid ?? UUID()
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
        let schema = Schema([ToDoTask.self, Category.self, GlobalTargetSettings.self, TaskSwipeAndTapOptions.self])
        let cfg = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true,
            groupContainer: .identifier("group.me.craigpeters.clarity"),
            cloudKitDatabase: .private("iCloud.me.craigpeters.clarity") // CK ON
        )
        return try ModelContainer(for: schema, configurations: [cfg])
    }

    static func liveExtension() throws -> ModelContainer {
        let schema = Schema([ToDoTask.self, Category.self, GlobalTargetSettings.self, TaskSwipeAndTapOptions.self])
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
        let schema = Schema([ToDoTask.self, Category.self, GlobalTargetSettings.self, TaskSwipeAndTapOptions.self])
        let cfg = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, allowsSave: true)
        return try ModelContainer(for: schema, configurations: [cfg])
    }
}

// AppContainer.swift (APP TARGET)
enum AppContainer {
    static let shared: ModelContainer = {
        return try! Containers.liveApp()
    }()
}


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
import XCGLogger

@ModelActor
actor ClarityModelActor {
    // MARK: Category Functions
    private let logger = LogManager.shared.log
    // Prevent concurrent completions for the same UUID within this actor
    private var inFlightCompletions: Set<UUID> = []
    // Throttle dedup runs triggered by remote merges / write paths
    private var lastDedupRunAt: Date? = nil
    
    private var totaltasks = 0
    
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
        WidgetCenter.shared.reloadAllTimelines()
        return CategoryDTO(from: model)
    }
    
    func deleteCategory(_ id: PersistentIdentifier) throws {
        if let model = modelContext.model(for: id) as? Category {
            modelContext.delete(model)
            try modelContext.save()
        }
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    func getCategories() throws -> [CategoryDTO] {
        let descriptor = FetchDescriptor<Category>()
        let categories = try modelContext.fetch(descriptor)
        return categories.map(CategoryDTO.init(from:))
    }
    
    // MARK: Task Functions
    
    func fetchWatchWidgetBackingData(completeFilter: ToDoTask.CompletedTaskFilter, dueFilter: ToDoTask.TaskFilterOption) -> WatchWidgetData {
        var data = WatchWidgetData(due: 0, completed: 0, progress: 0, target: 0)
        
        // data.completed
        let descriptor = FetchDescriptor<ToDoTask>(
            predicate: #Predicate { $0.completed },
            sortBy: [SortDescriptor(\.completedAt, order: .reverse)]
        )
        do {
            let tasks = try modelContext.fetch(descriptor)
            let dto: [ToDoTaskDTO] = tasks.map { ToDoTaskDTO(from: $0)}
            
            let filtered = dto.filter { completeFilter.matches($0) }
            data.completed = filtered.count
        } catch {
            data.completed = 0
        }
        
        // data.due
        do {
            let dueTasks = try fetchTasks(filter: dueFilter.toTaskFilter())
            data.due = dueTasks.count
        } catch {
            data.due = 0
        }
        
        //data.progress
        do {
            let progress = try fetchWeeklyProgress()
            data.target = progress.target
            data.completed = progress.completed
        } catch {
            data.target = 0
            data.completed = 0
        }
        
        return data
    }
    
    func fetchLastCompletedTask(filter: ToDoTask.TaskFilter = .all) -> ToDoTaskDTO? {
        let descriptor = FetchDescriptor<ToDoTask>(
            predicate: #Predicate { $0.completed },
            sortBy: [SortDescriptor(\.completedAt, order: .reverse)]
        )
        
        do {
            let tasks = try modelContext.fetch(descriptor)
            let now = Date()
            let filtered = tasks.filter { filter.matches(task: $0, at: now) }
            if let task = filtered.first {
                return ToDoTaskDTO(from: task)
            }
            return nil
        } catch {
            return nil
        }
    }

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
    
    func fetchCompletedTasks() throws -> [ToDoTaskDTO] {
        let descriptor = FetchDescriptor<ToDoTask>(
            predicate: #Predicate { $0.completed },
            sortBy: [SortDescriptor(\.due, order: .forward)]
        )
        let tasks = try modelContext.fetch(descriptor)
        LogManager.shared.log.debug("Fetched \(tasks.count) completed tasks")
        return tasks.map(ToDoTaskDTO.init(from:))
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
        LogManager.shared.log.debug("Update Task Day Day \(task.everySpecificDayDay)")
        
        try modelContext.save()
        try WidgetFileCoordinator.shared.writeTasks(fetchTasks(filter: .all))
        try WidgetFileCoordinator.shared.writeTasks(fetchCompletedTasks(), kind: DataFileKind.completed)
        WidgetCenter.shared.reloadAllTimelines()
        try? deduplicateTasksByUUID()
        return ToDoTaskDTO(from: model)
    }
    
    func addTask(_ dto: ToDoTaskDTO) throws -> ToDoTaskDTO {
        // Safely fetch categories using the provided context
        let descriptor = FetchDescriptor<Category>()
        let allCategories = try modelContext.fetch(descriptor)
        let incomingCategoryNames = dto.categories.map { $0.name }
        LogManager.shared.log.debug("addTask incoming categories: names=\(incomingCategoryNames) count=\(dto.categories.count)")
        // Map CategoryDTOs to persisted Category models (prefer id, fallback to name)
        let categories: [Category] = dto.categories.compactMap { dto in
            if let catId = dto.id, let existing = modelContext.model(for: catId) as? Category {
                return existing
            }
            return allCategories.first(where: { $0.name == dto.name })
        }
        LogManager.shared.log.debug("addTask mapped categories count=\(categories.count)")
        LogManager.shared.log.debug("Add Task Day Day \(dto.everySpecificDayDay)")
        
        
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
            LogManager.shared.log.info("addTask deduped: active task already exists for UUID \(existingTask.uuid?.uuidString ?? "Unknown UUID")")
            return ToDoTaskDTO(from: existingTask)
        }
        // Re-check just before insert to avoid races
        let existingBeforeInsert = try modelContext.fetch(existingDescriptor)
        LogManager.shared.log.debug("addTask existingBeforeInsert count=\(existingBeforeInsert.count)")
        if let existingTask = existingBeforeInsert.first {
            LogManager.shared.log.info("addTask deduped (pre-insert): active task already exists for UUID \(existingTask.uuid?.uuidString ?? "Unknown UUID")")
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
        try WidgetFileCoordinator.shared.writeTasks(fetchCompletedTasks(), kind: DataFileKind.completed)
        WidgetCenter.shared.reloadAllTimelines()
            try? deduplicateTasksByUUID()
            
            return ToDoTaskDTO(from: toDoTask)
    }
    
    func deleteTask(_ id: PersistentIdentifier) throws {
        if let model = modelContext.model(for: id) as? ToDoTask {
            modelContext.delete(model)
            try modelContext.save()
        }
        try WidgetFileCoordinator.shared.writeTasks(fetchTasks(filter: .all))
        try WidgetFileCoordinator.shared.writeTasks(fetchCompletedTasks(), kind: DataFileKind.completed)
        WidgetCenter.shared.reloadAllTimelines()
        try? deduplicateTasksByUUID()
    }
    
    func completeTask(_ id: UUID) throws {
        var completed = false
        
        // In-flight guard to avoid concurrent duplicate next-occurrence creation
        if inFlightCompletions.contains(id) {
            LogManager.shared.log.warning("completeTask: UUID \(id.uuidString) already in-flight, ignoring duplicate call")
            return
        }
        inFlightCompletions.insert(id)
        defer { inFlightCompletions.remove(id) }
        
        LogManager.shared.log.info("Completing task with UUID \(id.uuidString)")
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
            LogManager.shared.log.error("No tasks found to complete for UUID \(id.uuidString)")
            return
        }
        case 2...: do { // Multiple Tasks to complete
            LogManager.shared.log.error("Multiple incomplete tasks found for UUID \(id.uuidString) names \(tasks.map { $0.name ?? "No Task Name Found" }.joined(separator: ",")) ... completing all tasks")
        }
        default:
            LogManager.shared.log.info("Task \(tasks.first!.name!) found")
            let first = tasks.first!
            let catCount = first.categories?.count ?? 0
            LogManager.shared.log.debug("completeTask: found task uuid=\(first.uuid?.uuidString ?? "nil"), categories=\(catCount)")
        }
        do {
            tasks = try tasks.map { task in
                task.completed = true
                task.completedAt = Date.now
                if task.repeating! && !completed {
                    if let nextDTO = createNextOccurrence(task.id) {
                        LogManager.shared.log.debug("completeTask: creating next occurrence for uuid=\(task.uuid?.uuidString ?? "nil"), dtoCategoryCount=\(nextDTO.categories.count)")
                        let newTask = try addTask(nextDTO)
                        LogManager.shared.log.info("Created New Task for \(newTask.name)")
                    }
                    completed = true
                }
                return task
            }
        } catch {
            LogManager.shared.log.error("Error in completing task \(error.localizedDescription)")
        }
        try modelContext.save()
        try WidgetFileCoordinator.shared.writeTasks(fetchTasks(filter: .all))
        try WidgetFileCoordinator.shared.writeTasks(fetchCompletedTasks(), kind: DataFileKind.completed)
        WidgetCenter.shared.reloadAllTimelines()
        try? deduplicateTasksByUUID()
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
        LogManager.shared.log.info("fetchTaskByUuid: \(id) returned: \(tasks.count)")
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
            LogManager.shared.log.error("Task not found for provided PersistentIdentifier")
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
                LogManager.shared.log.debug("createNextOccurrence Day Day: \(task.everySpecificDayDay.map(String.init) ?? "None")")
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
                    LogManager.shared.log.error("Failed to compute next specific weekday; falling back to interval.nextDate")
                    nextDueDate = interval.nextDate(from: Date.now)
                }
            } else {
                nextDueDate = interval.nextDate(from: Date.now)
            }
        } else {
            // Fallback to daily if no interval set
            nextDueDate = Calendar.current.date(byAdding: .day, value: 1, to: task.due) ?? task.due
        }
        
        // Ensure categories are realized before mapping (if lazily loaded)
        let categoryCount = task.categories?.count ?? 0
        LogManager.shared.log.debug("createNextOccurrence: base task uuid=\(task.uuid?.uuidString ?? "nil"), name=\(task.name ?? "nil"), categories=\(categoryCount), nextDue=\(nextDueDate)")
        
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
    
    // MARK: - Maintenance / Deduplication
    func deduplicateTasksByUUID() throws {
        // Fetch all incomplete tasks
        let descriptor = FetchDescriptor<ToDoTask>(
            predicate: #Predicate { !$0.completed }
        )
        let tasks = try modelContext.fetch(descriptor)

        // Group by UUID (ignore nil)
        var groups: [UUID: [ToDoTask]] = [:]
        for task in tasks {
            guard let id = task.uuid else { continue }
            groups[id, default: []].append(task)
        }

        var totalDuplicateGroups = 0
        var totalDeleted = 0

        for (uuid, group) in groups where group.count > 1 {
            logger.error("Dedup: Found duplicate group uuid=\(uuid.uuidString) count=\(group.count)")

            // Log full details for each record in the group
            for (idx, t) in group.enumerated() {
                let categories = (t.categories ?? []).compactMap { $0.name }.joined(separator: ",")
                logger.error("  [\(idx)] id=\(t.id.debugDescription) name=\(t.name ?? "nil") due=\(t.due) completed=\(t.completed) completedAt=\(String(describing: t.completedAt)) cats=[\(categories)] created=[\(t.created.ISO8601Format())]")
            }

            // Choose the winner deterministically
            let winner = group.min { a, b in
                let aCatCount = a.categories?.count ?? 0
                let bCatCount = b.categories?.count ?? 0

                // 1) Prefer the one that has categories if the other doesn't (any positive count beats zero)
                if (aCatCount > 0) != (bCatCount > 0) {
                    return aCatCount == 0 // if a has 0 and b > 0, then a is "greater" so return false; but min uses this as "less-than"
                }

                // 2) If both have categories (or both don't), prefer more categories
                if aCatCount != bCatCount {
                    return aCatCount < bCatCount // larger category count wins, so "less-than" should be false when a has more
                }

                // 3) Earliest due date wins
                if a.due != b.due { return a.due < b.due }

                // 4) Prefer non-nil name
                let aNameNil = (a.name == nil)
                let bNameNil = (b.name == nil)
                if aNameNil != bNameNil { return !aNameNil } // if a has a name and b doesn't, a should come first

                // 5) Stable tie-breaker
                return a.id.debugDescription < b.id.debugDescription
            }!

            // Delete all others
            for t in group where t.id != winner.id {
                logger.warning("Dedup: Deleting loser id=\(t.id.debugDescription) for uuid=\(uuid.uuidString)")
                modelContext.delete(t)
                totalDeleted += 1
            }
            totalDuplicateGroups += 1
        }

        if totalDuplicateGroups > 0 {
            try modelContext.save()
            // Keep widgets in sync with the new state
            try WidgetFileCoordinator.shared.writeTasks(fetchTasks(filter: .all))
            WidgetCenter.shared.reloadAllTimelines()
        }

        logger.info("Dedup: groups=\(totalDuplicateGroups) deleted=\(totalDeleted)")
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

// #MARK: Timeline Entries

struct TaskWidgetEntry: TimelineEntry {
    let date: Date
    let todos: [ToDoTaskDTO]
    let progress: WeeklyProgress
    let filter: ToDoTask.TaskFilterOption
    let showWeeklyProgress: Bool
}

struct CompletedTaskEntry: TimelineEntry {
    let date: Date
    let tasks: [ToDoTaskDTO]
    let categories: [CategoryDTO]
    let progress: WeeklyProgress
    let filter: ToDoTask.CompletedTaskFilter
    let showWeeklyProgress: Bool
}

public struct WatchWidgetData: Codable, Sendable {
    public var due: Int
    public var completed: Int
    public var progress: Int
    public var target: Int
}

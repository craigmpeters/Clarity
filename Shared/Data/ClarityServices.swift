//
//  ClarityServices.swift
//  Clarity
//
//  Created by Craig Peters on 03/10/2025.
//

import SwiftData
#if canImport(WidgetKit)
import WidgetKit
#endif

enum ClarityServices {
    static func sharedContainer() throws -> ModelContainer {
        try Containers.live()
    }

    static func inMemoryContainer() -> ModelContainer {
        try! Containers.inMemory()
    }

    static func store() async throws -> ClarityModelActor {
        let container = try sharedContainer()
        return await ClarityModelActorFactory.makeBackground(container: container)
    }

    static func snapshotTasks(filter: ToDoTask.TaskFilter = .all) -> [ToDoTaskDTO] {
        do {
            let container = try Containers.live()
            let ctx = ModelContext(container)

            // Basic fetch (only unfinished), sorted for nice display.
            let descriptor = FetchDescriptor<ToDoTask>(
                predicate: #Predicate { !$0.completed },
                sortBy: [SortDescriptor(\.due, order: .forward)]
            )
            let all = try ctx.fetch(descriptor)

            let now = Date()
            let filtered = all.filter { filter.matches(task: $0, at: now) }
            return filtered.map(ToDoTaskDTO.init(from:))
        } catch {
            return []
        }
    }

    static func snapshotTasksAsync(filter: ToDoTask.TaskFilter = .all) async -> [ToDoTaskDTO] {
        await withCheckedContinuation { cont in
            Task.detached {
                cont.resume(returning: snapshotTasks(filter: filter))
            }
        }
    }
    
    static func snapshotCategories() -> [CategoryDTO] {
        do {
            let container = try sharedContainer()
            let context = ModelContext(container)
            let descriptor = FetchDescriptor<Category>()
            return try context.fetch(descriptor).map(CategoryDTO.init(from:))
        } catch {
            return []
        }
    }
    
    static func reloadWidgets(kind: String? = nil) {
            #if canImport(WidgetKit)
            if let kind { WidgetCenter.shared.reloadTimelines(ofKind: kind) }
            else { WidgetCenter.shared.reloadAllTimelines() }
            #endif
        }
    
    static func fetchWeeklyProgress() -> WeeklyProgress {
        do {
            let container = try sharedContainer()
            let context = ModelContext(container)
            
            let globalDescriptor = FetchDescriptor<GlobalTargetSettings>()
            let globalSettings = try context.fetch(globalDescriptor).first
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
            let tasks = try context.fetch(taskDescriptor)

            let completedCount = tasks.count
            
            return WeeklyProgress(
                completed: completedCount,
                target: globalTarget,
                categories: []
            )
        } catch {
            return WeeklyProgress(completed: 0,
                                  target: 0,
                                  categories: [])
        }

    }
}

import SwiftData
import os
#if canImport(WidgetKit)
import WidgetKit
#endif

enum ClarityServices {
    // Cache only for the EXTENSION process.
    // nonisolated(unsafe): single-writer (extension process only), no concurrent callers.
    nonisolated(unsafe) private static var cachedExtensionContainer: ModelContainer?

    // More reliable than checking bundle path
    private static var isExtension: Bool {
        Bundle.main.object(forInfoDictionaryKey: "NSExtension") != nil
    }

    nonisolated static func sharedContainer() throws -> ModelContainer {
        let isExtension = Bundle.main.object(forInfoDictionaryKey: "NSExtension") != nil
        print("🚦 Process type:", isExtension ? "EXTENSION" : "APP")

        if isExtension {
            if let c = cachedExtensionContainer { return c }
            print("🏗️ Creating NON-CloudKit container (EXT)")
            let c = try Containers.liveExtension()          // cloudKitDatabase: nil
            cachedExtensionContainer = c
            return c
        } else {
            return AppContainer.shared                     // single CloudKit container in app
        }
    }


    nonisolated static func inMemoryContainer() -> ModelContainer {
        try! Containers.inMemory()
    }

    static func store() async throws -> ClarityModelActor {
        let container = try sharedContainer()
        return await StoreRegistry.shared.store(for: container)
    }

    // -------- Snapshots for widgets / quick reads --------
    
    nonisolated static func snapshotCompleted() -> [ToDoTaskDTO] {
        do {
            let container = try sharedContainer()
            let ctx = ModelContext(container)
            let descriptor = FetchDescriptor<ToDoTask>(
                predicate: #Predicate { $0.completed },
                sortBy: [SortDescriptor(\.completedAt, order: .forward)]
            )
            let all = try ctx.fetch(descriptor)
            return all
                .map(ToDoTaskDTO.init(from:))
        } catch {
            return []
        }
    }

    nonisolated static func snapshotTasks(filter: ToDoTask.TaskFilter = .all) -> [ToDoTaskDTO] {
        do {
            let container = try sharedContainer()         // <- was Containers.live()
            let ctx = ModelContext(container)
            let descriptor = FetchDescriptor<ToDoTask>(
                predicate: #Predicate { !$0.completed },
                sortBy: [SortDescriptor(\.due, order: .forward)]
            )
            let all = try ctx.fetch(descriptor)
            let now = Date()
            return all
                .filter { filter.matches(task: $0, at: now) }
                .map(ToDoTaskDTO.init(from:))
        } catch {
            return []
        }
    }
    
    nonisolated static func snapshotCategories() -> [CategoryDTO] {
        do {
            let container = try sharedContainer()
            let ctx = ModelContext(container)
            let descriptor = FetchDescriptor<Category>(sortBy: [SortDescriptor(\.name)])
            return try ctx.fetch(descriptor).map(CategoryDTO.init(from:))
        } catch { return [] }
    }

    nonisolated static func reloadWidgets(kind: String? = nil) {
        #if canImport(WidgetKit)
        if let kind { WidgetCenter.shared.reloadTimelines(ofKind: kind) }
        else { WidgetCenter.shared.reloadAllTimelines() }
        #endif
    }

    nonisolated static func fetchWeeklyProgress() -> WeeklyProgress {
        do {
            let container = try sharedContainer()
            let ctx = ModelContext(container)

            let global = try ctx.fetch(FetchDescriptor<GlobalTargetSettings>()).first
            let target = global?.weeklyGlobalTarget ?? 0

            let cal = Calendar.current
            let now = Date()
            var comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
            comps.weekday = 2 // Monday
            let weekStart = cal.date(from: comps) ?? now

            let taskDescriptor = FetchDescriptor<ToDoTask>(
                predicate: #Predicate { task in
                    if let completed = task.completedAt {
                        return completed > weekStart
                    } else {
                        return false
                    }
                }
            )
            let count = try ctx.fetch(taskDescriptor).count
            let progress = WeeklyProgress(completed: count, target: target, error: "", categories: [])
            
            try? WidgetFileCoordinator.shared.writeWeeklyProgress(progress)

            return progress
        } catch {
            print(error.localizedDescription)
            return WeeklyProgress(completed: 0, target: 0, error: error.localizedDescription, categories: [])
        }
    }
}

actor StoreRegistry {
    static let shared = StoreRegistry()
    private var stores: [ObjectIdentifier: ClarityModelActor] = [:]

    func store(for container: ModelContainer) async -> ClarityModelActor {
        let key = ObjectIdentifier(container)
        if let existing = stores[key] { return existing }

        // Build OFF the main thread
        let store = await ClarityModelActorFactory.makeBackground(container: container)
        stores[key] = store
        return store
    }

    // Handy for tests/previews if you need to reset between runs
    func reset() {
        stores.removeAll()
    }
}


import SwiftData
import os
#if canImport(WidgetKit)
import WidgetKit
#endif

enum ClarityServices {
    // Cache only for extension and watch app processes.
    // nonisolated(unsafe): single-writer (no concurrent callers).
    nonisolated(unsafe) private static var cachedExtensionContainer: ModelContainer?

    nonisolated static func sharedContainer() throws -> ModelContainer {
        let isExtension = Bundle.main.object(forInfoDictionaryKey: "NSExtension") != nil
#if os(watchOS)
        let isWatchApp = true
#else
        let isWatchApp = false
#endif
        print("🚦 Process type:", isExtension ? "EXTENSION" : (isWatchApp ? "WATCH_APP" : "APP"))

        if isExtension || isWatchApp {
            if let c = cachedExtensionContainer { return c }
            print("🏗️ Creating NON-CloudKit container (EXT/WATCH)")
            let c = try Containers.liveExtension()
            cachedExtensionContainer = c
            return c
        } else {
            return AppContainer.shared
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
    
    // TODO: [CRASH-001] Route all snapshot reads through ClarityModelActor to avoid ad-hoc ModelContext
    // access on a non-actor isolation domain. SwiftData's ModelContext is not thread-safe; creating
    // contexts here and calling fetch() concurrently with the @ModelActor store can trigger
    // CoreData performAndWait crashes (signature: NSManagedObjectContext.performAndWait<A>(_:) + 8).
    // Replace with: let store = try await ClarityServices.store(); return await store.snapshotCompleted().
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

    // TODO: [CRASH-001] Ad-hoc ModelContext.fetch from a nonisolated static method is unsafe when
    // ClarityModelActor is mutating the same store. Move this to the actor and call via store().
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
    
    // TODO: [CRASH-001] Same ModelContext isolation issue: this should be a read on the actor.
    nonisolated static func snapshotCategories() -> [CategoryDTO] {
        do {
            let container = try sharedContainer()
            let ctx = ModelContext(container)
            let descriptor = FetchDescriptor<Category>(sortBy: [SortDescriptor(\.name)])
            return try ctx.fetch(descriptor).map(CategoryDTO.init(from:))
        } catch { return [] }
    }

    nonisolated static func writeCategorySnapshot() {
        let categories = snapshotCategories()
        try? WidgetFileCoordinator.shared.writeCategories(categories)
    }

    nonisolated static func reloadWidgets(kind: String? = nil) {
        #if canImport(WidgetKit)
        if let kind { WidgetCenter.shared.reloadTimelines(ofKind: kind) }
        else { WidgetCenter.shared.reloadAllTimelines() }
        #endif
    }

    // TODO: [CRASH-001] Heavy snapshot read across GlobalTargetSettings, Category, and ToDoTask
    // from a nonisolated context risks concurrent performAndWait with the model actor. Move to actor.
    nonisolated static func fetchWeeklyProgress() -> WeeklyProgress {
        do {
            let container = try sharedContainer()
            let ctx = ModelContext(container)

            let globalTarget = (try? ctx.fetch(FetchDescriptor<GlobalTargetSettings>()))?.first?.weeklyGlobalTarget ?? 0
            let categories = (try? ctx.fetch(FetchDescriptor<Category>()))?.map(CategoryDTO.init(from:)) ?? []
            let completedDTOs = (try? ctx.fetch(
                FetchDescriptor<ToDoTask>(predicate: #Predicate { $0.completed })
            ))?.map(ToDoTaskDTO.init(from:)) ?? []

            let progress = StatisticsCalculator.weeklyProgress(
                completedTasks: completedDTOs,
                categories: categories,
                globalTarget: globalTarget
            )

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


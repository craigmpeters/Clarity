import Foundation
import Observation
import OSLog
import SwiftData
import WidgetKit

/// This is a shared model used by the actors to interact with the data
public class ClarityModel {
    public static let schema = Schema([
        ToDoTask.self,
        Category.self,
        GlobalTargetSettings.self
    ])
    
    public static let modelConfiguration = ModelConfiguration(
        schema: schema,
        isStoredInMemoryOnly: false,
        allowsSave: true,
        groupContainer: .identifier("group.me.craigpeters.clarity"),
        cloudKitDatabase: .private("iCloud.me.craigpeters.clarity")
    )
}

/// This is the data actor used on the main thread for UI Specific Actions
@MainActor @Observable
final class MainDataActor: Sendable {
    let modelContainer: ModelContainer
    let modelContext: ModelContext
    private let repository: ClarityRepositoryProtocol
    static let shared = MainDataActor()
    
    private init(repository: ClarityRepositoryProtocol = ClarityTaskRepository()) {
        do {
            let schema = ClarityModel.schema
            let modelConfiguration = ClarityModel.modelConfiguration
            
            modelContainer = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
            modelContext = modelContainer.mainContext
            self.repository = repository
            
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }
    
    // MARK: Category Functions

    func getCategories() throws -> [Category] {
        try repository.getCategories(in: modelContext)
    }

    // MARK: Task Functions

    func fetchTasks(_ filter: ToDoTask.TaskFilter) async throws -> [ToDoTask] {
        try await repository.fetchTasks(in: modelContext, filter)
    }

    func addTask(name: String, duration: TimeInterval, repeating: Bool, categoryIds: [String]) {
        repository.addTask(in: modelContext, name: name, duration: duration, repeating: repeating, categoryIds: categoryIds)
        updateTaskWidgets()
    }
    
    func addTask(_ task: ToDoTask) {
        repository.addTask(in: modelContext, toDoTask: task)
    }

    func deleteTask(_ task: ToDoTask) {
        repository.deleteTask(in: modelContext, task)
        updateTaskWidgets()
    }
    
    func completeTask(in context: ModelContext, _ task: ToDoTask) {
        repository.completeTask(in: context, task)
    }

    func completeTask(_ task: ToDoTask) {
        repository.completeTask(in: modelContext, task)
        updateTaskWidgets()
    }

    func fetchTaskById(_ taskId: String) throws -> ToDoTask? {
        try repository.fetchTaskById(in: modelContext, taskId)
    }

    func createNextOccurrence(_ task: ToDoTask) -> ToDoTask {
        repository.createNextOccurrence(in: modelContext, task)
    }

    // MARK: Statistical Functions

    func fetchWeeklyProgress() throws -> WeeklyProgress {
        try repository.fetchWeeklyProgress(in: modelContext)
    }

    // MARK: Actions for Widgets / Intents

    private func updateTaskWidgets() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}

/// Static Data Store used in all non-ui based actions
@ModelActor
actor StaticDataStore {
    static let shared = StaticDataStore(modelContainer: {
        do {
            return try ModelContainer(
                for: ClarityModel.schema,
                configurations: [ClarityModel.modelConfiguration]
            )
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }())

    private let repo: ClarityRepositoryProtocol = ClarityTaskRepository()
    private let log = Logger(subsystem: "me.craigpeters.clarity", category: "StaticDataStore")
    
    // MARK: Category Functions

    func getCategories(in context: ModelContext) throws -> [Category] {
        try repo.getCategories(in: context)
    }
    
    func getCategories() throws -> [Category] {
        try getCategories(in: modelContext)
    }

    // MARK: Task Functions

    func fetchTasks(in context: ModelContext, _ filter: ToDoTask.TaskFilter) async throws -> [ToDoTask] {
        try await repo.fetchTasks(in: context, filter)
    }
    
    func fetchTasks(_ filter: ToDoTask.TaskFilter) async throws -> [ToDoTask] {
        return try await fetchTasks(in: modelContext, filter)
    }

    func addTask(in context: ModelContext, name: String, duration: TimeInterval, repeating: Bool, categoryIds: [String]) {
        repo.addTask(in: context, name: name, duration: duration, repeating: repeating, categoryIds: categoryIds)
        updateTaskWidgets()
    }
    
    func addTask(name: String, duration: TimeInterval, repeating: Bool, categoryIds: [String]) {
        repo.addTask(in: modelContext, name: name, duration: duration, repeating: repeating, categoryIds: categoryIds)
        updateTaskWidgets()
    }
    
    func addTask(in context: ModelContext, toDoTask: ToDoTask) {
        repo.addTask(in: modelContext, toDoTask: toDoTask)
        updateTaskWidgets()
    }

    func deleteTask(in context: ModelContext, _ task: ToDoTask) {
        repo.deleteTask(in: context, task)
        updateTaskWidgets()
    }

    func completeTask(in context: ModelContext, _ task: ToDoTask) {
        repo.completeTask(in: context, task)
        updateTaskWidgets()
    }
    
    func completeTask(_ task: ToDoTask) {
        completeTask(in: modelContext, task)
    }

    func fetchTaskById(in context: ModelContext, taskId: String) throws -> ToDoTask? {
        return try repo.fetchTaskById(in: context, taskId)
    }
    
    func fetchTaskById(_ taskId: String) throws -> ToDoTask? {
        return try fetchTaskById(in: modelContext, taskId: taskId)
    }

    func createNextOccurrence(in context: ModelContext, _ task: ToDoTask) -> ToDoTask {
        return repo.createNextOccurrence(in: context, task)
    }

    // MARK: Statistical Functions

    func fetchWeeklyProgress(in context: ModelContext) throws -> WeeklyProgress {
        let globalDescriptor = FetchDescriptor<GlobalTargetSettings>(
            sortBy: [SortDescriptor(\.created, order: .reverse)]
        )
        let settings = try context.fetch(globalDescriptor)
        let latestSettings = settings.first
        var globalTarget = latestSettings?.weeklyGlobalTarget ?? 0
        
        if globalTarget == 0 {
            let catDescriptor = FetchDescriptor<Category>()
            let categories = try context.fetch(catDescriptor)
            let sumTargets = categories.reduce(0) { $0 + $1.weeklyTarget }
            if sumTargets > 0 {
                log.debug("Using fallback global target from categories sum: \(sumTargets, privacy: .public)")
            } else {
                log.debug("No global target set and categories sum is 0")
            }
            globalTarget = sumTargets
        }
        
        // Get current week start (Monday)
        let calendar = Calendar.current
        let now = Date()
        var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
        
        // TODO: Have the start day configurable
        components.weekday = 2 // Monday
        let weekStart = calendar.date(from: components) ?? now
        
        let completedDescriptor = FetchDescriptor<ToDoTask>(
            predicate: #Predicate { task in
                task.completed && task.completedAt != nil
            }
        )
        let allCompleted = try modelContext.fetch(completedDescriptor)
        let weekCompleted = allCompleted.filter { task in
            guard let completedAt = task.completedAt else { return false }
            return completedAt >= weekStart
        }
        return WeeklyProgress(
            completed: weekCompleted.count,
            target: globalTarget,
            categories: []
        )
    }
    
    func fetchWeeklyProgress() async throws -> WeeklyProgress {
        return try fetchWeeklyProgress(in: modelContext)
    }

    // MARK: Actions for Widgets / Intents

    private func updateTaskWidgets() {
        DispatchQueue.main.async {
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
}

protocol ClarityRepositoryProtocol {
    // MARK: Category Functions

    func getCategories(in context: ModelContext) throws -> [Category]
    
    // MARK: Task Functions

    func fetchTasks(in context: ModelContext, _ filter: ToDoTask.TaskFilter) async throws -> [ToDoTask]
    func addTask(in context: ModelContext, name: String, duration: TimeInterval, repeating: Bool, categoryIds: [String])
    func addTask(in context: ModelContext, toDoTask: ToDoTask)
    func deleteTask(in context: ModelContext, _ task: ToDoTask)
    func completeTask(in context: ModelContext, _ task: ToDoTask)
    func fetchTaskById(in context: ModelContext, _ taskId: String) throws -> ToDoTask?
    func createNextOccurrence(in context: ModelContext, _ task: ToDoTask) -> ToDoTask
    
    // MARK: Statistical Functions

    func fetchWeeklyProgress(in context: ModelContext) throws -> WeeklyProgress
}

struct ClarityTaskRepository: ClarityRepositoryProtocol {
    private let log = Logger(subsystem: "me.craigpeters.clarity", category: "Repository")

    func fetchTaskById(in context: ModelContext, _ taskId: String) throws -> ToDoTask? {
        let descriptor = FetchDescriptor<ToDoTask>(
            predicate: #Predicate { task in
                !task.completed
            }
        )
        let tasks = try context.fetch(descriptor)
        
        // Find the task by ID in Swift code (not in predicate)
        guard let task = tasks.first(where: { String(describing: $0.id) == taskId }) else {
            log.warning("Task not found with ID: \(taskId, privacy: .public)")
            return nil
        }
        
        return task
    }
    
    func createNextOccurrence(in context: ModelContext, _ task: ToDoTask) -> ToDoTask {
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
            categories: task.categories ?? []
        )
        
        return newTask
    }
    
    func getCategories(in context: ModelContext) throws -> [Category] {
        do {
            let descriptor = FetchDescriptor<Category>()
            return try context.fetch(descriptor)
        } catch {
            log.error("Failed to fetch categories: \(String(describing: error), privacy: .public)")
            return []
        }
    }
    
    func fetchTasks(in context: ModelContext, _ filter: ToDoTask.TaskFilter) async throws -> [ToDoTask] {
        do {
            let descriptor = FetchDescriptor<ToDoTask>(
                predicate: #Predicate { !$0.completed },
                sortBy: [SortDescriptor(\.due, order: .forward)]
            )
            
            var tasks = try context.fetch(descriptor)
            // Apply filter
            let calendar = Calendar.current
            let now = Date()
            
            switch filter {
            case .today:
                tasks = tasks.filter { calendar.isDateInToday($0.due) }
            case .tomorrow:
                tasks = tasks.filter { calendar.isDateInTomorrow($0.due) }
            case .thisWeek:
                let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
                let endOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.end ?? now
                tasks = tasks.filter { $0.due >= startOfWeek && $0.due <= endOfWeek }
            case .overdue:
                tasks = tasks.filter { $0.due < calendar.startOfDay(for: now) }
            case .all:
                break // No additional filtering
            }
            
            return tasks
        } catch {
            log.error("Failed to fetch tasks: \(String(describing: error), privacy: .public)")
            return []
        }
    }
    
    func addTask(in context: ModelContext, name: String, duration: TimeInterval, repeating: Bool, categoryIds: [String]) {
        print("Data Manager: Category IDs: \(String(describing: categoryIds))")
        let task = ToDoTask(name: name)
        task.pomodoroTime = duration
        task.repeating = repeating

        // Safely fetch categories using the provided context
        let allCategories: [Category] = (try? getCategories(in: context)) ?? []
        // Filter to only the selected categories
        let categories = allCategories.filter { category in
            categoryIds.contains(String(describing: category.id))
        }
        task.categories = categories

        // Insert and save using the provided context
        context.insert(task)
        saveContext(in: context)
    }
    
    func addTask(in context: ModelContext, toDoTask: ToDoTask) {
        context.insert(toDoTask)
        saveContext(in: context)
    }
    
    func deleteTask(in context: ModelContext, _ task: ToDoTask) {
        context.delete(task)
        saveContext(in: context)
    }
    
    func completeTask(in context: ModelContext, _ task: ToDoTask) {
        task.completed = true
        task.completedAt = Date.now
        if task.repeating! {
            let nextTask = createNextOccurrence(in: context, task)
            context.insert(nextTask)
        }
        saveContext(in: context)
    }
    
    func fetchWeeklyProgress(in context: ModelContext) throws -> WeeklyProgress {
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
        log.debug("Weekly progress computed: \(completedCount, privacy: .public) / \(globalTarget, privacy: .public)")
        
        return WeeklyProgress(
            completed: completedCount,
            target: globalTarget,
            categories: []
        )
    }
    
    private func saveContext(in context: ModelContext) {
        do {
            try context.save()
            
        } catch {
            log.error("Could not save context: \(error.localizedDescription, privacy: .public)")
        }
    }
}

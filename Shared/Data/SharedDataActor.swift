import SwiftData
import WidgetKit
import Foundation


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
//public final class SharedDataActor: Sendable {
public final class MainDataActor: Sendable {
    static let shared: MainDataActor = MainDataActor()
    let modelContainer: ModelContainer
    let modelContext: ModelContext
    
    private init() {
        do {
            let schema = ClarityModel.schema
            let modelConfiguration = ClarityModel.modelConfiguration
            
            modelContainer = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
            self.modelContext = modelContainer.mainContext
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
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
    func deleteTask(in context: ModelContext, _ task: ToDoTask)
    func completeTask(in context: ModelContext, _ task: ToDoTask)
    func fetchTaskById(in context: ModelContext, _ taskId: String) throws -> ToDoTask?
    func createNextOccurrence(in context: ModelContext, _ task: ToDoTask) -> ToDoTask
    
    // MARK: Statistical Functions
    func fetchWeeklyTarget(in context: ModelContext) throws -> Int
}

struct ClarityTaskRepository: ClarityRepositoryProtocol {
    
    func fetchTaskById(in context: ModelContext, _ taskId: String) throws -> ToDoTask? {
        let descriptor = FetchDescriptor<ToDoTask>(
            predicate: #Predicate { task in
                !task.completed
            }
        )
        let tasks = try context.fetch(descriptor)
        
        // Find the task by ID in Swift code (not in predicate)
        guard let task = tasks.first(where: { String(describing: $0.id) == taskId }) else {
            print("Widget: Task not found with ID: \(taskId)")
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
            print("Failed to fetch categories: \(error)")
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
            print("Failed to fetch tasks: \(error)")
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
    
    func fetchWeeklyTarget(in context: ModelContext) throws -> Int {
        let globalDescriptor = FetchDescriptor<GlobalTargetSettings>()
        let globalSettings = try context.fetch(globalDescriptor).first
        let globalTarget = globalSettings?.weeklyGlobalTarget ?? 0
        return globalTarget
    }
    
    private func saveContext(in context: ModelContext) {
        do {
            try context.save()
            
        } catch {
            print("Could not save context \(error.localizedDescription)")
        }
    }

}

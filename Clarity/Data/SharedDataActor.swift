import SwiftData
import Foundation

@ModelActor
actor SharedDataActor {
    static let shared = SharedDataActor(modelContainer: {
        do {
            // Create model container with app group for widget data sharing
            let schema = Schema([
                ToDoTask.self,
                Category.self,
                GlobalTargetSettings.self
            ])
            
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                allowsSave: true,
            )
            
            return try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }())
    
    func getCategories() -> [Category] {
        do {
            let descriptor = FetchDescriptor<Category>()
            return try modelContext.fetch(descriptor)
        } catch {
            print("Failed to fetch categories: \(error)")
            return []
        }
    }
    
    func addTask(name: String, duration: TimeInterval, repeating: Bool, categoryIds: [String]) {
        print("Data Manager: Category IDs: \(String(describing: categoryIds))")
        let task = ToDoTask(name: name)
        task.pomodoroTime = duration
        task.repeating = repeating
        
        let allCategories: [Category] = getCategories()
        for category in allCategories {
                print("  - Name: \(category.name), ID: \(category.id.storeIdentifier ?? "nil")")
            }
        let categories = getCategories().filter {
            categoryIds.contains(String(describing: $0.id))
        }
        task.categories = categories
        
        modelContext.insert(task)
        
        do {
            try modelContext.save()
        } catch {
            print("Failed to save task: \(error)")
        }
    }
}

@ModelActor
actor WidgetDataActor {
    static let shared = WidgetDataActor(modelContainer: {
        do {
            let schema = Schema([
                ToDoTask.self,
                Category.self,
                GlobalTargetSettings.self
            ])
            
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                allowsSave: true,
                groupContainer: .identifier("group.me.craigpeters.clarity")
            )
            
            return try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }())
    
    func fetchTasksForWidget(filter: ToDoStore.TaskFilter) async -> (tasks: [ToDoTask], weeklyProgress: TaskWidgetEntry.WeeklyProgress?) {
        do {
            // Fetch incomplete tasks
            let descriptor = FetchDescriptor<ToDoTask>(
                predicate: #Predicate { !$0.completed },
                sortBy: [SortDescriptor(\.due, order: .forward)]
            )
            
            var tasks = try modelContext.fetch(descriptor)
            
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
            
            // Fetch weekly progress
            let weeklyProgress = await fetchWeeklyProgress()
            
            return (tasks, weeklyProgress)
        } catch {
            print("Failed to fetch tasks: \(error)")
            return ([], nil)
        }
    }
    
    func completeTask(taskId: String) async {
        do {
            // Fetch all incomplete tasks and filter in Swift
            let descriptor = FetchDescriptor<ToDoTask>(
                predicate: #Predicate { task in
                    !task.completed
                }
            )
            
            let tasks = try modelContext.fetch(descriptor)
            
            // Find the task by ID in Swift code (not in predicate)
            guard let task = tasks.first(where: { String(describing: $0.id) == taskId }) else {
                print("Widget: Task not found with ID: \(taskId)")
                return
            }
            
            print("Widget: Completing task: \(task.name)")
            
            // Mark as completed
            task.completed = true
            task.completedAt = Date()
            
            // Handle recurring tasks
            if task.repeating {
                let nextTask = createNextOccurrence(from: task)
                modelContext.insert(nextTask)
                print("Widget: Created next occurrence for recurring task")
            }
            
            try modelContext.save()
            print("Widget: Task completed successfully")
            
        } catch {
            print("Widget: Failed to complete task: \(error)")
        }
    }
    
    private func createNextOccurrence(from task: ToDoTask) -> ToDoTask {
        let nextDueDate: Date
        
        if let interval = task.recurrenceInterval {
            if interval == .custom {
                nextDueDate = Calendar.current.date(
                    byAdding: .day,
                    value: task.customRecurrenceDays,
                    to: task.due
                ) ?? task.due
            } else {
                nextDueDate = interval.nextDate(from: task.due)
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
            categories: task.categories
        )
        
        return newTask
    }
    
    private func fetchWeeklyProgress() async -> TaskWidgetEntry.WeeklyProgress? {
        do {
            // Get current week start (Monday)
            let calendar = Calendar.current
            let now = Date()
            var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
            components.weekday = 2 // Monday
            let weekStart = calendar.date(from: components) ?? now
            
            // Fetch completed tasks this week
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
            
            // Fetch global target
            let globalDescriptor = FetchDescriptor<GlobalTargetSettings>()
            let globalSettings = try modelContext.fetch(globalDescriptor).first
            let globalTarget = globalSettings?.weeklyGlobalTarget ?? 0
            
            // Fetch categories with targets
            let categoryDescriptor = FetchDescriptor<Category>(
                predicate: #Predicate { $0.weeklyTarget > 0 }
            )
            let categoriesWithTargets = try modelContext.fetch(categoryDescriptor)
            
            // Calculate category progress
            let categoryProgress = categoriesWithTargets.map { category in
                let completed = weekCompleted.filter { task in
                    task.categories.contains(category)
                }.count
                
                return (
                    name: category.name,
                    completed: completed,
                    target: category.weeklyTarget,
                    color: category.color.rawValue
                )
            }
            
            if globalTarget > 0 || !categoryProgress.isEmpty {
                return TaskWidgetEntry.WeeklyProgress(
                    completed: weekCompleted.count,
                    target: globalTarget,
                    categories: categoryProgress
                )
            }
            
            return nil
        } catch {
            print("Failed to fetch weekly progress: \(error)")
            return nil
        }
    }
}

import SwiftData
import Foundation

@ModelActor
actor SharedDataActor {
    static let shared = SharedDataActor(modelContainer: {
        do {
            return try ModelContainer(for: ToDoTask.self, Category.self, GlobalTargetSettings.self)
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

extension SharedDataActor {
    func getTasksForWidget(filter: WidgetTaskFilter, categoryId: String?) -> [ToDoTask] {
        do {
            let descriptor = FetchDescriptor<ToDoTask>(
                predicate: #Predicate { !$0.completed },
                sortBy: [SortDescriptor(\.due, order: .forward)]
            )
            
            var tasks = try modelContext.fetch(descriptor)
            print("getTasksForWidget :: Total Tasks \(tasks.count)")
            
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
            }
            
            // Apply category filter if specified
            if let categoryId = categoryId {
                tasks = tasks.filter { task in
                    task.categories.contains { String(describing: $0.id) == categoryId }
                }
            }
            
            return tasks
        } catch {
            print("Failed to fetch tasks for widget: \(error)")
            return []
        }
    }
}

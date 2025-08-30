import SwiftData
import Foundation

@ModelActor
actor SharedDataActor {
    static let shared = SharedDataActor(modelContainer: {
        do {
            return try ModelContainer(for: ToDoTask.self, Category.self)
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
        let task = ToDoTask(name: name)
        task.pomodoroTime = duration
        task.repeating = repeating
        
        let categories = getCategories().filter { categoryIds.contains($0.id.storeIdentifier ?? "") }
        task.categories = categories
        
        modelContext.insert(task)
        
        do {
            try modelContext.save()
        } catch {
            print("Failed to save task: \(error)")
        }
    }
}

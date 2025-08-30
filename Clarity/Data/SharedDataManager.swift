//
//  SharedDataManager.swift
//  Clarity
//
//  Created by Craig Peters on 30/08/2025.
//

// Create a shared data manager
import SwiftData
import Foundation

class SharedDataManager {
    static let shared = SharedDataManager()
    private var container: ModelContainer
    
    init() {
        do {
            container = try ModelContainer(for: ToDoTask.self, Category.self)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }
    
    func getCategories () async -> [Category] {
        do {
            let descriptor = FetchDescriptor<Category>()
            return try await container.mainContext.fetch(descriptor)
        } catch {
            print("Failed to fetch categories: \(error)")
                        return []
        }
    }
    
    func addTask(name: String, duration: TimeInterval, repeating: Bool, categoryIds: [String]) async {
        let task = ToDoTask(name: name)
        task.pomodoroTime = duration
        task.repeating = repeating
        
        let categories = await getCategories().filter { categoryIds.contains($0.id.debugDescription) }
        task.categories = categories
        
        await MainActor.run {
            container.mainContext.insert(task)
            do {
                try container.mainContext.save()
            } catch {
                print("Failed to save task: \(error)")
            }
        }
        

    }
}


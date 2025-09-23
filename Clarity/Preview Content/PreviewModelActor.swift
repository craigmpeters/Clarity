//
//  PreviewContainer.swift
//  Clarity
//
//  Created by Craig Peters on 22/09/2025.
//
import SwiftData
import Foundation

@MainActor
final class PreviewData {
    
    static let shared = PreviewData()
    
    let previewContainer: ModelContainer
    
    var previewContext: ModelContext {
        previewContainer.mainContext
    }
    
    private init() {
        let schema = Schema([
            ToDoTask.self,
            Category.self,
            GlobalTargetSettings.self
        ])
        
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true,
            allowsSave: true,
        )
        
        do {
            previewContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
            insertPreviewCategories()
            insertPreviewTasks()
            insertPreviewGlobalTarget()
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
        
    }
    
    // MARK: Public Functions
    
    
    func getCategories() -> [Category] {
        do {
            let descriptor = FetchDescriptor<Category>()
            return try previewContext.fetch(descriptor)
        } catch {
            print("Failed to fetch categories: \(error)")
            return []
        }
    }
    
    func getCategory() -> Category {
        return getCategories().first!
    }
    
    func getToDoTasks() -> [ToDoTask] {
        do {
            let descriptor = FetchDescriptor<ToDoTask>()
            return try previewContext.fetch(descriptor)
        } catch {
            print("Failed to fetch tasks: \(error)")
            return []
        }
    }
    
    func getToDoTask() -> ToDoTask {
        return getToDoTasks().first!
    }
    
    // MARK: Functions to insert Preview Data
    
    private func insertPreviewCategories(){
        let categories = [
            Category(name: "Work", color: .Blue, weeklyTarget: 8),
            Category(name: "Personal", color: .Green, weeklyTarget: 5),
            Category(name: "Learning", color: .Purple, weeklyTarget: 3),
            Category(name: "Health", color: .Red, weeklyTarget: 7),
            Category(name: "Creative", color: .Orange, weeklyTarget: 2),
            Category(name: "Urgent", color: .Yellow, weeklyTarget: 0),
            Category(name: "Planning", color: .Cyan, weeklyTarget: 2)
        ]
        
        for category in categories {
            previewContext.insert(category)
        }
        
        saveContext()
    }
    
    private func insertPreviewTasks(){
        // Get existing categories or create basic ones
        let categories = getCategories()
        if categories.isEmpty {
            insertPreviewCategories()
        }

        let workCategory = categories.first { $0.name == "Work" }
        let personalCategory = categories.first { $0.name == "Personal" }
        let learningCategory = categories.first { $0.name == "Learning" }
        
        let sampleTasks = [
            // Overdue tasks
            ("Review quarterly reports", 25, Date().addingTimeInterval(-86400), [workCategory].compactMap { $0 }),
            
            // Today's tasks
            ("Team standup meeting prep", 15, Date(), [workCategory].compactMap { $0 }),
            ("Grocery shopping", 5, Date(), [personalCategory].compactMap { $0 }),
            ("SwiftUI documentation reading", 25, Date(), [learningCategory].compactMap { $0 }),
            
            // Tomorrow's tasks
            ("Client presentation slides", 10, Date().addingTimeInterval(86400), [workCategory].compactMap { $0 }),
            ("Doctor appointment", 5, Date().addingTimeInterval(86400), [personalCategory].compactMap { $0 }),
            
            // This week
            ("Code review session", 25, Date().addingTimeInterval(86400 * 2), [workCategory].compactMap { $0 }),
            ("Weekend hiking preparation", 20, Date().addingTimeInterval(86400 * 3), [personalCategory].compactMap { $0 }),
            ("iOS 18 features research", 25, Date().addingTimeInterval(86400 * 4), [learningCategory].compactMap { $0 }),
        ]
        
        for (name, minutes, dueDate, taskCategories) in sampleTasks {
            let task = ToDoTask(
                name: name,
                pomodoroTime: TimeInterval(minutes * 60),
                due: dueDate,
                categories: taskCategories
            )
            previewContext.insert(task)
        }
        saveContext()
    }
    
    private func insertPreviewGlobalTarget() {
        let settings = GlobalTargetSettings()
        settings.weeklyGlobalTarget = 10
        previewContext.insert(settings)
        
    }
    
    private func saveContext() {
        do {
            try previewContext.save()
        } catch {
            print("Failed to save context: \(error)")
        }
    }
}


//
//  CreateTaskIntent.swift
//  Clarity
//
//  Created by Craig Peters on 30/08/2025.
//

import Foundation
import AppIntents

struct CreateTaskIntent: AppIntent {
    @Dependency var store: DataStore
    static var title: LocalizedStringResource = "Create Task"
    static var description = IntentDescription("Create a new task in Clarity")
    static var openAppWhenRun: Bool = false
    
    @Parameter(title: "Task Name")
    var taskName: String
    
    @Parameter(title: "Duration (Minutes)", default: 5)
    var duration: Int
    
    @Parameter(title: "Repeating Task?", default: false)
    var isRepeating: Bool
    
    @Parameter(title: "Categories")
    var categories: [CategoryEntity]?
    
    func perform() async throws -> some IntentResult {
        print("Received categoryIds: \(String(describing: categories))")
        
        await store.addTask(
            name: taskName,
            duration: TimeInterval(duration * 60),
            repeating: isRepeating,
            categoryIds: categories?.map { $0.id } ?? []
        )
        
        return .result()
    }
}

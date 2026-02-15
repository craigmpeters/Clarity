//
//  CreateTaskIntent.swift
//  Clarity
//
//  Created by Craig Peters on 30/08/2025.
//

import Foundation
import AppIntents

struct CreateTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "Create Task"
    static var description = IntentDescription("Create a new task in Clarity")
    static var openAppWhenRun: Bool = false
    
    @Parameter(title: "Task Name", requestValueDialog: "What’s the task name?")
    var taskName: String
    
    @Parameter(title: "Duration (Minutes)", default: 5)
    var duration: Int
    
    @Parameter(title: "Repeating Task?", default: false)
    var isRepeating: Bool
    
    @Parameter(title: "Categories")
    var categories: [CategoryEntity]
    
    func perform() async throws -> some IntentResult {
        let availableCategories = ClarityServices.snapshotCategories()
        let selectedCategoryDTOs: [CategoryDTO] = categories.compactMap { entity in
            availableCategories.first(where: { $0.name == entity.name })
        }

        let dto = ToDoTaskDTO(
            name: taskName,
            pomodoroTime: TimeInterval(duration * 60),
            repeating: isRepeating,
            categories: selectedCategoryDTOs
        )
        let store = try await ClarityServices.store()
        _ = try await store.addTask(dto)
        
        ClarityServices.reloadWidgets(kind: "ClarityTaskWidget")
        
        return .result()
    }
}

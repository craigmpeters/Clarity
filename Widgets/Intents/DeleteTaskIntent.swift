//
//  DeleteTaskIntent.swift
//  Clarity
//
//  Created by Craig Peters on 02/12/2025.
//

import AppIntents

struct DeleteTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "Delete a Task"
    static var description = IntentDescription("Delete a task in Clarity")
    
    static var parameterSummary: some ParameterSummary {
        Summary("Delete a Task")
    }

    
    @Parameter(title: "Task")
    var task: TaskEntity
    
    init() {} // required
    
    init(task: TaskEntity) {
        self.task = task
    }
    
    func perform() async throws -> some IntentResult & ProvidesDialog {
        do {
            let store = try await ClarityServices.store()
            guard let dto = try await store.fetchTaskByUuid(UUID(uuidString: task.id)!) else {
                return .result(dialog: "Invalid task Identifier.")
            }
            
            try await store.deleteTask(dto.id!)
            return .result(dialog: "Deleted Task: \(dto.name)")
            
        } catch {
            return .result(dialog: "Couldn’t delete task: \(error.localizedDescription)")
        }
        
    }

    
}

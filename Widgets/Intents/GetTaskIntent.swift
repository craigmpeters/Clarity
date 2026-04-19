//
//  GetTaskIntent.swift
//  Clarity
//
//  Created by Craig Peters on 05/04/2026.
//

import AppIntents


struct GetTaskIntent : AppIntent {
    
    static var title: LocalizedStringResource = "Get Task Details"
    static var description = IntentDescription("Get Details about a task")
    
    static var parameterSummary: some ParameterSummary {
        Summary("Get \(\.$task) details in Clarity")
    }

    
    @Parameter(title: "Task")
    var task: TaskEntity
    
    init() {} // required
    
    init(task: TaskEntity) {
        self.task = task
    }
    
    
    func perform() async throws -> some IntentResult & ReturnsValue<TaskDetailEntity> {
        let store = try await ClarityServices.store()
        let uuid = UUID(uuidString: task.id)!
        guard let dto = try await store.fetchTaskByUuid(uuid) else {
            throw $task.needsValueError("Could not find task, please try again.")
        }
        let lastCompletedAt = try await store.fetchLastCompletedAt(uuid: uuid)
        return .result(value: TaskDetailEntity(from: dto, lastCompletedAt: lastCompletedAt))
    }
    
    
}

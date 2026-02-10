import AppIntents
import SwiftData
import OSLog
#if canImport(WidgetKit)
import WidgetKit
#endif

struct CompleteTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "Complete Task"
    static var description = IntentDescription("Mark a task as completed")
    static var openAppWhenRun = false
    private var taskUuid: String?

    // Change to task UUID
    @Parameter(title: "Task")
    var task: TaskEntity

    init() {} // required
    
    init(task: TaskEntity) {
        self.task = task
    }

    static var parameterSummary: some ParameterSummary {
        Summary("Complete task")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        do {
            
            let store = try await ClarityServices.store() // non-CloudKit container in extensions
            
            let taskId: UUID? = {
                if let taskUuid, let u = UUID(uuidString: taskUuid) {
                    return u
                }
                return UUID(uuidString: task.id)
            }()
            
            // Fetch DTO and ensure it's present
            guard let dto = try await store.fetchTaskByUuid(taskId!) else {
                return .result(dialog: "Invalid task Identifier.")
            }

            let uuid = dto.uuid
            try await store.completeTask(uuid)

            ClarityServices.reloadWidgets(kind: "ClarityWidget")
            return .result(dialog: "Task completed")
        } catch {
            os_log("CompleteTaskIntent error: %{public}@", String(describing: error))
            return .result(dialog: "Couldn’t complete the task.")
        }
    }
}


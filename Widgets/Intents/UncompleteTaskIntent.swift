import AppIntents
import SwiftData
import OSLog
import XCGLogger
#if canImport(WidgetKit)
import WidgetKit
#endif

struct UncompleteTaskIntent: AppIntent {
    static let title: LocalizedStringResource = "Uncomplete Task"
    static let description = IntentDescription("Mark a completed task as incomplete")
    static let openAppWhenRun = false
    
    @Parameter(title: "Task")
    var task: TaskEntity

    init() {}
    
    init(task: TaskEntity) {
        self.task = task
    }

    static var parameterSummary: some ParameterSummary {
        Summary("Uncomplete task")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        do {
            let store = try await ClarityServices.store()
            
            guard let taskUUID = UUID(uuidString: task.id) else {
                return .result(dialog: "Invalid task identifier.")
            }
            
            // Fetch DTO and ensure it's completed
            guard let dto = try await store.fetchTaskByUuid(taskUUID) else {
                return .result(dialog: "Task not found.")
            }
            
            guard dto.completed else {
                return .result(dialog: "Task is not completed.")
            }

            let uuid = dto.uuid
            LogManager.shared.log.debug("Uncompleting task with ID: \(uuid)")
            try await store.uncompleteTask(uuid)

            ClarityServices.reloadWidgets(kind: "ClarityWidget")
            return .result(dialog: "Task marked as incomplete")
        } catch {
            os_log("UncompleteTaskIntent error: %{public}@", String(describing: error))
            return .result(dialog: "Couldn't uncomplete the task.")
        }
    }
}

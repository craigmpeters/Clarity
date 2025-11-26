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

    // Change to task UUID
    @Parameter(title: "Task ID")
    var taskUuid: String

    init() {} // required
    
    init(id: UUID) {
        self.taskUuid = id.uuidString
    }

    static var parameterSummary: some ParameterSummary {
        Summary("Complete task")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        do {
            // Parse UUID safely
            guard let uuid = UUID(uuidString: taskUuid) else {
                return .result(dialog: "Invalid task identifier.")
            }

            let store = try await ClarityServices.store() // non-CloudKit container in extensions

            // Fetch DTO and ensure it's present
            guard let dto = try await store.fetchTaskByUuid(uuid) else {
                return .result(dialog: "Invalid task Identifier.")
            }

            let taskID = dto.id
            try await store.completeTask(taskID!)

            ClarityServices.reloadWidgets(kind: "ClarityWidget")
            return .result(dialog: "Task completed")
        } catch {
            os_log("CompleteTaskIntent error: %{public}@", String(describing: error))
            return .result(dialog: "Couldn’t complete the task.")
        }
    }
}


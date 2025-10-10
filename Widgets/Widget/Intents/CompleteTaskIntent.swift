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

    // 👇 MUST be a @Parameter so AppIntents serializes it across processes.
    @Parameter(title: "Encoded Task ID")
    var encodedId: String

    init() {} // required

    // Convenience init for widget code
    init(id: PersistentIdentifier) {
        let data = try! JSONEncoder().encode(id)
        self.encodedId = data.base64EncodedString()
    }

    static var parameterSummary: some ParameterSummary {
        Summary("Complete task")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        // Decode ID
        guard
            let data = Data(base64Encoded: encodedId),
            let id = try? JSONDecoder().decode(PersistentIdentifier.self, from: data)
        else {
            return .result(dialog: "Task not found")
        }

        do {
            let store = try await ClarityServices.store() // non-CloudKit container in extensions
            try await store.completeTask(id)
            ClarityServices.reloadWidgets(kind: "ClarityWidget")
            return .result(dialog: "Task completed")
        } catch {
            os_log("CompleteTaskIntent error: %{public}@", String(describing: error))
            return .result(dialog: "Couldn’t complete the task.")
        }
    }
}


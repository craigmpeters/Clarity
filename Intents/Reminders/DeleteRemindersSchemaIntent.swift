//
//  DeleteRemindersSchemaIntent.swift
//  Clarity
//
//  App Intents schema intent for deleting reminders in the reminders domain.
//

import AppIntents
import Foundation

@available(iOS 27, macOS 27, *)
@AppIntent(schema: .reminders.deleteReminders)
struct DeleteRemindersSchemaIntent {
    @Parameter(title: "Target Reminders")
    var entities: [ReminderEntity]

    static let title: LocalizedStringResource = "Delete Reminders"
    static let description = IntentDescription("Delete reminders in Clarity")

    func perform() async throws -> some IntentResult {
        let store = try await ClarityServices.store()
        for entity in entities {
            guard let (kind, uuid) = ReminderSchemaID.decode(entity.id) else { continue }
            switch kind {
            case .task:
                try await store.deleteTask(uuid: uuid)
            case .habit:
                try await store.deleteHabit(uuid)
            }
        }
        return .result()
    }
}

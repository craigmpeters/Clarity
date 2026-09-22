//
//  CreateListSchemaIntent.swift
//  Clarity
//
//  App Intents schema intent for creating lists in the reminders domain.
//

import AppIntents
import Foundation

@available(iOS 27, macOS 27, *)
@AppIntent(schema: .reminders.createList)
struct CreateListSchemaIntent {
    @Parameter(title: "Name")
    var name: String

    @Parameter(title: "Type")
    var type: ReminderListType

    static let title: LocalizedStringResource = "Create List"
    static let description = IntentDescription("Create a list in Clarity")

    func perform() async throws -> some IntentResult & ReturnsValue<ReminderListEntity> {
        let store = try await ClarityServices.store()
        let dto = CategoryDTO(
            id: nil,
            name: name,
            color: .Blue,
            weeklyTarget: 0
        )
        let saved = try await store.addCategory(dto)
        let entity = ReminderListEntity(
            id: saved.uuid?.uuidString ?? saved.name,
            name: saved.name
        )
        return .result(value: entity)
    }
}

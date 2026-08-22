//
//  CreateReminderSchemaIntent.swift
//  Clarity
//
//  App Intents schema intent for creating reminders in the reminders domain.
//

import AppIntents
import Foundation
import UniformTypeIdentifiers

@available(iOS 27, macOS 27, *)
@AppIntent(schema: .reminders.createReminder)
struct CreateReminderSchemaIntent {
    @Parameter(title: "Title")
    var title: String

    @Parameter(title: "List")
    var list: ReminderListEntity?

    @Parameter(title: "Due Date")
    var dueDate: DateComponents?

    @Parameter(title: "Recurrence")
    var recurrence: Calendar.RecurrenceRule?

    @Parameter(title: "Images", supportedTypeIdentifiers: ["public.image"])
    var images: [IntentFile]

    // Required schema properties that Clarity does not persist.
    @Parameter(title: "Note")
    var note: AttributedString?

    @Parameter(title: "Is Flagged")
    var isFlagged: Bool?

    @Parameter(title: "Tags")
    var tags: Set<String>

    @Parameter(title: "URLs")
    var urls: [URL]

    @Parameter(title: "Priority")
    var priority: Int?

    @Parameter(title: "Location Trigger")
    var locationTrigger: ReminderLocationTriggerEntity?

    @Parameter(title: "Section")
    var section: ReminderSectionEntity?

    // Custom routing parameter: defaults to Task when not supplied by Siri.
    @Parameter(title: "Kind")
    var kind: ReminderKind?

    static let title: LocalizedStringResource = "Create Reminder"
    static let description = IntentDescription("Create a reminder in Clarity")

    func perform() async throws -> some IntentResult & ReturnsValue<ReminderEntity> {
        let store = try await ClarityServices.store()
        let allCategories = try await store.getCategories()
        let targetList = list ?? ReminderSchemaList.entity(for: nil, allCategories: allCategories)
        let category = ReminderSchemaCategory.resolve(targetList, from: allCategories)

        let due = ReminderSchemaDate.date(from: dueDate)
        let (interval, customDays, specificDay) = ReminderSchemaRecurrence.recurrenceInterval(from: recurrence)
        let kind = self.kind ?? .task

        switch kind {
        case .task:
            let dto = ToDoTaskDTO(
                name: title,
                repeating: recurrence != nil,
                recurrenceInterval: interval,
                customRecurrenceDays: customDays,
                due: due,
                everySpecificDayDay: specificDay ?? 0,
                categories: category.map { [$0] } ?? []
            )
            let saved = try await store.addTask(dto)
            return .result(
                value: ReminderEntity(
                    task: saved,
                    category: saved.categories.first,
                    allCategories: allCategories
                )
            )
        case .habit:
            let dto = HabitDTO(
                name: title,
                dailyTarget: 1,
                categories: category.map { [$0] } ?? []
            )
            let saved = try await store.addHabit(dto)
            return .result(
                value: ReminderEntity(
                    habit: saved,
                    category: saved.categories.first,
                    allCategories: allCategories
                )
            )
        }
    }
}

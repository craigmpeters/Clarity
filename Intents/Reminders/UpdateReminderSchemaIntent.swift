//
//  UpdateReminderSchemaIntent.swift
//  Clarity
//
//  App Intents schema intent for updating reminders in the reminders domain.
//

import AppIntents
import Foundation

@available(iOS 27, macOS 27, *)
@AppIntent(schema: .reminders.updateReminder)
struct UpdateReminderSchemaIntent {
    @Parameter(title: "Target Reminder")
    var target: ReminderEntity

    @Parameter(title: "Title")
    var title: String?

    @Parameter(title: "Due Date")
    var dueDate: DateComponents?

    @Parameter(title: "Recurrence")
    var recurrence: Calendar.RecurrenceRule?

    @Parameter(title: "Is Completed")
    var isCompleted: Bool?

    @Parameter(title: "List")
    var list: ReminderListEntity?

    // Required schema properties that Clarity does not persist.
    @Parameter(title: "Note")
    var note: AttributedString?

    @Parameter(title: "Is Flagged")
    var isFlagged: Bool?

    @Parameter(title: "Tags")
    var tags: Set<String>?

    @Parameter(title: "URLs")
    var urls: [URL]?

    @Parameter(title: "Priority")
    var priority: Int?

    @Parameter(title: "Location Trigger")
    var locationTrigger: ReminderLocationTriggerEntity?

    static let title: LocalizedStringResource = "Update Reminder"
    static let description = IntentDescription("Update a reminder in Clarity")

    func perform() async throws -> some IntentResult & ReturnsValue<ReminderEntity> {
        let store = try await ClarityServices.store()
        guard let (kind, uuid) = ReminderSchemaID.decode(target.id) else {
            throw ReminderSchemaError.unresolvableReminder
        }

        let allCategories = try await store.getCategories()
        let targetList = list ?? target.list
        let category = ReminderSchemaCategory.resolve(targetList, from: allCategories)

        switch kind {
        case .task:
            let existing = try await store.fetchTaskByUuidIncludingCompleted(uuid)
            guard var dto = existing else { throw ReminderSchemaError.unresolvableReminder }

            if let title { dto.name = title }
            if let dueDate { dto.due = ReminderSchemaDate.date(from: dueDate) }
            if let recurrence {
                let (interval, customDays, specificDay) = ReminderSchemaRecurrence.recurrenceInterval(from: recurrence)
                dto.repeating = true
                dto.recurrenceInterval = interval
                dto.customRecurrenceDays = customDays
                dto.everySpecificDayDay = specificDay ?? 0
            }
            if let category { dto.categories = [category] }

            if title != nil || dueDate != nil || recurrence != nil || category != nil {
                dto = try await store.updateTask(dto)
            }

            if let isCompleted {
                if isCompleted {
                    try await store.completeTask(uuid)
                } else {
                    try await store.uncompleteTask(uuid)
                }
                // Re-fetch because completing a recurring task may spawn the next occurrence.
                dto = try await store.fetchTaskByUuidIncludingCompleted(uuid) ?? dto
            }
            return .result(
                value: ReminderEntity(
                    task: dto,
                    category: dto.categories.first,
                    allCategories: allCategories
                )
            )

        case .habit:
            let existing = try await store.fetchHabit(uuid)
            guard var dto = existing else { throw ReminderSchemaError.unresolvableReminder }

            if let title { dto.name = title }
            if let category { dto.categories = [category] }

            if let isCompleted {
                let amount = isCompleted ? dto.dailyTarget : 0
                _ = try await store.setHabitProgress(uuid, date: .now, amount: amount)
            } else if title != nil || category != nil {
                dto = try await store.updateHabit(dto)
            }

            let startOfDay = Calendar.current.startOfDay(for: .now)
            let occurrence = try? await store.fetchHabitHistory(uuid, from: startOfDay, to: .now).first
            return .result(
                value: ReminderEntity(
                    habit: dto,
                    occurrence: occurrence,
                    category: dto.categories.first,
                    allCategories: allCategories
                )
            )
        }
    }
}

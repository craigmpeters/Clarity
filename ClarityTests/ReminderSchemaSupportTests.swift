//
//  ReminderSchemaSupportTests.swift
//  ClarityTests
//
//  Swift Testing unit tests for reminders-domain App Intents schema mapping.
//

import AppIntents
import Foundation
import Testing

@testable import Clarity

struct ReminderSchemaSupportTests {

    // MARK: - ReminderSchemaID

    @available(iOS 27, macOS 27, *)
    @Test func idEncodeDecodeRoundTrip() {
        let uuid = UUID()
        let taskID = ReminderSchemaID.encode(.task, uuid: uuid)
        let habitID = ReminderSchemaID.encode(.habit, uuid: uuid)

        #expect(taskID == "task-\(uuid.uuidString)")
        #expect(habitID == "habit-\(uuid.uuidString)")

        #expect(ReminderSchemaID.decode(taskID)! == (kind: .task, uuid: uuid))
        #expect(ReminderSchemaID.decode(habitID)! == (kind: .habit, uuid: uuid))
    }

    @available(iOS 27, macOS 27, *)
    @Test func idDecodeRejectsMalformedInput() {
        #expect(ReminderSchemaID.decode("not-a-prefix") == nil)
        #expect(ReminderSchemaID.decode("task-not-a-uuid") == nil)
        #expect(ReminderSchemaID.decode("habit-not-a-uuid") == nil)
        #expect(ReminderSchemaID.decode("") == nil)
    }

    // MARK: - ReminderSchemaRecurrence forward/backward mapping

    @available(iOS 27, macOS 27, *)
    @Test func recurrenceSpecificDayRoundTripCoversBoundaries() {
        for appWeekday in 0...6 {
            let rule = ReminderSchemaRecurrence.recurrenceRule(
                from: .specific,
                customDays: 1,
                specificDay: appWeekday
            )
            let (_, _, decodedSpecificDay) = ReminderSchemaRecurrence.recurrenceInterval(from: rule)
            #expect(decodedSpecificDay == appWeekday, "app weekday \(appWeekday) should round-trip unchanged")
        }
    }

    @available(iOS 27, macOS 27, *)
    @Test func recurrenceSpecificDayOutOfRangeWrapsToValidIndex() {
        // Negative and repeated values wrap to the valid 0...6 index the same way the app does.
        let cases: [Int: Int] = [
            -1: 6,  // Saturday via backward wrap
            7: 0,   // Sunday via forward wrap
            8: 1    // Monday via forward wrap
        ]
        for (input, expected) in cases {
            let rule = ReminderSchemaRecurrence.recurrenceRule(
                from: .specific,
                customDays: 1,
                specificDay: input
            )
            let (_, _, decodedSpecificDay) = ReminderSchemaRecurrence.recurrenceInterval(from: rule)
            #expect(decodedSpecificDay == expected, "input \(input) should map to \(expected)")
        }
    }

    @available(iOS 27, macOS 27, *)
    @Test func recurrenceRoundTripForAllIntervals() {
        let intervals: [ToDoTask.RecurrenceInterval] = [
            .daily, .everyOtherDay, .weekly, .biweekly, .monthly, .specific, .custom
        ]

        for interval in intervals {
            let rule = ReminderSchemaRecurrence.recurrenceRule(
                from: interval,
                customDays: 3,
                specificDay: 2
            )
            let (decodedInterval, decodedCustomDays, decodedSpecificDay) = ReminderSchemaRecurrence.recurrenceInterval(from: rule)

            switch interval {
            case .daily:
                #expect(decodedInterval == .daily)
            case .everyOtherDay:
                #expect(decodedInterval == .everyOtherDay)
            case .weekly:
                #expect(decodedInterval == .weekly)
            case .biweekly:
                #expect(decodedInterval == .biweekly)
            case .monthly:
                #expect(decodedInterval == .monthly)
            case .specific:
                #expect(decodedInterval == .specific)
                #expect(decodedSpecificDay == 2)
            case .custom:
                #expect(decodedInterval == .custom)
                #expect(decodedCustomDays == 3)
            }
        }
    }

    @available(iOS 27, macOS 27, *)
    @Test func recurrenceNilRuleDefaultsToDaily() {
        let (interval, customDays, specificDay) = ReminderSchemaRecurrence.recurrenceInterval(from: nil)
        #expect(interval == .daily)
        #expect(customDays == 1)
        #expect(specificDay == nil)
    }

    // MARK: - ReminderEntity construction

    @available(iOS 27, macOS 27, *)
    @Test func reminderEntityFromTaskDTO() {
        let category = CategoryDTO(
            id: nil,
            name: "Work",
            color: .Blue,
            weeklyTarget: 0,
            uuid: UUID()
        )
        let task = ToDoTaskDTO(
            name: "Submit report",
            repeating: true,
            recurrenceInterval: .daily,
            customRecurrenceDays: 1,
            due: Date(timeIntervalSince1970: 1_000_000),
            everySpecificDayDay: 0,
            categories: [category],
            uuid: UUID()
        )

        let entity = ReminderEntity(
            task: task,
            category: category,
            allCategories: [category]
        )

        #expect(entity.title == "Submit report")
        #expect(entity.id == ReminderSchemaID.encode(.task, uuid: task.uuid))
        #expect(entity.isCompleted == false)
        #expect(entity.list.name == "Work")
    }

    @available(iOS 27, macOS 27, *)
    @Test func reminderEntityFromHabitDTO() {
        let category = CategoryDTO(
            id: nil,
            name: "Health",
            color: .Green,
            weeklyTarget: 0,
            uuid: UUID()
        )
        let habit = HabitDTO(
            uuid: UUID(),
            name: "Drink Water",
            dailyTarget: 8,
            categories: [category]
        )

        let entity = ReminderEntity(
            habit: habit,
            category: category,
            allCategories: [category]
        )

        #expect(entity.title == "Drink Water")
        #expect(entity.id == ReminderSchemaID.encode(.habit, uuid: habit.uuid))
        #expect(entity.isCompleted == false)
        #expect(entity.list.name == "Health")
    }
}

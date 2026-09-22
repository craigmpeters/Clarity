//
//  RemindersSchemaSupport.swift
//  Clarity
//
//  Shared mapping helpers for the App Intents reminders schema.
//

import AppIntents
import Foundation

@available(iOS 27, macOS 27, *)
enum ReminderKind: String, AppEnum, Sendable {
    case task
    case habit

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Reminder Kind")
    }

    static let caseDisplayRepresentations: [ReminderKind: DisplayRepresentation] = [
        .task: DisplayRepresentation(title: "Task"),
        .habit: DisplayRepresentation(title: "Habit")
    ]
}

@available(iOS 27, macOS 27, *)
enum ReminderSchemaError: Error, CustomStringConvertible {
    case unresolvableReminder

    var description: String {
        switch self {
        case .unresolvableReminder:
            return "Could not resolve the reminder."
        }
    }
}

@available(iOS 27, macOS 27, *)
enum ReminderSchemaID {
    static let taskPrefix = "task-"
    static let habitPrefix = "habit-"

    static func encode(_ kind: ReminderKind, uuid: UUID) -> String {
        switch kind {
        case .task: return taskPrefix + uuid.uuidString
        case .habit: return habitPrefix + uuid.uuidString
        }
    }

    static func decode(_ id: String) -> (kind: ReminderKind, uuid: UUID)? {
        if id.hasPrefix(taskPrefix) {
            let raw = String(id.dropFirst(taskPrefix.count))
            guard let uuid = UUID(uuidString: raw) else { return nil }
            return (.task, uuid)
        }
        if id.hasPrefix(habitPrefix) {
            let raw = String(id.dropFirst(habitPrefix.count))
            guard let uuid = UUID(uuidString: raw) else { return nil }
            return (.habit, uuid)
        }
        return nil
    }
}

@available(iOS 27, macOS 27, *)
enum ReminderSchemaDate {
    /// Convert a schema `DateComponents` into a concrete `Date`.
    /// Falls back to the current date when the components cannot be resolved.
    static func date(from components: DateComponents?) -> Date {
        guard let components else { return Date.now }
        return Calendar.current.date(from: components) ?? Date.now
    }
}

@available(iOS 27, macOS 27, *)
enum ReminderSchemaRecurrence {
    /// Map a Clarity `RecurrenceInterval` to a schema `Calendar.RecurrenceRule`.
    static func recurrenceRule(from interval: ToDoTask.RecurrenceInterval, customDays: Int, specificDay: Int?) -> Calendar.RecurrenceRule? {
        switch interval {
        case .daily:
            return Calendar.RecurrenceRule(calendar: .current, frequency: .daily, interval: 1)
        case .everyOtherDay:
            return Calendar.RecurrenceRule(calendar: .current, frequency: .daily, interval: 2)
        case .weekly:
            return Calendar.RecurrenceRule(calendar: .current, frequency: .weekly, interval: 1)
        case .biweekly:
            return Calendar.RecurrenceRule(calendar: .current, frequency: .weekly, interval: 2)
        case .monthly:
            return Calendar.RecurrenceRule(calendar: .current, frequency: .monthly, interval: 1)
        case .specific:
            // App stores everySpecificDayDay as a 0-based index into Calendar.current.weekdaySymbols
            // (0 = Sunday ... 6 = Saturday), while Calendar uses 1-based weekday numbers.
            let appWeekday = specificDay ?? 0
            let normalized = ((appWeekday % 7) + 7) % 7
            let calendarWeekday = normalized + 1
            let localeWeekday = localeWeekday(from: calendarWeekday)
            return Calendar.RecurrenceRule(
                calendar: .current,
                frequency: .weekly,
                interval: 1,
                weekdays: [.every(localeWeekday)]
            )
        case .custom:
            let days = max(customDays, 1)
            return Calendar.RecurrenceRule(calendar: .current, frequency: .daily, interval: days)
        }
    }

    private static func localeWeekday(from calendarWeekday: Int) -> Locale.Weekday {
        switch calendarWeekday {
        case 1: return .sunday
        case 2: return .monday
        case 3: return .tuesday
        case 4: return .wednesday
        case 5: return .thursday
        case 6: return .friday
        case 7: return .saturday
        default: return .monday
        }
    }

    /// Map a schema `Calendar.RecurrenceRule` back to a Clarity `RecurrenceInterval`.
    /// Defaults to `.daily` when the rule is nil or cannot be matched.
    static func recurrenceInterval(from rule: Calendar.RecurrenceRule?) -> (interval: ToDoTask.RecurrenceInterval, customDays: Int, specificDay: Int?) {
        guard let rule else { return (.daily, 1, nil) }
        switch rule.frequency {
        case .daily:
            switch rule.interval {
            case 1: return (.daily, 1, nil)
            case 2: return (.everyOtherDay, 1, nil)
            default: return (.custom, max(rule.interval, 1), nil)
            }
        case .weekly:
            if rule.interval == 2 {
                return (.biweekly, 1, nil)
            } else if rule.interval == 1 {
                let weekdays = rule.weekdays
                if weekdays.count == 1 {
                    let weekday = weekdays[0]
                    switch weekday {
                    case .every(let localeWeekday):
                        return (.specific, 1, appWeekday(from: localeWeekday))
                    default:
                        return (.weekly, 1, nil)
                    }
                } else {
                    return (.weekly, 1, nil)
                }
            } else {
                return (.weekly, 1, nil)
            }
        case .monthly:
            return (.monthly, 1, nil)
        default:
            return (.daily, 1, nil)
        }
    }

    private static func appWeekday(from localeWeekday: Locale.Weekday) -> Int {
        // Calendar weekday numbers are 1-based (1 = Sunday). Convert to the app's 0-based
        // weekdaySymbols index (0 = Sunday ... 6 = Saturday).
        switch localeWeekday {
        case .sunday: return 0
        case .monday: return 1
        case .tuesday: return 2
        case .wednesday: return 3
        case .thursday: return 4
        case .friday: return 5
        case .saturday: return 6
        default: return 1
        }
    }
}

@available(iOS 27, macOS 27, *)
enum ReminderSchemaList {
    /// Build a schema list entity from the given category, falling back to the first available category.
    static func entity(for category: CategoryDTO?, allCategories: [CategoryDTO]) -> ReminderListEntity {
        let resolved = category ?? allCategories.first
        return ReminderListEntity(
            id: resolved?.uuid?.uuidString ?? "default",
            name: resolved?.name ?? "Default"
        )
    }
}

@available(iOS 27, macOS 27, *)
enum ReminderSchemaCategory {
    /// Find a category matching the schema list entity, or return the first available category.
    static func resolve(_ entity: ReminderListEntity, from categories: [CategoryDTO]) -> CategoryDTO? {
        if let match = categories.first(where: { $0.uuid?.uuidString == entity.id }) {
            return match
        }
        return categories.first
    }
}

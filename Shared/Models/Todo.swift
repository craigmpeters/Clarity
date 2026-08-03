//
//  Todo.swift
//  Clarity
//
//  Created by Craig Peters on 17/08/2025.
//

import AppIntents
import Foundation
import Observation
import os
import SwiftData
import SwiftUI

@Model
class ToDoTask {
    var name: String?
    var created: Date = Date()
    var due: Date = Date.now.addingTimeInterval(24 * 60 * 60)
    var pomodoro: Bool = true
    var pomodoroTime: TimeInterval = 25 * 60
    var repeating: Bool?
    var completed: Bool = false
    var completedAt: Date?
    var startedAt: Date?
    var recurrenceInterval: RecurrenceInterval?
    var customRecurrenceDays: Int = 1
    var everySpecificDayDay: Int?
    var uuid: UUID?
    var completionMoodValence: Double?

    @Relationship var categories: [Category]? = []
    
    var recurrenceDescription: String? {
        guard repeating ?? false, let interval = recurrenceInterval else { return nil }
        
        if interval == .custom {
            if customRecurrenceDays == 1 {
                return "Daily"
            } else {
                return "Every \(customRecurrenceDays) days"
            }
        }
        
        if interval == .specific {
            guard let day = everySpecificDayDay else {
                everySpecificDayDay = 1
                return "Every Monday"
            }
            return "Every \(Calendar.current.weekdaySymbols[day])"
        }
        
        return interval.displayName
    }
    
    init(name: String?, pomodoro: Bool = true, pomodoroTime: TimeInterval = 25 * 60, repeating: Bool = false, recurrenceInterval: RecurrenceInterval? = nil, customRecurrenceDays: Int = 1, due: Date = Date(), everySpecificDayDay: Int? = nil, categories: [Category] = [], uuid: UUID? = UUID(), completed: Bool = false, completedAt: Date? = nil, startedAt: Date? = nil) {
        self.name = name ?? ""
        self.created = Date.now
        self.due = due
        self.pomodoro = true // No longer an option
        self.pomodoroTime = pomodoroTime
        self.repeating = repeating
        self.categories = categories
        self.completed = false
        self.recurrenceInterval = recurrenceInterval
        self.everySpecificDayDay = everySpecificDayDay
        self.customRecurrenceDays = customRecurrenceDays
        self.uuid = uuid
        self.completed = completed
        self.completedAt = completedAt
        self.startedAt = startedAt
    }
    
    enum RecurrenceInterval: String, CaseIterable, Codable {
        case daily = "Daily"
        case everyOtherDay = "Every Other Day"
        case weekly = "Weekly"
        case biweekly = "Biweekly"
        case monthly = "Monthly"
        case specific = "Every Specific Day"
        case custom = "Custom"
        
        var displayName: String {
            return rawValue
        }
        
        func nextDate(from date: Date) -> Date {
            let calendar = Calendar.current
            switch self {
            case .daily:
                return calendar.date(byAdding: .day, value: 1, to: date) ?? date
            case .everyOtherDay:
                return calendar.date(byAdding: .day, value: 2, to: date) ?? date
            case .weekly:
                return calendar.date(byAdding: .weekOfYear, value: 1, to: date) ?? date
            case .biweekly:
                return calendar.date(byAdding: .weekOfYear, value: 2, to: date) ?? date
            case .monthly:
                return calendar.date(byAdding: .month, value: 1, to: date) ?? date
            case .custom:
                // For custom, we'll use the customRecurrenceDays property
                return date
            case .specific:
                // Use the specificDay property
                return date
            }
         }
    }
    
    enum TaskFilter: String, CaseIterable {
        case all = "All Tasks"
        case overdue = "Overdue"
        case today = "Today"
        case tomorrow = "Tomorrow"
        case thisWeek = "This Week"
        
        func matches(task: ToDoTask) -> Bool {
            switch self {
            case .all:
                return true
            case .overdue:
                return task.due < Calendar.current.startOfDay(for: Date())
            case .today:
                return Calendar.current.isDateInToday(task.due)
            case .tomorrow:
                return Calendar.current.isDateInTomorrow(task.due)
            case .thisWeek:
                let startOfWeek = Calendar.current.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
                let endOfWeek = Calendar.current.dateInterval(of: .weekOfYear, for: Date())?.end ?? Date()
                return task.due >= startOfWeek && task.due <= endOfWeek
            }
        }
    }
}

public struct ToDoTaskDTO: Sendable, Codable, Hashable {
    var id: PersistentIdentifier?
    var name: String
    var created: Date
    var due: Date
    var pomodoro: Bool
    var pomodoroTime: TimeInterval
    var repeating: Bool
    var completed: Bool
    var completedAt: Date?
    var startedAt: Date?
    var recurrenceInterval: ToDoTask.RecurrenceInterval?
    var customRecurrenceDays: Int
    var everySpecificDayDay: Int
    var categories: [CategoryDTO]
    var uuid: UUID
    var completionMoodValence: Double?
    nonisolated init(id: PersistentIdentifier? = nil, name: String?, pomodoro: Bool = true, pomodoroTime: TimeInterval = 25 * 60, repeating: Bool = false, recurrenceInterval: ToDoTask.RecurrenceInterval? = nil, customRecurrenceDays: Int = 1, due: Date = Date(), everySpecificDayDay: Int = 0, categories: [CategoryDTO] = [], uuid: UUID? = UUID(), completed: Bool = false, completedAt: Date? = nil, startedAt: Date? = nil, completionMoodValence: Double? = nil) {
        self.id = id
        self.name = name ?? ""
        self.created = Date.now
        self.completed = completed
        self.completedAt = completedAt
        self.due = due
        self.pomodoro = true // No longer an option
        self.pomodoroTime = pomodoroTime
        self.repeating = repeating
        self.categories = categories
        self.recurrenceInterval = recurrenceInterval
        self.customRecurrenceDays = customRecurrenceDays
        self.everySpecificDayDay = everySpecificDayDay
        self.uuid = uuid ?? UUID()
        self.startedAt = startedAt
        self.completionMoodValence = completionMoodValence
    }
    
//    var encodedId: String? {
//        guard let id else { return nil }
//        guard let data = try? JSONEncoder().encode(id) else { return nil }
//        return data.base64EncodedString()
//    }
//
//    public static func decodeId(_ encodedId: String) throws -> UUID? {
//        guard let data = Data(base64Encoded: encodedId) else {
//            throw NSError(domain: "ToDo", code: 0, userInfo: nil)
//        }
//        return try JSONDecoder().decode(UUID.self, from: data)
//    }
}

extension ToDoTaskDTO {
    nonisolated init(from model: ToDoTask) {
        self.init(
            id: model.persistentModelID,
            name: model.name,
            pomodoro: model.pomodoro,
            pomodoroTime: model.pomodoroTime,
            repeating: model.repeating ?? false,
            recurrenceInterval: model.recurrenceInterval,
            customRecurrenceDays: model.customRecurrenceDays,
            due: model.due,
            everySpecificDayDay: model.everySpecificDayDay ?? 1,
            categories: (model.categories ?? []).map(CategoryDTO.init(from:)),
            uuid: model.uuid ?? UUID(),
            completed: model.completed,
            completedAt: model.completedAt,
            startedAt: model.startedAt,
            completionMoodValence: model.completionMoodValence
        )
    }
    
    // TODO: Remove Duplication
    public nonisolated static func focusFilter(in tasks: [ToDoTaskDTO]) -> [ToDoTaskDTO] {
        let defaults = UserDefaults(suiteName: "group.me.craigpeters.clarity")
        let focusData = defaults?.data(forKey: "ClarityFocusFilter")
        guard let focusData, let settings = try? JSONDecoder().decode(_FocusFilterRaw.self, from: focusData) else {
            return tasks
        }

        let focusedNames = Set(settings.Categories)
        let isHide = settings.showOrHide == "hide"

        func hasAllowedCategory(_ task: ToDoTaskDTO, allowed: Set<String>) -> Bool {
            let categoryNames = task.categories.map { $0.name }
            if categoryNames.isEmpty { return !isHide }
            return categoryNames.contains { focusedNames.contains($0) }
        }

        if isHide {
            return tasks.filter { !hasAllowedCategory($0, allowed: focusedNames) }
        } else {
            return tasks.filter { hasAllowedCategory($0, allowed: focusedNames) }
        }
    }
}

// Plain decode-only mirror of CategoryFilterSettings.
// Avoids AppEntity/AppEnum isolation bleed by using only plain Swift types.
// Explicit Decodable conformance prevents @MainActor synthesis from @Model context.
private struct _FocusFilterRaw {
    var Categories: [String]
    var showOrHide: String  // raw value of FilterShowOrHide ("show" or "hide")
}

extension _FocusFilterRaw: Decodable {
    private enum CodingKeys: String, CodingKey { case Categories, showOrHide }
    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.Categories = try container.decode([String].self, forKey: .Categories)
        self.showOrHide = try container.decode(String.self, forKey: .showOrHide)
    }
}

extension ToDoTask {
    static func focusFilter(in tasks: [ToDoTask]) -> [ToDoTask] {
        let defaults = UserDefaults(suiteName: "group.me.craigpeters.clarity")
        let focusData = defaults?.data(forKey: "ClarityFocusFilter")
        guard let focusData, let settings = try? JSONDecoder().decode(_FocusFilterRaw.self, from: focusData) else {
            return tasks
        }

        let focusedNames = Set(settings.Categories)
        let isHide = settings.showOrHide == "hide"

        func hasAllowedCategory(_ task: ToDoTask, allowed: Set<String>) -> Bool {
            let categoryNames = (task.categories ?? []).compactMap { $0.name }
            if categoryNames.isEmpty { return !isHide }
            return categoryNames.contains { focusedNames.contains($0) }
        }

        if isHide {
            return tasks.filter { !hasAllowedCategory($0, allowed: focusedNames) }
        } else {
            return tasks.filter { hasAllowedCategory($0, allowed: focusedNames) }
        }
    }
}

extension ToDoTask.TaskFilter {
    nonisolated func matches(task: ToDoTask, at now: Date, calendar: Calendar = .current) -> Bool {
        switch self {
        case .all:
            return true
        case .overdue:
            return task.due < calendar.startOfDay(for: now)
        case .today:
            return calendar.isDate(task.due, inSameDayAs: now)
        case .tomorrow:
            guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) else { return false }
            return calendar.isDate(task.due, inSameDayAs: tomorrow)
        case .thisWeek:
            guard let di = calendar.dateInterval(of: .weekOfYear, for: now) else { return false }
            return (di.start ... di.end).contains(task.due)
        }
    }
    
    nonisolated func matches(dto: ToDoTaskDTO, at now: Date, calendar: Calendar = .current) -> Bool {
        switch self {
        case .all:
            return true
        case .overdue:
            return dto.due < calendar.startOfDay(for: now)
        case .today:
            return calendar.isDate(dto.due, inSameDayAs: now)
        case .tomorrow:
            guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) else { return false }
            return calendar.isDate(dto.due, inSameDayAs: tomorrow)
        case .thisWeek:
            guard let di = calendar.dateInterval(of: .weekOfYear, for: now) else { return false }
            return (di.start ... di.end).contains(dto.due)
        }
    }
}

extension ToDoTask.TaskFilter {
    var systemImage: String {
        switch self {
        case .all: return "tray.full"
        case .today: return "calendar.circle"
        case .tomorrow: return "calendar.badge.plus"
        case .thisWeek: return "calendar"
        case .overdue: return "exclamationmark.triangle"
        }
    }
    
    var color: Color {
        switch self {
        case .all: return .gray
        case .today: return .blue
        case .tomorrow: return .green
        case .thisWeek: return .purple
        case .overdue: return .red
        }
    }
}

// MARK: Predicates

extension ToDoTask {
    enum CompletedTaskFilter: String, AppEnum, CaseIterable {
        case Today = "Today"
        case PastWeek = "This Week"
        case Month = "Last Month"
        
        static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Filter")
        static let caseDisplayRepresentations: [CompletedTaskFilter: DisplayRepresentation] = [
            .Today: DisplayRepresentation(title: "Today"),
            .PastWeek: DisplayRepresentation(title: "This Week"),
            .Month: DisplayRepresentation(title: "Last Month")
        ]
        
        static func completedToday() -> (ToDoTaskDTO) -> Bool {
            let cal = Calendar.current
            let now = Date()
            let startOfDay = cal.startOfDay(for: now)
            let endOfDay = cal.date(byAdding: DateComponents(day: 1, second: -1), to: startOfDay) ?? now
            return { task in
                guard let completedAt = task.completedAt else { return false }
                return task.completed && completedAt >= startOfDay && completedAt <= endOfDay
            }
        }
        
        static func completedThisWeek() -> (ToDoTaskDTO) -> Bool {
            let cal = Calendar.current
            let now = Date()
            var comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
            comps.weekday = 2 // Monday
            let weekStart = cal.date(from: comps) ?? now
            let weekEnd = cal.date(byAdding: .day, value: 7, to: weekStart) ?? now
            return { task in
                guard let completed = task.completedAt else { return false }
                return task.completed && completed >= weekStart && completed < weekEnd
            }
        }
        
        func matches(_ dto: ToDoTaskDTO, calendar : Calendar = .current, now: Date = Date()) -> Bool {
            switch self {
            case .Today:
                return calendar.isDate(dto.completedAt ?? Date(), inSameDayAs: now)
            case .PastWeek:
                guard let di = calendar.dateInterval(of: .weekOfYear, for: now) else { return false }
                return (di.start ... di.end).contains(dto.completedAt ?? now)
            case .Month:
                return true
            default:
                return true
            }
        }
        
        
//        switch self {
//        case .all:
//            return true
//        case .overdue:
//            return dto.due < calendar.startOfDay(for: now)
//        case .today:
//            return calendar.isDate(dto.due, inSameDayAs: now)
//        case .tomorrow:
//            guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) else { return false }
//            return calendar.isDate(dto.due, inSameDayAs: tomorrow)
//        case .thisWeek:
//            guard let di = calendar.dateInterval(of: .weekOfYear, for: now) else { return false }
//            return (di.start ... di.end).contains(dto.due)
//        }
    }

    enum TaskFilterOption: String, AppEnum, CaseIterable {
        case today = "Today"
        case tomorrow = "Tomorrow"
        case thisWeek = "This Week"
        case overdue = "Overdue"
        case all = "All Tasks"
        
        static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Filter")
        static let caseDisplayRepresentations: [TaskFilterOption: DisplayRepresentation] = [
            .today: DisplayRepresentation(title: "Today"),
            .tomorrow: DisplayRepresentation(title: "Tomorrow"),
            .thisWeek: DisplayRepresentation(title: "This Week"),
            .overdue: DisplayRepresentation(title: "Overdue"),
            .all: DisplayRepresentation(title: "All Tasks")
        ]
        
        static let filterColor: [TaskFilterOption: Color] = [
            .today: .green,
            .tomorrow: .blue,
            .thisWeek: .blue,
            .overdue: .red,
            .all: .gray
        ]
        
        // FIXME: Is this needed?
        func toTaskFilter() -> ToDoTask.TaskFilter {
            switch self {
            case .today: return .today
            case .tomorrow: return .tomorrow
            case .thisWeek: return .thisWeek
            case .overdue: return .overdue
            case .all: return .all
            }
        }
    }
}


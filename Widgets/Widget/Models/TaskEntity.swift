//
//  TaskEntity.swift
//  Clarity
//
//  Created by Craig Peters on 01/12/2025.
//

import AppIntents
import SwiftUI


struct TaskEntity: AppEntity, Identifiable, Sendable {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Task"
    static var defaultQuery = TaskQuery()

    var id: String
    var name: String
    var date: Date
    var repeating: Bool

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
    static var query = TaskQuery()
}

struct TaskQuery: EntityQuery, Sendable {
    func entities(for identifiers: [String]) async throws -> [TaskEntity] {
        try await allEntities().filter( { identifiers.contains($0.id)})
    }
    
    func suggestedEntities() async throws -> [TaskEntity] {
        try await allEntities()
    }

    func allEntities() async throws -> [TaskEntity] {
        let tasks = ClarityServices.snapshotTasks()
        return tasks.map { TaskEntity(id: $0.uuid.uuidString, name: $0.name, date: $0.due, repeating: $0.repeating) }

    }
}

extension TaskQuery {
    func entities(matching filter: TaskFilterOption) async throws -> [TaskEntity] {
        let all = try await allEntities()
        let now = Date()
        let calendar = Calendar.current
        
        switch filter {
        case .today:
            return all.filter { calendar.isDate($0.date, inSameDayAs: now) }
        case .tomorrow:
            if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) {
                return all.filter { calendar.isDate($0.date, inSameDayAs: tomorrow) }
            }
            return []
        case .thisWeek:
            return all.filter { calendar.isDate($0.date, equalTo: now, toGranularity: .weekOfYear) }
        case .overdue:
            return all.filter { $0.date <  Calendar.current.startOfDay(for: now) }
        case .all:
            return all
        }
    }
}

enum TaskFilterOption: String, AppEnum, CaseIterable {
    case today = "Today"
    case tomorrow = "Tomorrow"
    case thisWeek = "This Week"
    case overdue = "Overdue"
    case all = "All Tasks"
    
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Filter")
    static var caseDisplayRepresentations: [TaskFilterOption: DisplayRepresentation] = [
        .today: DisplayRepresentation(title: "Today"),
        .tomorrow: DisplayRepresentation(title: "Tomorrow"),
        .thisWeek: DisplayRepresentation(title: "This Week"),
        .overdue: DisplayRepresentation(title: "Overdue"),
        .all: DisplayRepresentation(title: "All Tasks")
    ]
    
    static var filterColor: [TaskFilterOption: Color] = [
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

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
        //let tasks = ClarityServices.snapshotTasks()
        var tasks : [ToDoTaskDTO] = []
        do {
            tasks = try WidgetFileCoordinator.shared.readTasks()
        } catch {
            print("Failed to read tasks from file DB: \(error)")
        }
        return tasks.map { TaskEntity(id: $0.uuid.uuidString, name: $0.name, date: $0.due, repeating: $0.repeating) }

    }
}

extension TaskQuery {
    func entities(matching filter: ToDoTask.TaskFilterOption) async throws -> [TaskEntity] {
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



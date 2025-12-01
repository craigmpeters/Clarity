//
//  TaskEntity.swift
//  Clarity
//
//  Created by Craig Peters on 01/12/2025.
//

import AppIntents


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

//
//  CreateTaskIntent.swift
//  Clarity
//
//  Created by Craig Peters on 30/08/2025.
//

import Foundation
import AppIntents


// MARK: - AppIntents Entity for Category

struct CategoryEntity: AppEntity, Identifiable, Sendable {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Category"
    static var defaultQuery = CategoryQuery()

    // Use String identifiers to align with repository expectations
    var id: String { name }
    var name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
    
    static var query = CategoryQuery()
}

struct CategoryQuery: EntityQuery, Sendable {
    func entities(for identifiers: [String]) async throws -> [CategoryEntity] {
        try await allEntities().filter( { identifiers.contains($0.id)})
    }
    
    func suggestedEntities() async throws -> [CategoryEntity] {
        try await allEntities()
    }

    func allEntities() async throws -> [CategoryEntity] {
        // Read from the shared store (App Group) without @Query
        let categories = ClarityServices.snapshotCategories()
        return categories
            .map { $0.name }
            .compactMap { $0 }
            .unique()
            .map(CategoryEntity.init(name:))
    }
}

private extension Sequence where Element: Hashable {
    func unique() -> [Element] {
        var set = Set<Element>()
        return self.filter { set.insert($0).inserted }
    }
}

struct CreateTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "Create Task"
    static var description = IntentDescription("Create a new task in Clarity")
    static var openAppWhenRun: Bool = false
    
    @Parameter(title: "Task Name", requestValueDialog: "What’s the task name?")
    var taskName: String
    
    @Parameter(title: "Duration (Minutes)", default: 5)
    var duration: Int
    
    @Parameter(title: "Repeating Task?", default: false)
    var isRepeating: Bool
    
    @Parameter(title: "Categories")
    var categories: [CategoryEntity]
    
    func perform() async throws -> some IntentResult {
        let dto = ToDoTaskDTO(
            name: taskName,
            pomodoroTime: TimeInterval(duration * 60),
            repeating: isRepeating,
            categories: categories.map(\.name)
        )
        let store = try await ClarityServices.store()
        _ = try await store.addTask(dto)
        
        ClarityServices.reloadWidgets(kind: "ClarityWidget")
        
        return .result()
    }
}


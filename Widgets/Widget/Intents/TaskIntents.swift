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
    var id: String
    var name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: LocalizedStringResource(stringLiteral: name))
    }
}

struct CategoryQuery: EntityQuery, Sendable {
    func entities(for identifiers: [CategoryEntity.ID]) async throws -> [CategoryEntity] {
        let categories = try await StaticDataStore.shared.getCategories()
        let mapped = categories.compactMap { cat -> CategoryEntity? in
            let identifier = String(describing: cat.id)
            guard let name = cat.name else { return nil }
            return CategoryEntity(id: identifier, name: name)
        }
        let idSet = Set(identifiers)
        return mapped.filter { idSet.contains($0.id) }
    }

    func suggestedEntities() async throws -> [CategoryEntity] {
        let categories = try await StaticDataStore.shared.getCategories()
        return categories.compactMap { cat in
            let identifier = String(describing: cat.id)
            guard let name = cat.name else { return nil }
            return CategoryEntity(id: identifier, name: name)
        }
    }
}

struct CreateTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "Create Task"
    static var description = IntentDescription("Create a new task in Clarity")
    static var openAppWhenRun: Bool = false
    
    @Parameter(title: "Task Name")
    var taskName: String
    
    @Parameter(title: "Duration (Minutes)", default: 5)
    var duration: Int
    
    @Parameter(title: "Repeating Task?", default: false)
    var isRepeating: Bool
    
    @Parameter(title: "Categories")
    var categories: [CategoryEntity]
    
    func perform() async throws -> some IntentResult {
        print("Received categoryIds: \(String(describing: categories))")
        
        await StaticDataStore.shared.addTask(
            name: taskName,
            duration: TimeInterval(duration * 60),
            repeating: isRepeating,
            categoryIds: categories.map { $0.id }
        )
        
        return .result()
    }
}


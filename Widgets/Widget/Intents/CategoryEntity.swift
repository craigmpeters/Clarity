//
//  CategoryEntity.swift
//  Clarity
//
//  Created by Craig Peters on 01/12/2025.
//

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

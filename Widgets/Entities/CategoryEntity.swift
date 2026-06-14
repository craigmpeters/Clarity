//
//  CategoryEntity.swift
//  Clarity
//
//  Created by Craig Peters on 01/12/2025.
//

import AppIntents


// MARK: - AppIntents Entity for Category

struct CategoryEntity: AppEntity, Identifiable, Sendable {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Category"
    static let defaultQuery = CategoryQuery()

    // Use String identifiers to align with repository expectations
    var id: String { name }
    var name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

// Explicit Codable conformance — avoids @MainActor isolation bleed from AppEntity synthesis
extension CategoryEntity: Codable {
    enum CodingKeys: String, CodingKey { case name }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try container.decode(String.self, forKey: .name)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
    }
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
    nonisolated func unique() -> [Element] {
        var set = Set<Element>()
        return self.filter { set.insert($0).inserted }
    }
}

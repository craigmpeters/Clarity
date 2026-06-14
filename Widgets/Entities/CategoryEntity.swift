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

    /// Stable UUID string — safe across CloudKit sync and process boundaries.
    var id: String
    var name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }

    init(name: String, uuid: UUID? = nil) {
        self.name = name
        // Use the category's UUID when available; fall back to a name-based deterministic value
        // only for legacy records that haven't been backfilled yet.
        self.id = uuid?.uuidString ?? name
    }
}

// Explicit Codable conformance — avoids @MainActor isolation bleed from AppEntity synthesis
extension CategoryEntity: Codable {
    enum CodingKeys: String, CodingKey { case id, name }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try container.decode(String.self, forKey: .name)
        // Decode id if present; fall back to name for legacy encoded values
        self.id = (try? container.decode(String.self, forKey: .id)) ?? self.name
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
    }
}

struct CategoryQuery: EntityQuery, Sendable {
    func entities(for identifiers: [String]) async throws -> [CategoryEntity] {
        try await allEntities().filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [CategoryEntity] {
        try await allEntities()
    }

    func allEntities() async throws -> [CategoryEntity] {
        let categories = ClarityServices.snapshotCategories()
        // Deduplicate by id (uuid-based), preserving order
        var seen = Set<String>()
        return categories.compactMap { dto -> CategoryEntity? in
            let entity = CategoryEntity(name: dto.name, uuid: dto.uuid)
            guard seen.insert(entity.id).inserted else { return nil }
            return entity
        }
    }
}


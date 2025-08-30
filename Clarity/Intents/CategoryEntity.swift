//
//  CategoryEntity.swift
//  Clarity
//
//  Created by Craig Peters on 30/08/2025.
//

import Foundation
import SwiftData
import AppIntents

// First, create an AppEntity for categories
struct CategoryEntity: AppEntity {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Category")
    static var defaultQuery = CategoryQuery()
    
    var id: String
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
    
    let name: String
    let colorRawValue: String
    
    init(from category: Category) {
        self.id = category.id.storeIdentifier ?? "unknown" // Unwrap with nil coalescing
        self.name = category.name
        self.colorRawValue = category.color.rawValue
    }
}

// Query provider for categories
struct CategoryQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [CategoryEntity] { // Fixed typo
        let categories = await SharedDataManager.shared.getCategories()
        return categories.compactMap { category in
            if identifiers.contains(category.id.storeIdentifier ?? "") { // Unwrap here too
                return CategoryEntity(from: category)
            }
            return nil
        }
    }
    
    func suggestedEntities() async throws -> [CategoryEntity] {
        let categories = await SharedDataManager.shared.getCategories()
        return categories.map { CategoryEntity(from: $0) } // Add this return statement
    }
}

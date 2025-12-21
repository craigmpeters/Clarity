//
//  Category.swift
//  Clarity
//
//  Created by Craig Peters on 28/08/2025.
//

import Foundation
import SwiftData
import SwiftUI
import AppIntents

@Model
class Category {
    //TODO: Guard against existing categories on create
    var name: String?
    var color: CategoryColor?
    var weeklyTarget: Int = 0
    @Relationship(inverse: \ToDoTask.categories) var tasks: [ToDoTask]? = []
    
    init(name: String, color: CategoryColor = .Red, weeklyTarget: Int = 0) {
        self.name = name
        self.color = color
        self.weeklyTarget = weeklyTarget
    }
    
    // Example reusable predicate for SwiftData queries. Adjust as needed.
    // Use as: let results = try modelContext.fetch(FetchDescriptor<Category>(predicate: Category.nameIsNotEmpty))
//    static var focusFilter: Predicate<Category> {
//        let defaults = UserDefaults(suiteName: "group.me.craigpeters.clarity")
//        if let data = defaults?.data(forKey: "ClarityFocusFilter") {
//            if let settings = try? JSONDecoder().decode(CategoryFilterSettings.self, from: data) {
//                // Build a predicate based on settings. This example filters by category name.
//                // Adjust to use IDs if your CategoryEntity contains identifiers.
//                let names = Set(settings.Categories.compactMap { $0.name })
//                switch settings.showOrHide {
//                case .show:
//                    return #Predicate<Category> { category in
//                        if let name = category.name {
//                            return names.contains(name)
//                        } else {
//                            return false
//                        }
//                    }
//                case .hide:
//                    return #Predicate<Category> { category in
//                        if let name = category.name {
//                            return !names.contains(name)
//                        } else {
//                            return true
//                        }
//                    }
//                }
//            }
//        }
//        // Fallback: include everything that has a non-empty name
//        return #Predicate<Category> { category in
//            category.name != nil && category.name != ""
//        }
//    }
    
    enum CategoryColor: String, CaseIterable, Codable {
        case Red = "Red"
        case Blue = "Blue"
        case Green = "Green"
        case Yellow = "Yellow"
        case Brown = "Brown"
        case Cyan = "Cyan"
        case Pink = "Pink"
        case Purple = "Purple"
        case Orange = "Orange"
        
        var SwiftUIColor : Color {
            switch self {
            case .Red: return .red
            case .Blue: return .blue
            case .Green: return .green
            case .Yellow: return .yellow
            case .Brown: return .brown
            case .Cyan: return .cyan
            case .Pink: return
                // Barbie pink - vibrant!
                Color(red: 1.0, green: 0.08, blue: 0.58)
            case .Purple: return
                Color(red: 0.58, green: 0.0, blue: 0.83)
            case .Orange: return .orange
            }
        }
        
        var contrastingTextColor: Color {
            switch self {
            case .Yellow, .Cyan, .Pink:
                return .black
            case .Red, .Blue, .Green, .Brown, .Orange, .Purple:
                return .white
            }
        }
    }
}

struct CategoryDTO: Sendable, Codable, Hashable {
    var id: PersistentIdentifier?
    var name: String
    var color: Category.CategoryColor
    var weeklyTarget: Int
    
    init(id: PersistentIdentifier?, name: String, color: Category.CategoryColor, weeklyTarget: Int) {
        self.id = id
        self.name = name
        self.color = color
        self.weeklyTarget = weeklyTarget
        
    }
    
    var encodedId: String? {
        guard let id else { return nil }
        guard let data = try? JSONEncoder().encode(id) else { return nil }
        return data.base64EncodedString()
    }
    
    func decodeId(_ encodedId: String) throws -> PersistentIdentifier? {
        guard let data = Data(base64Encoded: encodedId) else {
            throw NSError(domain: "ToDo", code: 0, userInfo: nil)
        }
        return try JSONDecoder().decode(PersistentIdentifier.self, from: data)
    }
}

extension CategoryDTO {
    init(from model: Category) {
        self.init(id: model.persistentModelID, name: model.name!, color: model.color ?? Category.CategoryColor.Red , weeklyTarget: model.weeklyTarget)
    }
}


struct CategoryFilterSettings: Codable {
    var Categories: [CategoryEntity]
    var showOrHide: FilterShowOrHide
}

enum FilterShowOrHide: String, Codable, AppEnum {
    case show
    case hide

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Show or Hide Categories"

    static var caseDisplayRepresentations: [FilterShowOrHide: DisplayRepresentation] = [
        .show: "Show",
        .hide: "Hide"
    ]
}


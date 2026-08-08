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
    /// SF Symbol name used to represent this category visually. Optional.
    var iconName: String?
    /// Stable identifier safe for use across CloudKit sync and widget/intent boundaries.
    /// Optional for migration safety — backfilled at app launch.
    var uuid: UUID?
    @Relationship(inverse: \ToDoTask.categories) var tasks: [ToDoTask]? = []
    @Relationship(inverse: \Habit.categories) var habits: [Habit]? = []

    init(name: String, color: CategoryColor = .Red, weeklyTarget: Int = 0, iconName: String? = nil) {
        self.name = name
        self.color = color
        self.weeklyTarget = weeklyTarget
        self.iconName = iconName
        self.uuid = UUID()
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

struct CategoryDTO: Sendable, Hashable {
    var id: PersistentIdentifier?
    var name: String
    var color: Category.CategoryColor
    var weeklyTarget: Int
    var iconName: String?
    /// Stable UUID — preferred over PersistentIdentifier for cross-process use (widgets, intents).
    var uuid: UUID?

    nonisolated init(id: PersistentIdentifier?, name: String, color: Category.CategoryColor, weeklyTarget: Int, iconName: String? = nil, uuid: UUID? = nil) {
        self.id = id
        self.name = name
        self.color = color
        self.weeklyTarget = weeklyTarget
        self.iconName = iconName
        self.uuid = uuid
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

extension Category: Hashable {
    static func == (lhs: Category, rhs: Category) -> Bool {
        lhs.uuid == rhs.uuid
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(uuid)
    }
}

extension CategoryDTO: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, name, color, weeklyTarget, iconName, uuid
    }

    nonisolated init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decodeIfPresent(PersistentIdentifier.self, forKey: .id)
        self.name = try c.decode(String.self, forKey: .name)
        self.color = try c.decode(Category.CategoryColor.self, forKey: .color)
        self.weeklyTarget = try c.decodeIfPresent(Int.self, forKey: .weeklyTarget) ?? 0
        self.iconName = try c.decodeIfPresent(String.self, forKey: .iconName)
        self.uuid = try c.decodeIfPresent(UUID.self, forKey: .uuid)
    }

    nonisolated func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(color, forKey: .color)
        try c.encode(weeklyTarget, forKey: .weeklyTarget)
        try c.encodeIfPresent(iconName, forKey: .iconName)
        try c.encodeIfPresent(uuid, forKey: .uuid)
    }
}

extension CategoryDTO {
    nonisolated init(from model: Category) {
        self.init(
            id: model.persistentModelID,
            name: model.name ?? "",
            color: model.color ?? .Red,
            weeklyTarget: model.weeklyTarget,
            iconName: model.iconName,
            uuid: model.uuid
        )
    }
}


struct CategoryFilterSettings {
    var Categories: [CategoryEntity]
    var showOrHide: FilterShowOrHide
}

// Explicit Codable — avoids @MainActor bleed from AppEntity synthesis
extension CategoryFilterSettings: Codable {
    enum CodingKeys: String, CodingKey { case Categories, showOrHide }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.Categories = try container.decode([CategoryEntity].self, forKey: .Categories)
        self.showOrHide = try container.decode(FilterShowOrHide.self, forKey: .showOrHide)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(Categories, forKey: .Categories)
        try container.encode(showOrHide, forKey: .showOrHide)
    }
}

enum FilterShowOrHide: String, Codable, AppEnum {
    case show
    case hide

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Show or Hide Categories"

    static let caseDisplayRepresentations: [FilterShowOrHide: DisplayRepresentation] = [
        .show: "Show",
        .hide: "Hide"
    ]
}


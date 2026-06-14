//
//  Statistics.swift
//  Clarity
//
//  Created by Craig Peters on 01/09/2025.
//

import SwiftData
import Foundation

@Model
public final class GlobalTargetSettings {
    var weeklyGlobalTarget: Int = 0 // Total tasks per week across all categories
    var created: Date = Date()
    
    init(weeklyGlobalTarget: Int = 0) {
        self.weeklyGlobalTarget = weeklyGlobalTarget
        self.created = Date()
    }
}

public struct CategoryProgress: Sendable {
    let name: String
    let completed: Int
    let target: Int
    let color: String
}

extension CategoryProgress: Codable {
    enum CodingKeys: String, CodingKey { case name, completed, target, color }
    nonisolated public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try c.decode(String.self, forKey: .name)
        self.completed = try c.decode(Int.self, forKey: .completed)
        self.target = try c.decode(Int.self, forKey: .target)
        self.color = try c.decode(String.self, forKey: .color)
    }
    nonisolated public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(name, forKey: .name)
        try c.encode(completed, forKey: .completed)
        try c.encode(target, forKey: .target)
        try c.encode(color, forKey: .color)
    }
}

public struct WeeklyProgress: Sendable {
    let completed: Int
    let target: Int
    let error: String?
    let categories: [CategoryProgress]
}

extension WeeklyProgress: Codable {
    enum CodingKeys: String, CodingKey { case completed, target, error, categories }
    nonisolated public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.completed = try c.decode(Int.self, forKey: .completed)
        self.target = try c.decode(Int.self, forKey: .target)
        self.error = try c.decodeIfPresent(String.self, forKey: .error)
        self.categories = try c.decode([CategoryProgress].self, forKey: .categories)
    }
    nonisolated public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(completed, forKey: .completed)
        try c.encode(target, forKey: .target)
        try c.encodeIfPresent(error, forKey: .error)
        try c.encode(categories, forKey: .categories)
    }
}

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

// MARK: - StatsTimeframe

public enum StatsTimeframe: String, CaseIterable, Sendable, Codable {
    case today      = "Today"
    case last7Days  = "7 Days"
    case last30Days = "30 Days"
    case last90Days = "90 Days"
    case thisYear   = "This Year"
    case allTime    = "All Time"

    public var dateRange: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        let now = Date()
        switch self {
        case .today:
            return "Today only"
        case .last7Days:
            let start = Calendar.current.date(byAdding: .day, value: -7, to: now) ?? now
            return "\(formatter.string(from: start)) - Today"
        case .last30Days:
            let start = Calendar.current.date(byAdding: .day, value: -30, to: now) ?? now
            return "\(formatter.string(from: start)) - Today"
        case .last90Days:
            let start = Calendar.current.date(byAdding: .day, value: -90, to: now) ?? now
            return "\(formatter.string(from: start)) - Today"
        case .thisYear:
            let start = Calendar.current.dateInterval(of: .year, for: now)?.start ?? now
            return "Since \(formatter.string(from: start))"
        case .allTime:
            return "All completed tasks"
        }
    }

    public var shortDescription: String {
        switch self {
        case .today:     return "24 hrs"
        case .last7Days:  return "1 week"
        case .last30Days: return "1 month"
        case .last90Days: return "3 months"
        case .thisYear:   return Calendar.current.component(.year, from: Date()).description
        case .allTime:    return "Everything"
        }
    }
}

// MARK: - StatisticsCalculator output types

struct OverviewMetrics: Sendable {
    let totalCompleted: Int
    let totalFocusTime: TimeInterval
    let averagePerDay: Double
}

struct HourlyCompletionData: Sendable {
    let hour: Int        // 0..<24
    let count: Int
    let intensity: Double
}

struct DailyCompletionData: Sendable {
    let date: Date
    let dateString: String
    let categoryCompletions: [String: Int]
    let totalCount: Int
}

struct CategoryCompletionData: Sendable {
    let categoryName: String
    let completionCount: Int
    let color: Category.CategoryColor
}

struct StreakResult: Sendable {
    let current: Int
    let longest: Int
}

struct StatisticsSummary: Sendable {
    let filteredTasks: [ToDoTaskDTO]
    let allCompletedTasks: [ToDoTaskDTO]
    let overview: OverviewMetrics
    let categoryData: [CategoryCompletionData]
    let hourlyData: [HourlyCompletionData]
    let dailyData: [DailyCompletionData]
    let streak: StreakResult
}

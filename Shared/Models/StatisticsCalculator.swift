//
//  StatisticsCalculator.swift
//  Clarity
//
//  Created by Craig Peters on 14/06/2026.
//

import Foundation

/// Pure, nonisolated statistics computation over `ToDoTaskDTO` arrays.
/// No SwiftData queries, no actor isolation — safe to call from any context.
nonisolated struct StatisticsCalculator: Sendable {

    // MARK: - Top-level entry point

    /// Produces a full StatisticsSummary for the given timeframe and optional category filter.
    /// Pass all completed tasks (completed == true); streak uses the full unfiltered set.
    static func summary(
        from allCompletedTasks: [ToDoTaskDTO],
        timeframe: StatsTimeframe,
        categoryFilter: String? = nil,
        categories: [CategoryDTO] = [],
        referenceDate: Date = Date()
    ) -> StatisticsSummary {
        var filtered = filter(allCompletedTasks, for: timeframe, referenceDate: referenceDate)
        if let name = categoryFilter {
            filtered = filter(filtered, byCategory: name)
        }
        return StatisticsSummary(
            filteredTasks: filtered,
            allCompletedTasks: allCompletedTasks,
            overview: overviewMetrics(from: filtered, referenceDate: referenceDate),
            categoryData: categoryData(from: filtered, categories: categories),
            hourlyData: hourlyData(from: filtered),
            dailyData: dailyData(from: filtered),
            streak: streakData(from: allCompletedTasks, referenceDate: referenceDate)
        )
    }

    // MARK: - Filtering

    /// Returns tasks whose `completedAt` falls within the given timeframe window.
    static func filter(
        _ tasks: [ToDoTaskDTO],
        for timeframe: StatsTimeframe,
        referenceDate: Date = Date()
    ) -> [ToDoTaskDTO] {
        let calendar = Calendar.current
        switch timeframe {
        case .today:
            return tasks.filter { task in
                guard let completedAt = task.completedAt else { return false }
                return calendar.isDate(completedAt, inSameDayAs: referenceDate)
            }
        case .last7Days:
            let start = calendar.date(byAdding: .day, value: -7, to: referenceDate) ?? referenceDate
            return tasks.filter { task in
                guard let completedAt = task.completedAt else { return false }
                return completedAt >= start
            }
        case .last30Days:
            let start = calendar.date(byAdding: .day, value: -30, to: referenceDate) ?? referenceDate
            return tasks.filter { task in
                guard let completedAt = task.completedAt else { return false }
                return completedAt >= start
            }
        case .last90Days:
            let start = calendar.date(byAdding: .day, value: -90, to: referenceDate) ?? referenceDate
            return tasks.filter { task in
                guard let completedAt = task.completedAt else { return false }
                return completedAt >= start
            }
        case .thisYear:
            let start = calendar.dateInterval(of: .year, for: referenceDate)?.start ?? referenceDate
            return tasks.filter { task in
                guard let completedAt = task.completedAt else { return false }
                return completedAt >= start
            }
        case .allTime:
            return tasks
        }
    }

    /// Applies an additional category-name filter on an already-filtered list.
    static func filter(
        _ tasks: [ToDoTaskDTO],
        byCategory categoryName: String
    ) -> [ToDoTaskDTO] {
        tasks.filter { dto in
            dto.categories.contains { $0.name == categoryName }
        }
    }

    // MARK: - Overview Metrics

    static func overviewMetrics(
        from tasks: [ToDoTaskDTO],
        referenceDate: Date = Date()
    ) -> OverviewMetrics {
        let totalCompleted = tasks.count
        let totalFocusTime = tasks.reduce(0.0) { $0 + ($1.pomodoro ? $1.pomodoroTime : 0) }

        let averagePerDay: Double = {
            guard !tasks.isEmpty else { return 0 }
            let dates = tasks.compactMap { $0.completedAt }.sorted()
            guard let first = dates.first, let last = dates.last else { return 0 }
            let days = Calendar.current.dateComponents([.day], from: first, to: last).day ?? 1
            return Double(tasks.count) / Double(max(days, 1))
        }()

        return OverviewMetrics(
            totalCompleted: totalCompleted,
            totalFocusTime: totalFocusTime,
            averagePerDay: averagePerDay
        )
    }

    // MARK: - Hourly Distribution

    /// Returns exactly 24 entries (hours 0..<24) with completion counts and intensity values.
    static func hourlyData(from tasks: [ToDoTaskDTO]) -> [HourlyCompletionData] {
        let calendar = Calendar.current
        var hourCounts: [Int: Int] = [:]

        for task in tasks {
            guard let completedAt = task.completedAt else { continue }
            let hour = calendar.component(.hour, from: completedAt)
            hourCounts[hour, default: 0] += 1
        }

        let maxCount = hourCounts.values.max() ?? 1

        return (0..<24).map { hour in
            let count = hourCounts[hour] ?? 0
            let intensity = Double(count) / Double(maxCount)
            return HourlyCompletionData(hour: hour, count: count, intensity: intensity)
        }
    }

    // MARK: - Daily Breakdown

    /// Returns one entry per day that has at least one completion, sorted descending by date.
    static func dailyData(from tasks: [ToDoTaskDTO]) -> [DailyCompletionData] {
        let calendar = Calendar.current
        var dailyCount: [Date: [String]] = [:]

        for task in tasks {
            guard let completedAt = task.completedAt else { continue }
            let startOfDay = calendar.startOfDay(for: completedAt)
            if dailyCount[startOfDay] == nil {
                dailyCount[startOfDay] = []
            }
            if !task.categories.isEmpty {
                for cat in task.categories {
                    dailyCount[startOfDay]?.append(cat.name)
                }
            }
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"

        return dailyCount.map { (date, categoryNames) -> DailyCompletionData in
            var categoryCount: [String: Int] = [:]
            for name in categoryNames {
                categoryCount[name.isEmpty ? "Uncategorized" : name, default: 0] += 1
            }

            // Tasks on this date with no categories go into "Uncategorized"
            let tasksOnDate = tasks.filter { dto in
                guard let c = dto.completedAt else { return false }
                return calendar.startOfDay(for: c) == date
            }
            let noCategoryCount = tasksOnDate.filter { $0.categories.isEmpty }.count
            if noCategoryCount > 0 {
                categoryCount["Uncategorized", default: 0] += noCategoryCount
            }

            let total = tasksOnDate.count

            return DailyCompletionData(
                date: date,
                dateString: formatter.string(from: date),
                categoryCompletions: categoryCount,
                totalCount: total
            )
        }.sorted { $0.date > $1.date }
    }

    // MARK: - Category Completion

    /// Returns one entry per category (plus "Uncategorized"), sorted descending by count.
    /// Color comes from the passed `categories` list; "Uncategorized" uses `.Brown` as a sentinel
    /// (views that need gray should map `.Brown` → `.gray` when `categoryName == "Uncategorized"`).
    static func categoryData(
        from tasks: [ToDoTaskDTO],
        categories: [CategoryDTO]
    ) -> [CategoryCompletionData] {
        var categoryCount: [String: Int] = [:]

        for task in tasks {
            if !task.categories.isEmpty {
                for cat in task.categories {
                    categoryCount[cat.name, default: 0] += 1
                }
            } else {
                categoryCount["Uncategorized", default: 0] += 1
            }
        }

        // Explicit pass for tasks with no categories (mirrors existing StatsView logic)
        let uncategorizedCount = tasks.filter { $0.categories.isEmpty }.count
        if uncategorizedCount > 0 {
            categoryCount["Uncategorized"] = uncategorizedCount
        }

        let colorMap = Dictionary(uniqueKeysWithValues: categories.map { ($0.name, $0.color) })

        return categoryCount.map { (name, count) -> CategoryCompletionData in
            let color = colorMap[name] ?? .Brown
            return CategoryCompletionData(categoryName: name, completionCount: count, color: color)
        }.sorted { $0.completionCount > $1.completionCount }
    }

    // MARK: - Streak

    /// Computes current and longest completion streaks.
    /// Must receive **all** completed tasks — not a time-filtered subset.
    static func streakData(
        from allCompletedTasks: [ToDoTaskDTO],
        referenceDate: Date = Date()
    ) -> StreakResult {
        return StreakResult(
            current: calculateCurrentStreak(from: allCompletedTasks, referenceDate: referenceDate),
            longest: calculateLongestStreak(from: allCompletedTasks)
        )
    }

    private static func calculateCurrentStreak(
        from tasks: [ToDoTaskDTO],
        referenceDate: Date
    ) -> Int {
        let calendar = Calendar.current
        let completedDates = Set(tasks.compactMap { task -> Date? in
            guard let completedAt = task.completedAt else { return nil }
            return calendar.startOfDay(for: completedAt)
        })

        guard !completedDates.isEmpty else { return 0 }

        var streak = 0
        var current = calendar.startOfDay(for: referenceDate)

        // If nothing completed today, look back from yesterday
        if !completedDates.contains(current) {
            current = calendar.date(byAdding: .day, value: -1, to: current) ?? current
        }

        while completedDates.contains(current) {
            streak += 1
            current = calendar.date(byAdding: .day, value: -1, to: current) ?? current
        }
        return streak
    }

    private static func calculateLongestStreak(from tasks: [ToDoTaskDTO]) -> Int {
        let calendar = Calendar.current
        let sortedDates = tasks.compactMap { task -> Date? in
            guard let completedAt = task.completedAt else { return nil }
            return calendar.startOfDay(for: completedAt)
        }.sorted()

        guard !sortedDates.isEmpty else { return 0 }

        var longest = 1
        var current = 1

        for i in 1..<sortedDates.count {
            let diff = calendar.dateComponents([.day], from: sortedDates[i - 1], to: sortedDates[i]).day ?? 0
            if diff == 1 {
                current += 1
                longest = max(longest, current)
            } else if diff > 1 {
                current = 1
            }
            // diff == 0: same day, don't reset
        }
        return longest
    }

    // MARK: - Weekly Progress (for ClarityModelActor / widgets)

    /// Builds a `WeeklyProgress` value with a populated `categories` array.
    /// Replaces the hardcoded `categories: []` that was previously in both
    /// `ClarityModelActor.fetchWeeklyProgress()` and `ClarityServices.fetchWeeklyProgress()`.
    static func weeklyProgress(
        completedTasks: [ToDoTaskDTO],
        categories: [CategoryDTO],
        globalTarget: Int,
        referenceDate: Date = Date()
    ) -> WeeklyProgress {
        let calendar = Calendar.current
        var comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: referenceDate)
        comps.weekday = 2 // Monday
        let weekStart = calendar.date(from: comps) ?? referenceDate

        let tasksThisWeek = completedTasks.filter { dto in
            guard let completedAt = dto.completedAt else { return false }
            return completedAt >= weekStart
        }

        let totalCompleted = tasksThisWeek.count

        let categoryProgresses: [CategoryProgress] = categories.compactMap { cat in
            guard cat.weeklyTarget > 0 else { return nil }
            let completed = tasksThisWeek.filter { dto in
                dto.categories.contains { $0.name == cat.name }
            }.count
            return CategoryProgress(
                name: cat.name,
                completed: completed,
                target: cat.weeklyTarget,
                color: cat.color.rawValue
            )
        }.sorted { $0.name < $1.name }

        return WeeklyProgress(
            completed: totalCompleted,
            target: globalTarget,
            error: nil,
            categories: categoryProgresses
        )
    }
}

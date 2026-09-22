//
//  StatisticsCalculatorTests.swift
//  ClarityTests
//
//  Created by OpenCode on 09/08/2026.
//

import Foundation
import Testing
@testable import Clarity

struct StatisticsCalculatorTests {

    private let calendar = Calendar.current

    private func date(year: Int, month: Int, day: Int, hour: Int = 12) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        return calendar.date(from: components) ?? Date()
    }

    private func task(
        name: String,
        completedAt: Date? = nil,
        pomodoroTime: TimeInterval = 25 * 60,
        categories: [CategoryDTO] = []
    ) -> ToDoTaskDTO {
        ToDoTaskDTO(
            name: name,
            pomodoroTime: pomodoroTime,
            categories: categories,
            uuid: UUID(),
            completedAt: completedAt
        )
    }

    private func category(
        name: String,
        color: Clarity.Category.CategoryColor = .Red,
        weeklyTarget: Int = 0
    ) -> CategoryDTO {
        CategoryDTO(id: nil, name: name, color: color, weeklyTarget: weeklyTarget, uuid: UUID())
    }

    // MARK: - Filtering

    @Test func filterTodayOnlyIncludesSameDay() {
        let reference = date(year: 2026, month: 1, day: 5)
        let sameDay = date(year: 2026, month: 1, day: 5, hour: 8)
        let otherDay = date(year: 2026, month: 1, day: 4, hour: 8)
        let tasks = [
            task(name: "same", completedAt: sameDay),
            task(name: "other", completedAt: otherDay),
            task(name: "nil", completedAt: nil)
        ]

        let filtered = StatisticsCalculator.filter(tasks, for: .today, referenceDate: reference)
        #expect(filtered.map(\.name) == ["same"])
    }

    @Test func filterLast7DaysBoundaryIsInclusive() {
        let reference = date(year: 2026, month: 1, day: 5)
        let boundary = date(year: 2025, month: 12, day: 29, hour: 12)
        let justBefore = date(year: 2025, month: 12, day: 29, hour: 11)
        let inside = date(year: 2025, month: 12, day: 30, hour: 12)
        let tasks = [
            task(name: "boundary", completedAt: boundary),
            task(name: "justBefore", completedAt: justBefore),
            task(name: "inside", completedAt: inside)
        ]

        let filtered = StatisticsCalculator.filter(tasks, for: .last7Days, referenceDate: reference)
        #expect(Set(filtered.map(\.name)) == Set(["boundary", "inside"]))
    }

    @Test func filterThisYearFromYearStart() {
        let reference = date(year: 2026, month: 3, day: 15)
        let lastYear = date(year: 2025, month: 12, day: 31)
        let thisYear = date(year: 2026, month: 1, day: 1)
        let tasks = [
            task(name: "lastYear", completedAt: lastYear),
            task(name: "thisYear", completedAt: thisYear)
        ]

        let filtered = StatisticsCalculator.filter(tasks, for: .thisYear, referenceDate: reference)
        #expect(filtered.map(\.name) == ["thisYear"])
    }

    @Test func filterAllTimeIncludesTasksWithNilCompletedAt() {
        let tasks = [
            task(name: "nil"),
            task(name: "set", completedAt: date(year: 2026, month: 1, day: 1))
        ]

        let filtered = StatisticsCalculator.filter(tasks, for: .allTime, referenceDate: date(year: 2026, month: 1, day: 5))
        #expect(filtered.count == 2)
    }

    @Test func filterByCategoryName() {
        let work = category(name: "Work")
        let tasks = [
            task(name: "in", categories: [work]),
            task(name: "out", categories: [category(name: "Home")])
        ]

        let filtered = StatisticsCalculator.filter(tasks, byCategory: "Work")
        #expect(filtered.map(\.name) == ["in"])
    }

    // MARK: - Overview metrics

    @Test func overviewMetricsEmpty() {
        let metrics = StatisticsCalculator.overviewMetrics(from: [], referenceDate: date(year: 2026, month: 1, day: 5))
        #expect(metrics.totalCompleted == 0)
        #expect(metrics.totalFocusTime == 0)
        #expect(metrics.averagePerDay == 0)
    }

    @Test func overviewMetricsFocusTimeSumsPomodoroTime() {
        let tasks = [
            task(name: "short", completedAt: date(year: 2026, month: 1, day: 5), pomodoroTime: 600),
            task(name: "long", completedAt: date(year: 2026, month: 1, day: 5), pomodoroTime: 1200)
        ]

        let metrics = StatisticsCalculator.overviewMetrics(from: tasks, referenceDate: date(year: 2026, month: 1, day: 5))
        #expect(metrics.totalFocusTime == 1800)
    }

    @Test func overviewMetricsAveragePerDaySingleDay() {
        let tasks = (0..<3).map { index in
            task(name: "t\(index)", completedAt: date(year: 2026, month: 1, day: 5))
        }

        let metrics = StatisticsCalculator.overviewMetrics(from: tasks, referenceDate: date(year: 2026, month: 1, day: 5))
        #expect(metrics.averagePerDay == 3.0)
    }

    @Test func overviewMetricsAveragePerDayMultiDay() {
        let tasks = [
            task(name: "d1", completedAt: date(year: 2026, month: 1, day: 1)),
            task(name: "d5", completedAt: date(year: 2026, month: 1, day: 5))
        ]

        let metrics = StatisticsCalculator.overviewMetrics(from: tasks, referenceDate: date(year: 2026, month: 1, day: 5))
        #expect(metrics.averagePerDay == 0.5)
    }

    // MARK: - Hourly distribution

    @Test func hourlyDataAlwaysReturns24Entries() {
        let data = StatisticsCalculator.hourlyData(from: [])
        #expect(data.count == 24)
        #expect(data.allSatisfy { $0.count == 0 && $0.intensity == 0 })
    }

    @Test func hourlyDataBucketsAndScalesIntensity() {
        let h9 = date(year: 2026, month: 1, day: 5, hour: 9)
        let h10 = date(year: 2026, month: 1, day: 5, hour: 10)
        let tasks = [
            task(name: "h9a", completedAt: h9),
            task(name: "h9b", completedAt: h9),
            task(name: "h10", completedAt: h10)
        ]

        let data = StatisticsCalculator.hourlyData(from: tasks)
        #expect(data[9].count == 2)
        #expect(data[9].intensity == 1.0)
        #expect(data[10].count == 1)
        #expect(data[10].intensity == 0.5)
        #expect(data[11].count == 0)
    }

    // MARK: - Daily breakdown

    @Test func dailyDataBucketsByStartOfDayAndSortsDescending() {
        let d1 = date(year: 2026, month: 1, day: 5)
        let d2 = date(year: 2026, month: 1, day: 4)
        let tasks = [
            task(name: "d1", completedAt: d1),
            task(name: "d1b", completedAt: d1),
            task(name: "d2", completedAt: d2)
        ]

        let data = StatisticsCalculator.dailyData(from: tasks)
        #expect(data.count == 2)
        #expect(data[0].totalCount == 2)
        #expect(data[1].totalCount == 1)
    }

    @Test func dailyDataUncategorizedPaths() {
        let d = date(year: 2026, month: 1, day: 5)
        let tasks = [
            task(name: "emptyCat", completedAt: d, categories: [category(name: "", color: Clarity.Category.CategoryColor.Red)]),
            task(name: "noCat", completedAt: d, categories: [])
        ]

        let data = StatisticsCalculator.dailyData(from: tasks)
        #expect(data.count == 1)
        // PINNED: possible bug — both empty category name and no categories are merged into "Uncategorized"
        let uncategorizedCount = data[0].categoryCompletions["Uncategorized"]
        #expect(uncategorizedCount == 2)
        #expect(data[0].totalCount == 2)
    }

    // MARK: - Category completion

    @Test func categoryDataMissingColorFallsBackToBrown() {
        let tasks = [task(name: "t", categories: [category(name: "NoColorList")])]

        let data = StatisticsCalculator.categoryData(from: tasks, categories: [])
        #expect(data.count == 1)
        #expect(data[0].categoryName == "NoColorList")
        #expect(data[0].color == Clarity.Category.CategoryColor.Brown)
    }

    @Test func categoryDataUsesColorFromCategoriesList() {
        let blue = category(name: "BlueCat", color: Clarity.Category.CategoryColor.Blue)
        let tasks = [task(name: "t", categories: [blue])]

        let data = StatisticsCalculator.categoryData(from: tasks, categories: [blue])
        #expect(data[0].color == Clarity.Category.CategoryColor.Blue)
    }

    @Test func categoryDataUncategorizedRedundantPass() {
        let tasks = [task(name: "noCat", completedAt: date(year: 2026, month: 1, day: 5), categories: [])]

        let data = StatisticsCalculator.categoryData(from: tasks, categories: [])
        #expect(data.count == 1)
        // PINNED: possible bug — the explicit uncategorized pass overwrites the value already set in the first pass
        #expect(data[0].categoryName == "Uncategorized")
        #expect(data[0].completionCount == 1)
    }

    @Test func categoryDataSortedByCountDescending() {
        let tasks = [
            task(name: "a", categories: [category(name: "A")]),
            task(name: "a2", categories: [category(name: "A")]),
            task(name: "b", categories: [category(name: "B")])
        ]

        let data = StatisticsCalculator.categoryData(from: tasks, categories: [])
        #expect(data[0].categoryName == "A")
        #expect(data[1].categoryName == "B")
    }

    // MARK: - Streaks

    @Test func currentStreakIncludesTodayWhenCompleted() {
        let ref = date(year: 2026, month: 1, day: 5)
        let tasks = [
            task(name: "t1", completedAt: date(year: 2026, month: 1, day: 5)),
            task(name: "t2", completedAt: date(year: 2026, month: 1, day: 4)),
            task(name: "t3", completedAt: date(year: 2026, month: 1, day: 3))
        ]

        let streak = StatisticsCalculator.streakData(from: tasks, referenceDate: ref)
        #expect(streak.current == 3)
        #expect(streak.longest == 3)
    }

    @Test func currentStreakStartsFromYesterdayWhenTodayMissing() {
        let ref = date(year: 2026, month: 1, day: 5)
        let tasks = [
            task(name: "t1", completedAt: date(year: 2026, month: 1, day: 4)),
            task(name: "t2", completedAt: date(year: 2026, month: 1, day: 3))
        ]

        let streak = StatisticsCalculator.streakData(from: tasks, referenceDate: ref)
        #expect(streak.current == 2)
    }

    @Test func longestStreakIgnoresSameDayCompletionsAndResetsAfterGap() {
        let tasks = [
            task(name: "d1", completedAt: date(year: 2026, month: 1, day: 1)),
            task(name: "d1b", completedAt: date(year: 2026, month: 1, day: 1, hour: 15)),
            task(name: "d2", completedAt: date(year: 2026, month: 1, day: 2)),
            task(name: "d4", completedAt: date(year: 2026, month: 1, day: 4))
        ]

        let streak = StatisticsCalculator.streakData(from: tasks, referenceDate: date(year: 2026, month: 1, day: 5))
        #expect(streak.longest == 2)
        #expect(streak.current == 1)
    }

    // MARK: - Weekly progress

    @Test func weeklyProgressIsMondayBased() {
        let monday = date(year: 2026, month: 1, day: 5) // Monday
        let tasks = [task(name: "mon", completedAt: monday)]

        let progress = StatisticsCalculator.weeklyProgress(
            completedTasks: tasks,
            categories: [],
            globalTarget: 10,
            referenceDate: monday
        )
        #expect(progress.completed == 1)
    }

    @Test func weeklyProgressExcludesSundayBeforeMondayStart() {
        let sunday = date(year: 2026, month: 1, day: 4)
        let monday = date(year: 2026, month: 1, day: 5)
        let tasks = [task(name: "sun", completedAt: sunday)]

        let progress = StatisticsCalculator.weeklyProgress(
            completedTasks: tasks,
            categories: [],
            globalTarget: 10,
            referenceDate: monday
        )
        #expect(progress.completed == 0)
    }

    @Test func weeklyProgressCategoryProgressRequiresTarget() {
        let cat = category(name: "Work", weeklyTarget: 5)
        let monday = date(year: 2026, month: 1, day: 5)
        let tasks = [task(name: "t", completedAt: monday, categories: [cat])]

        let progress = StatisticsCalculator.weeklyProgress(
            completedTasks: tasks,
            categories: [cat],
            globalTarget: 10,
            referenceDate: monday
        )
        #expect(progress.categories.count == 1)
        #expect(progress.categories[0].completed == 1)
        #expect(progress.categories[0].target == 5)
    }

    @Test func weeklyProgressSkipsCategoryWithZeroTarget() {
        let cat = category(name: "Untargeted", weeklyTarget: 0)
        let monday = date(year: 2026, month: 1, day: 5)
        let tasks = [task(name: "t", completedAt: monday, categories: [cat])]

        let progress = StatisticsCalculator.weeklyProgress(
            completedTasks: tasks,
            categories: [cat],
            globalTarget: 10,
            referenceDate: monday
        )
        #expect(progress.categories.isEmpty)
    }

    @Test func weeklyProgressCategoriesSortedByName() {
        let beta = category(name: "Beta", weeklyTarget: 1)
        let alpha = category(name: "Alpha", weeklyTarget: 1)
        let monday = date(year: 2026, month: 1, day: 5)
        let tasks = [task(name: "t", completedAt: monday, categories: [beta])]

        let progress = StatisticsCalculator.weeklyProgress(
            completedTasks: tasks,
            categories: [beta, alpha],
            globalTarget: 10,
            referenceDate: monday
        )
        #expect(progress.categories.map(\.name) == ["Alpha", "Beta"])
    }

    // MARK: - Summary entry point

    @Test func summaryComposesFilteredTasksAndOverview() {
        let ref = date(year: 2026, month: 1, day: 5)
        let tasks = [
            task(name: "today", completedAt: ref),
            task(name: "yesterday", completedAt: date(year: 2026, month: 1, day: 4)),
            task(name: "uncategorized", completedAt: ref, categories: [])
        ]

        let summary = StatisticsCalculator.summary(from: tasks, timeframe: .today, referenceDate: ref)
        #expect(summary.filteredTasks.count == 2)
        #expect(summary.overview.totalCompleted == 2)
        #expect(summary.categoryData.contains { $0.categoryName == "Uncategorized" })
    }
}

//
//  HeatmapMathTests.swift
//  ClarityTests
//
//  Created by OpenCode on 13/08/2026.
//

import Foundation
import Testing
@testable import Clarity

struct HeatmapMathTests {

    private let calendar = Calendar.current

    private func makeTask(
        dueOffsetDays: Int,
        completedOffsetDays: Int? = nil,
        recurrence: ToDoTask.RecurrenceInterval? = nil,
        customDays: Int = 0
    ) -> ToDoTaskDTO {
        let now = Date()
        let due = calendar.date(byAdding: .day, value: dueOffsetDays, to: now) ?? now
        let completedAt: Date? = completedOffsetDays.flatMap { calendar.date(byAdding: .day, value: $0, to: now) }
        return ToDoTaskDTO(
            name: "task",
            repeating: recurrence != nil,
            recurrenceInterval: recurrence,
            customRecurrenceDays: customDays,
            due: due,
            completed: completedAt != nil,
            completedAt: completedAt
        )
    }

    @Test func earlyCompletionReturnsZeroRatio() {
        let task = makeTask(dueOffsetDays: 1, completedOffsetDays: 0)
        let ratio = HeatmapMath.latenessRatio(for: task, completedAt: task.heatmapCompletedAt, interval: task.heatmapRecurrenceInterval)
        #expect(ratio == 0)
    }

    @Test func nilCompletionReturnsZeroRatio() {
        let task = makeTask(dueOffsetDays: 0)
        let ratio = HeatmapMath.latenessRatio(for: task, completedAt: nil, interval: task.heatmapRecurrenceInterval)
        #expect(ratio == 0)
    }

    @Test func lateRatioIsCappedAtOne() {
        let task = makeTask(dueOffsetDays: -30, completedOffsetDays: 0, recurrence: .daily)
        let ratio = HeatmapMath.latenessRatio(for: task, completedAt: task.heatmapCompletedAt, interval: task.heatmapRecurrenceInterval)
        #expect(ratio == 1.0)
    }

    @Test func noRecurrenceFallsBackToWeeklyInterval() {
        let task = makeTask(dueOffsetDays: -3, completedOffsetDays: 0)
        let ratio = HeatmapMath.latenessRatio(for: task, completedAt: task.heatmapCompletedAt, interval: task.heatmapRecurrenceInterval)
        #expect(ratio > 0)
        #expect(ratio <= 1)
    }

    @Test func intervalDurationByRecurrence() {
        #expect(HeatmapMath.intervalDuration(for: .daily, customDays: 0) == 1 * 24 * 3600)
        #expect(HeatmapMath.intervalDuration(for: .everyOtherDay, customDays: 0) == 2 * 24 * 3600)
        #expect(HeatmapMath.intervalDuration(for: .weekly, customDays: 0) == 7 * 24 * 3600)
        #expect(HeatmapMath.intervalDuration(for: .biweekly, customDays: 0) == 14 * 24 * 3600)
        #expect(HeatmapMath.intervalDuration(for: .monthly, customDays: 0) == 30 * 24 * 3600)
        #expect(HeatmapMath.intervalDuration(for: .custom, customDays: 5) == 5 * 24 * 3600)
        #expect(HeatmapMath.intervalDuration(for: .specific, customDays: 0) == 7 * 24 * 3600)
        #expect(HeatmapMath.intervalDuration(for: nil, customDays: 0) == 0)
    }

    @Test func buildDaysReturnsCorrectDateRange() {
        let calendar = Calendar(identifier: .gregorian)
        let now = calendar.date(from: DateComponents(year: 2026, month: 8, day: 12, hour: 12))!
        let today = calendar.startOfDay(for: now)
        let totalDays = 7
        let entries = HeatmapMath.buildDays(totalDays: totalDays, tasks: [], referenceDate: now)

        #expect(entries.count == totalDays)
        #expect(entries.last?.date == today)
        #expect(entries.first?.date == calendar.date(byAdding: .day, value: -(totalDays - 1), to: today))
    }

    @Test func buildDaysBucketsCompletedTasksByStartOfDay() {
        let calendar = Calendar(identifier: .gregorian)
        let now = calendar.date(from: DateComponents(year: 2026, month: 8, day: 12, hour: 12))!
        let today = calendar.startOfDay(for: now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let task = ToDoTaskDTO(
            name: "completed",
            due: yesterday,
            completed: true,
            completedAt: yesterday
        )

        let entries = HeatmapMath.buildDays(totalDays: 2, tasks: [task], referenceDate: now)
        let yesterdayEntry = entries.first
        #expect(yesterdayEntry?.tasks.count == 1)
        #expect(yesterdayEntry?.bestLatenessRatio != nil)
    }

    @Test func buildDaysUsesBestLatenessRatio() {
        let calendar = Calendar(identifier: .gregorian)
        let now = calendar.date(from: DateComponents(year: 2026, month: 8, day: 12, hour: 12))!
        let today = calendar.startOfDay(for: now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let early = ToDoTaskDTO(
            name: "early",
            recurrenceInterval: .daily,
            due: yesterday,
            completed: true,
            completedAt: yesterday
        )
        let late = ToDoTaskDTO(
            name: "late",
            recurrenceInterval: .daily,
            due: yesterday,
            completed: true,
            completedAt: yesterday.addingTimeInterval(20 * 3600)
        )

        let entries = HeatmapMath.buildDays(totalDays: 2, tasks: [early, late], referenceDate: now)
        #expect(entries.first?.bestLatenessRatio == 0)
    }

    @Test func incompleteTasksAreExcludedFromDayBuckets() {
        let calendar = Calendar(identifier: .gregorian)
        let now = calendar.date(from: DateComponents(year: 2026, month: 8, day: 12, hour: 12))!
        let today = calendar.startOfDay(for: now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let task = ToDoTaskDTO(name: "incomplete", due: yesterday, completed: false, completedAt: nil)

        let entries = HeatmapMath.buildDays(totalDays: 2, tasks: [task], referenceDate: now)
        #expect(entries.first?.tasks.isEmpty == true)
        #expect(entries.first?.bestLatenessRatio == nil)
    }
}

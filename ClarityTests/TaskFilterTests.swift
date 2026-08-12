//
//  TaskFilterTests.swift
//  ClarityTests
//
//  Created by OpenCode on 09/08/2026.
//

import Foundation
import Testing
@testable import Clarity

struct TaskFilterTests {

    private let calendar = Calendar.current

    private func date(year: Int, month: Int, day: Int, hour: Int = 12) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        return calendar.date(from: components) ?? Date()
    }

    private func task(name: String, due: Date) -> ToDoTaskDTO {
        ToDoTaskDTO(name: name, due: due, categories: [], uuid: UUID())
    }

    @Test func allMatchesEverything() {
        let t = task(name: "any", due: date(year: 1999, month: 1, day: 1))
        #expect(ToDoTask.TaskFilter.all.matches(dto: t, at: Date(), calendar: calendar))
    }

    @Test func overdueBeforeStartOfDay() {
        let now = date(year: 2026, month: 1, day: 5)
        let yesterday = date(year: 2026, month: 1, day: 4)
        let t = task(name: "late", due: yesterday)
        #expect(ToDoTask.TaskFilter.overdue.matches(dto: t, at: now, calendar: calendar))
    }

    @Test func dueAtStartOfDayIsNotOverdue() {
        let now = date(year: 2026, month: 1, day: 5)
        let startOfDay = calendar.startOfDay(for: now)
        let t = task(name: "boundary", due: startOfDay)
        #expect(ToDoTask.TaskFilter.overdue.matches(dto: t, at: now, calendar: calendar) == false)
    }

    @Test func todayMatchesSameDay() {
        let now = date(year: 2026, month: 1, day: 5)
        let t = task(name: "today", due: now)
        #expect(ToDoTask.TaskFilter.today.matches(dto: t, at: now, calendar: calendar))
    }

    @Test func tomorrowMatchesNextCalendarDay() {
        let now = date(year: 2026, month: 1, day: 5)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))!
        let t = task(name: "tomorrow", due: tomorrow)
        #expect(ToDoTask.TaskFilter.tomorrow.matches(dto: t, at: now, calendar: calendar))
    }

    @Test func thisWeekIncludesStartOfWeek() {
        let now = date(year: 2026, month: 1, day: 5) // Monday
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)!.start
        let t = task(name: "weekStart", due: weekStart)
        #expect(ToDoTask.TaskFilter.thisWeek.matches(dto: t, at: now, calendar: calendar))
    }

    @Test func thisWeekExcludesJustOutsideWeek() {
        let now = date(year: 2026, month: 1, day: 5)
        let weekEnd = calendar.dateInterval(of: .weekOfYear, for: now)!.end
        let justOutside = weekEnd.addingTimeInterval(1)
        let t = task(name: "outside", due: justOutside)
        #expect(ToDoTask.TaskFilter.thisWeek.matches(dto: t, at: now, calendar: calendar) == false)
    }

    @Test func recurrenceIntervalNextDateCalculations() {
        let d = date(year: 2026, month: 1, day: 5)
        #expect(ToDoTask.RecurrenceInterval.daily.nextDate(from: d) == calendar.date(byAdding: .day, value: 1, to: d))
        #expect(ToDoTask.RecurrenceInterval.everyOtherDay.nextDate(from: d) == calendar.date(byAdding: .day, value: 2, to: d))
        #expect(ToDoTask.RecurrenceInterval.weekly.nextDate(from: d) == calendar.date(byAdding: .weekOfYear, value: 1, to: d))
        #expect(ToDoTask.RecurrenceInterval.biweekly.nextDate(from: d) == calendar.date(byAdding: .weekOfYear, value: 2, to: d))
        #expect(ToDoTask.RecurrenceInterval.monthly.nextDate(from: d) == calendar.date(byAdding: .month, value: 1, to: d))
        #expect(ToDoTask.RecurrenceInterval.custom.nextDate(from: d) == d)
        #expect(ToDoTask.RecurrenceInterval.specific.nextDate(from: d) == d)
    }

    @Test func recurrenceIntervalMonthEndBehavior() {
        // PINNED: Calendar date arithmetic for monthly on Jan 31 produces Feb 28 (or 29 in leap year).
        let jan31 = date(year: 2026, month: 1, day: 31)
        let nextDate = ToDoTask.RecurrenceInterval.monthly.nextDate(from: jan31)
        let components = calendar.dateComponents([.month, .day], from: nextDate)
        #expect(components.month == 2)
        #expect(components.day == 28)
    }

    @Test func completedTaskFilterTodayMatchesSameDay() {
        let now = date(year: 2026, month: 1, day: 5)
        let t = task(name: "today", due: now)
        // ToDoTaskDTO has no completedAt setter in the convenience init, so we cannot test this
        // with completedAt directly. The matches function uses completedAt, so this test documents
        // the limitation of the DTO init.
        #expect(ToDoTask.CompletedTaskFilter.Today.matches(t, calendar: calendar, now: now) == false)
    }

    @Test func completedTaskFilterMonthAlwaysReturnsTrue() {
        // PINNED: .Month ignores the date and returns true for every completed task.
        let now = date(year: 2026, month: 1, day: 5)
        let t = task(name: "any", due: date(year: 2020, month: 1, day: 1))
        #expect(ToDoTask.CompletedTaskFilter.Month.matches(t, calendar: calendar, now: now) == true)
    }

    @Test func taskFilterOptionMapping() {
        #expect(ToDoTask.TaskFilterOption.today.toTaskFilter() == .today)
        #expect(ToDoTask.TaskFilterOption.tomorrow.toTaskFilter() == .tomorrow)
        #expect(ToDoTask.TaskFilterOption.thisWeek.toTaskFilter() == .thisWeek)
        #expect(ToDoTask.TaskFilterOption.overdue.toTaskFilter() == .overdue)
        #expect(ToDoTask.TaskFilterOption.all.toTaskFilter() == .all)
    }

    @Test func taskFilterOptionColors() {
        #expect(ToDoTask.TaskFilterOption.filterColor[.today] != nil)
        #expect(ToDoTask.TaskFilterOption.filterColor[.tomorrow] != nil)
        #expect(ToDoTask.TaskFilterOption.filterColor[.all] != nil)
    }
}

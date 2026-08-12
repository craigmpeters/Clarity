//
//  CompanionTaskContextTests.swift
//  ClarityTests
//
//  Created by OpenCode on 09/08/2026.
//

import Foundation
import Testing
@testable import Clarity

struct CompanionTaskContextTests {

    private let calendar = Calendar.current

    private func summary(
        name: String,
        dueDate: Date,
        lastCompletedAt: Date? = nil,
        lastMoodValence: Double? = nil,
        categories: [String] = []
    ) -> CompanionTaskContext.TaskSummary {
        CompanionTaskContext.TaskSummary(
            uuid: UUID(),
            name: name,
            dueDate: dueDate,
            pomodoroMinutes: 25,
            lastCompletedAt: lastCompletedAt,
            lastMoodValence: lastMoodValence,
            categories: categories
        )
    }

    private func habitSummary(
        name: String,
        weeklyFrequency: Int = 7,
        currentStreak: Int = 0,
        doneToday: Bool = false
    ) -> CompanionTaskContext.HabitSummary {
        CompanionTaskContext.HabitSummary(
            uuid: UUID(),
            name: name,
            weeklyFrequency: weeklyFrequency,
            currentStreak: currentStreak,
            doneToday: doneToday
        )
    }

    private func context(
        dueTasks: [CompanionTaskContext.TaskSummary] = [],
        recentlyCompleted: [CompanionTaskContext.TaskSummary] = [],
        habits: [CompanionTaskContext.HabitSummary] = []
    ) -> CompanionTaskContext {
        CompanionTaskContext(
            dueTasks: dueTasks,
            recentlyCompleted: recentlyCompleted,
            habits: habits,
            loadedAt: Date()
        )
    }

    @Test func emptyContextReturnsNoTasksString() {
        let ctx = context()
        #expect(ctx.instructionsBlock == "The user has no tasks or habits recorded yet.")
    }

    @Test func dueTasksSectionPresent() {
        let due = summary(name: "Read Docs", dueDate: Date().addingTimeInterval(3600))
        let ctx = context(dueTasks: [due])
        #expect(ctx.instructionsBlock.contains("UPCOMING TASKS"))
        #expect(ctx.instructionsBlock.contains("\"Read Docs\""))
    }

    @Test func dueTasksCategoriesIncluded() {
        let due = summary(name: "Work", dueDate: Date(), categories: ["Work", "Admin"])
        let ctx = context(dueTasks: [due])
        #expect(ctx.instructionsBlock.contains("[Work, Admin]"))
    }

    @Test func moodThresholdGreat() {
        let due = summary(name: "T", dueDate: Date(), lastCompletedAt: Date(), lastMoodValence: 0.5)
        let ctx = context(dueTasks: [due])
        #expect(ctx.instructionsBlock.contains("felt great"))
    }

    @Test func moodThresholdOkay() {
        // PINNED: 0.0 falls into the "okay" bucket (>= 0.0 and < 0.5).
        let due = summary(name: "T", dueDate: Date(), lastCompletedAt: Date(), lastMoodValence: 0.0)
        let ctx = context(dueTasks: [due])
        #expect(ctx.instructionsBlock.contains("felt okay"))
    }

    @Test func moodThresholdDrained() {
        let due = summary(name: "T", dueDate: Date(), lastCompletedAt: Date(), lastMoodValence: -0.1)
        let ctx = context(dueTasks: [due])
        #expect(ctx.instructionsBlock.contains("felt drained"))
    }

    @Test func lastCompletedSuffixOnlyWhenMoodAndLastCompletedPresent() {
        let withBoth = summary(name: "T", dueDate: Date(), lastCompletedAt: Date(), lastMoodValence: 0.5)
        let ctxWithBoth = context(dueTasks: [withBoth])
        #expect(ctxWithBoth.instructionsBlock.contains("last done"))

        let withMoodOnly = summary(name: "T", dueDate: Date(), lastMoodValence: 0.5)
        let ctxWithMoodOnly = context(dueTasks: [withMoodOnly])
        #expect(ctxWithMoodOnly.instructionsBlock.contains("last done") == false)
    }

    @Test func recentlyCompletedSectionPresent() {
        let completed = summary(name: "Done", dueDate: Date(), lastCompletedAt: Date(), lastMoodValence: 0.6)
        let ctx = context(recentlyCompleted: [completed])
        #expect(ctx.instructionsBlock.contains("RECENTLY COMPLETED"))
        #expect(ctx.instructionsBlock.contains("\"Done\""))
        #expect(ctx.instructionsBlock.contains("0.6"))
    }

    @Test func habitsSectionDailyFrequency() {
        let habit = habitSummary(name: "Walk", weeklyFrequency: 7, currentStreak: 3, doneToday: true)
        let ctx = context(habits: [habit])
        #expect(ctx.instructionsBlock.contains("HABITS"))
        #expect(ctx.instructionsBlock.contains("\"Walk\" (daily)"))
        #expect(ctx.instructionsBlock.contains("done today"))
    }

    @Test func habitsSectionWeeklyFrequency() {
        let habit = habitSummary(name: "Stretch", weeklyFrequency: 3, currentStreak: 1, doneToday: false)
        let ctx = context(habits: [habit])
        #expect(ctx.instructionsBlock.contains("3 days/week"))
        #expect(ctx.instructionsBlock.contains("not done today"))
    }

    @Test func habitsSectionStreakCount() {
        let habit = habitSummary(name: "Read", weeklyFrequency: 7, currentStreak: 5)
        let ctx = context(habits: [habit])
        #expect(ctx.instructionsBlock.contains("streak 5 weeks"))
    }
}

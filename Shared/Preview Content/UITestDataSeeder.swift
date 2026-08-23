//
//  UITestDataSeeder.swift
//  Clarity
//
//  Shared helper that seeds the same deterministic data for both SwiftUI previews
//  and UI tests. Extracted from PreviewData so the app can seed an in-memory
//  container when launched with the --uitesting argument.
//

import SwiftData
import Foundation

@MainActor
enum UITestDataSeeder {
    static func seed(in container: ModelContainer) {
        let context = ModelContext(container)
        insertCategories(into: context)
        insertGlobalTarget(into: context)
        insertSwipeOptions(into: context)
        insertTasks(into: context)
        insertStatistics(into: context)
        insertHabits(into: context)
        save(context)
    }

    private static func insertCategories(into context: ModelContext) {
        let categories = [
            Category(name: "Work", color: .Blue, weeklyTarget: 8, iconName: "briefcase.fill"),
            Category(name: "Personal", color: .Green, weeklyTarget: 5, iconName: "person.fill"),
            Category(name: "Learning", color: .Purple, weeklyTarget: 3, iconName: "book.fill"),
            Category(name: "Health", color: .Red, weeklyTarget: 7, iconName: "heart.fill"),
            Category(name: "Creative", color: .Orange, weeklyTarget: 2, iconName: "paintbrush.fill"),
            Category(name: "Urgent", color: .Yellow, weeklyTarget: 0, iconName: "exclamationmark.triangle.fill"),
            Category(name: "Planning", color: .Cyan, weeklyTarget: 2, iconName: "calendar")
        ]
        for category in categories {
            context.insert(category)
        }
    }

    private static func insertGlobalTarget(into context: ModelContext) {
        let settings = GlobalTargetSettings()
        settings.weeklyGlobalTarget = 10
        context.insert(settings)
    }

    private static func insertSwipeOptions(into context: ModelContext) {
        let swipeOptions = TaskSwipeAndTapOptions()
        swipeOptions.tap = .complete
        swipeOptions.primarySwipeLeading = .startTimer
        swipeOptions.secondarySwipeLeading = .complete
        swipeOptions.primarySwipeTrailing = .delete
        swipeOptions.secondarySwipeTrailing = .edit
        context.insert(swipeOptions)
    }

    private static func insertTasks(into context: ModelContext) {
        let categories = fetchCategories(from: context)
        let work = categories.first { $0.name == "Work" }
        let personal = categories.first { $0.name == "Personal" }
        let learning = categories.first { $0.name == "Learning" }

        let sampleTasks = [
            ("Review quarterly reports", 5, Date().addingTimeInterval(-86400), [work].compactMap { $0 }),
            ("Team standup meeting prep", 5, Date(), [work].compactMap { $0 }),
            ("Grocery shopping", 5, Date(), [personal].compactMap { $0 }),
            ("SwiftUI documentation reading", 5, Date(), [learning].compactMap { $0 }),
            ("Client presentation slides", 5, Date().addingTimeInterval(86400), [work].compactMap { $0 }),
            ("Doctor appointment", 5, Date().addingTimeInterval(86400), [personal].compactMap { $0 }),
            ("Code review session", 5, Date().addingTimeInterval(86400 * 2), [work].compactMap { $0 }),
            ("Weekend hiking preparation", 5, Date().addingTimeInterval(86400 * 3), [personal].compactMap { $0 }),
            ("iOS 18 features research", 5, Date().addingTimeInterval(86400 * 4), [learning].compactMap { $0 }),
            ("Watch WWDC", 5, Date().addingTimeInterval(86400 * 4), [learning].compactMap { $0 })
        ]

        for (name, minutes, dueDate, taskCategories) in sampleTasks {
            let task = ToDoTask(
                name: name,
                pomodoroTime: TimeInterval(minutes * 60),
                due: dueDate,
                everySpecificDayDay: nil,
                categories: taskCategories
            )
            context.insert(task)
        }

        let completedTask = ToDoTask(
            name: "Completed",
            pomodoroTime: TimeInterval(1000),
            due: Date(),
            everySpecificDayDay: nil,
            categories: []
        )
        completedTask.completed = true
        completedTask.completedAt = Date()
        context.insert(completedTask)
    }

    private static func insertStatistics(into context: ModelContext) {
        let calendar = Calendar.current
        let now = Date()

        for dayOffset in 0..<30 {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: now) else { continue }
            let taskCount = Int.random(in: 1...3)
            for taskIndex in 0..<taskCount {
                let task = ToDoTask(
                    name: "Stats Task \(dayOffset)-\(taskIndex)",
                    pomodoroTime: TimeInterval(5 * 60),
                    due: date,
                    categories: []
                )
                task.completed = true
                task.completedAt = date.addingTimeInterval(Double.random(in: 0...86400))
                context.insert(task)
            }
        }
    }

    private static func insertHabits(into context: ModelContext) {
        let categories = fetchCategories(from: context)
        let health = categories.first { $0.name == "Health" }
        let personal = categories.first { $0.name == "Personal" }

        let habits = [
            Habit(
                name: "Drink Water",
                unitLabel: "mL",
                dailyTarget: 2500,
                incrementStep: 250,
                weeklyFrequency: 7,
                categories: [health].compactMap { $0 }
            ),
            Habit(
                name: "Read 30 Minutes",
                unitLabel: "minutes",
                dailyTarget: 30,
                incrementStep: 5,
                weeklyFrequency: 5,
                categories: [personal].compactMap { $0 }
            )
        ]
        for habit in habits {
            addOccurrence(habit, context)
            context.insert(habit)
        }
    }
    
    private static func addOccurrence(_ habit: Habit, _ context: ModelContext) {
        let total = habit.incrementStep * 2.0
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let new =  HabitOccurrence(habit:habit, periodStart: startOfDay, currentAmount: total)
        context.insert(new)
    }
    
    

    private static func fetchCategories(from context: ModelContext) -> [Category] {
        (try? context.fetch(FetchDescriptor<Category>())) ?? []
    }

    private static func save(_ context: ModelContext) {
        do {
            try context.save()
        } catch {
            print("Failed to seed UI test data: \(error)")
        }
    }
}

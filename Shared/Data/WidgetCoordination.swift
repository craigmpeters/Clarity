//
//  WidgetCoordination.swift
//  Clarity
//
//  Abstraction over WidgetKit/file coordination so that ClarityModelActor
//  can be exercised in unit tests without triggering WidgetCenter/NSFileCoordinator
//  machinery in the test host.
//

import Foundation
import WidgetKit

protocol WidgetCoordination: Sendable {
    nonisolated func writeCategories(_ categories: [CategoryDTO]) throws
    nonisolated func writeHabits(_ habits: [HabitDTO]) throws
    nonisolated func writeTasks(_ tasks: ToDoTaskList) throws
    nonisolated func reloadAllTimelines()
    nonisolated func reloadTimelines(ofKind kind: String)
}

struct LiveWidgetCoordinator: WidgetCoordination {
    nonisolated func writeCategories(_ categories: [CategoryDTO]) throws {
        try WidgetFileCoordinator.shared.writeCategories(categories)
    }

    nonisolated func writeHabits(_ habits: [HabitDTO]) throws {
        try WidgetFileCoordinator.shared.writeHabits(habits)
    }

    nonisolated func writeTasks(_ tasks: ToDoTaskList) throws {
        try WidgetFileCoordinator.shared.writeTasks(tasks)
    }

    nonisolated func reloadAllTimelines() {
        Task { @MainActor in WidgetCenter.shared.reloadAllTimelines() }
    }

    nonisolated func reloadTimelines(ofKind kind: String) {
        Task { @MainActor in WidgetCenter.shared.reloadTimelines(ofKind: kind) }
    }
}

struct NoOpWidgetCoordinator: WidgetCoordination {
    nonisolated func writeCategories(_ categories: [CategoryDTO]) throws {}
    nonisolated func writeHabits(_ habits: [HabitDTO]) throws {}
    nonisolated func writeTasks(_ tasks: ToDoTaskList) throws {}
    nonisolated func reloadAllTimelines() {}
    nonisolated func reloadTimelines(ofKind kind: String) {}
}

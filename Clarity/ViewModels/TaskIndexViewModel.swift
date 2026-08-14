//
//  TaskIndexViewModel.swift
//  Clarity
//
//  View model for TaskIndexView. Owns filtering, store access, and task actions.
//

import SwiftData
import SwiftUI
import os

@Observable
@MainActor
final class TaskIndexViewModel {
    var selectedFilter: ToDoTask.TaskFilter = .all
    var selectedCategory: Category?
    var showingTaskForm = false
    var taskToEdit: ToDoTaskDTO?

    private(set) var store: ClarityModelActor?
    private var refreshID = UUID()

    var refreshTrigger: UUID { refreshID }

    func filteredTasks(from allTasks: [ToDoTask]) -> [ToDoTask] {
        let focused = ToDoTask.focusFilter(in: allTasks)
        let filtered = focused.filter { task in
            let dueDateMatches = selectedFilter.matches(task: task)
            let taskCategories = task.categories ?? []
            let matchesSelectedCategory: Bool = {
                guard let selectedCategory, let selectedName = selectedCategory.name else { return true }
                return taskCategories.contains { $0.name == selectedName }
            }()
            return dueDateMatches && matchesSelectedCategory
        }
        #if INTERNAL
        logDuplicateTasks(in: filtered)
        #endif
        return filtered
    }

    func setStore(_ store: ClarityModelActor) {
        self.store = store
    }

    func triggerRefresh() {
        refreshID = UUID()
    }

    func editTask(_ task: ToDoTaskDTO) {
        LogManager.shared.log.debug("Editing \(task.name)")
        taskToEdit = task
        showingTaskForm = true
    }

    func deleteTask(_ task: ToDoTaskDTO) {
        LogManager.shared.log.debug("Deleting: (\(task.name))")
        Task {
            try? await store?.deleteTask(task.id!)
        }
    }

    func completeTask(_ task: ToDoTaskDTO) {
        LogManager.shared.log.debug("Attempting to complete task for ID: \(task.id.debugDescription) : \(task.name)")
        guard let store else { return }
        let id = task.uuid
        Task {
            LogManager.shared.log.debug("Completing task with ID: \(id) and name: \(task.name)")
            try? await store.completeTask(id)
        }
    }

    func startTimer(for task: ToDoTaskDTO, selectedTask: inout ToDoTaskDTO?, container: ModelContainer) {
        guard !PomodoroService.shared.isActive else {
            LogManager.shared.log.debug("Pomodoro already active, ignoring start request for \(task.name)")
            return
        }
        LogManager.shared.log.debug("Starting Pomodoro for \(task.name)")
        selectedTask = task
        PomodoroService.shared.startPomodoro(for: task, container: container, device: .iPhone)
    }

    func completeTaskFromPomodoroNotification(userInfo: [AnyHashable: Any]?) {
        guard let store else { return }
        if let id = userInfo?["taskID"] as? UUID {
            LogManager.shared.log.debug("Completing Task with ID \(id)")
            Task { try? await store.completeTask(id) }
        } else if let id = PomodoroService.shared.toDoTask?.uuid {
            LogManager.shared.log.debug("Completing Task with ID: \(id)")
            Task { try? await store.completeTask(id) }
        }
    }

    #if INTERNAL
    func logDuplicateTasks(in tasks: [ToDoTask]) {
        var groups: [UUID: [ToDoTask]] = [:]
        for task in tasks {
            guard let id = task.uuid else { continue }
            groups[id, default: []].append(task)
        }
        for (uuid, group) in groups where group.count > 1 {
            LogManager.shared.log.error("Duplicate tasks detected for UUID=\(uuid.uuidString); count=\(group.count)")
            for (index, t) in group.enumerated() {
                let dump = dumpTask(t)
                LogManager.shared.log.error("  [\(index)] \n\(dump)")
            }
        }
    }

    private func dumpTask(_ t: ToDoTask) -> String {
        var lines: [String] = []
        lines.append("id: \(t.id.debugDescription)")
        lines.append("uuid: \(t.uuid?.uuidString ?? "nil")")
        lines.append("name: \(t.name ?? "nil")")
        lines.append("due: \(t.due.formatted())")
        lines.append("created: \(t.completedAt?.formatted() ?? "nil")")
        lines.append("completed: \(t.completed)")
        lines.append("completedAt: \(t.completedAt?.formatted() ?? "nil")")
        lines.append("pomodoro: \(t.pomodoro.description)")
        lines.append("pomodoroTime: \(t.pomodoroTime.description)")
        lines.append("repeating: \(t.repeating?.description ?? "nil")")
        lines.append("recurrenceInterval: \(String(describing: t.recurrenceInterval))")
        lines.append("customRecurrenceDays: \(t.customRecurrenceDays.description)")
        lines.append("everySpecificDayDay: \(t.everySpecificDayDay?.description ?? "nil")")
        let categoryNames = (t.categories ?? []).compactMap { $0.name }.joined(separator: ", ")
        lines.append("categories.count: \(t.categories?.count ?? 0)")
        lines.append("categories: [\(categoryNames)]")
        return lines.joined(separator: "\n")
    }
    #endif
}

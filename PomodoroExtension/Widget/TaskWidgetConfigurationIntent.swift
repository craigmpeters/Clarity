//
//  TaskWidgetConfigurationIntent.swift
//  Clarity
//
//  Created by Craig Peters on 02/09/2025.
//

import WidgetKit
import SwiftUI
import SwiftData
import AppIntents

struct TaskWidgetProvider: AppIntentTimelineProvider {
    typealias Entry = TaskWidgetEntry
    typealias Intent = TaskWidgetConfigurationIntent
    
    func placeholder(in context: Context) -> TaskWidgetEntry {
        TaskWidgetEntry(
            date: Date(),
            taskCount: 5,
            tasks: [],
            filter: .today,
            category: nil
        )
    }
    
    func snapshot(for configuration: TaskWidgetConfigurationIntent, in context: Context) async -> TaskWidgetEntry {
        await fetchTaskEntry(for: configuration)
    }
    
    func timeline(for configuration: TaskWidgetConfigurationIntent, in context: Context) async -> Timeline<TaskWidgetEntry> {
        let entry = await fetchTaskEntry(for: configuration)
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
        return Timeline(entries: [entry], policy: .after(nextUpdate))
    }
    
    private func fetchTaskEntry(for configuration: TaskWidgetConfigurationIntent) async -> TaskWidgetEntry {
        let tasks = await SharedDataActor.shared.getTasksForWidget(
            filter: configuration.filter,
            categoryId: configuration.category?.id
        )
        
        let taskInfos = tasks.map { task in
            TaskWidgetEntry.TaskInfo(
                id: String(describing: task.id),
                name: task.name,
                dueDate: task.due,
                categoryColors: task.categories.map { $0.color },
                categoryNames: task.categories.map { $0.name },
                pomodoroTime: task.pomodoroTime
            )
        }
        
        return TaskWidgetEntry(
            date: Date(),
            taskCount: taskInfos.count,
            tasks: taskInfos,
            filter: configuration.filter,
            category: configuration.category
        )
    }
}

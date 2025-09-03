//
//  WidgtProvider.swift
//  Clarity
//
//  Created by Craig Peters on 03/09/2025.
//

import AppIntents
import WidgetKit

struct TaskWidgetProvider: AppIntentTimelineProvider {
    typealias Entry = TaskWidgetEntry
    typealias Intent = TaskWidgetIntent
    
    func placeholder(in context: Context) -> TaskWidgetEntry {
        TaskWidgetEntry(
            date: Date(),
            filter: .today,
            taskCount: 0,
            tasks: [],
            weeklyProgress: nil
        )
    }
    
    func snapshot(for configuration: TaskWidgetIntent, in context: Context) async -> TaskWidgetEntry {
        await fetchEntry(for: configuration.filter.toTaskFilter())
    }
    
    func timeline(for configuration: TaskWidgetIntent, in context: Context) async -> Timeline<TaskWidgetEntry> {
        let entry = await fetchEntry(for: configuration.filter.toTaskFilter())
        
        // Update every 30 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
        
        return Timeline(entries: [entry], policy: .after(nextUpdate))
    }
    
    private func fetchEntry(for filter: ToDoStore.TaskFilter) async -> TaskWidgetEntry {
        let (tasks, weeklyProgress) = await WidgetDataActor.shared.fetchTasksForWidget(filter: filter)
        
        let taskInfos = tasks.prefix(10).map { task in
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            
            return TaskWidgetEntry.TaskInfo(
                name: task.name,
                dueTime: formatter.string(from: task.due),
                categoryColors: task.categories.map { $0.color.rawValue },
                pomodoroMinutes: Int(task.pomodoroTime / 60)
            )
        }
        
        return TaskWidgetEntry(
            date: Date(),
            filter: filter,
            taskCount: tasks.count,
            tasks: Array(taskInfos),
            weeklyProgress: weeklyProgress
        )
    }
}

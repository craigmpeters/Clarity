//
//  WidgetProvider.swift
//  Clarity
//
//  Created by Craig Peters on 03/09/2025.
//

import AppIntents
import WidgetKit
import SwiftUI

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
        // For previews, return sample data
        if context.isPreview {
            return createSampleEntry(for: configuration.filter.toTaskFilter())
        }
        
        return await fetchEntry(for: configuration.filter.toTaskFilter())
    }
    
    func timeline(for configuration: TaskWidgetIntent, in context: Context) async -> Timeline<TaskWidgetEntry> {
        let entry = await fetchEntry(for: configuration.filter.toTaskFilter())
        
        // Calculate next significant update times
        let calendar = Calendar.current
        let now = Date()
        
        // Always update at midnight (when day changes)
        let nextMidnight = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: now) ?? now)
        
        // For frequent updates during the day, update every 15 minutes
        let next15Minutes = calendar.date(byAdding: .minute, value: 15, to: now) ?? now
        
        // Use whichever comes first - this ensures we update at midnight for date changes
        let nextUpdate = min(nextMidnight, next15Minutes)
        
        return Timeline(entries: [entry], policy: .after(nextUpdate))
    }
    
    private func fetchEntry(for filter: ToDoStore.TaskFilter) async -> TaskWidgetEntry {
        do {
            let (tasks, weeklyProgress) = await WidgetDataActor.shared.fetchTasksForWidget(filter: filter)
            
            let taskInfos = tasks.prefix(10).map { task in
                let formatter = DateFormatter()
                formatter.timeStyle = .short
                
                return TaskWidgetEntry.TaskInfo(
                    id: String(describing: task.id),
                    name: task.name ?? "",
                    dueTime: formatter.string(from: task.due),
                    categoryColors: task.categories?.map { $0.color.rawValue } ?? [],
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
    
    private func createSampleEntry(for filter: ToDoStore.TaskFilter) -> TaskWidgetEntry {
        let sampleTasks = [
            TaskWidgetEntry.TaskInfo(
                id: "sample-1",
                name: "Complete iOS project",
                dueTime: "2:00 PM",
                categoryColors: ["Blue"],
                pomodoroMinutes: 25
            ),
            TaskWidgetEntry.TaskInfo(
                id: "sample-2",
                name: "Review pull requests",
                dueTime: "4:30 PM",
                categoryColors: ["Green"],
                pomodoroMinutes: 15
            )
        ]
        
        let sampleProgress = TaskWidgetEntry.WeeklyProgress(
            completed: 3,
            target: 7,
        )
        
        return TaskWidgetEntry(
            date: Date(),
            filter: filter,
            taskCount: sampleTasks.count,
            tasks: sampleTasks,
            weeklyProgress: sampleProgress
        )
    }
}

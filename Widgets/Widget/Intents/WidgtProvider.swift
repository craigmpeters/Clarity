//
//  WidgetProvider.swift
//  Clarity
//
//  Created by Craig Peters on 03/09/2025.
//

import AppIntents
import WidgetKit
import SwiftUI
import OSLog

struct TaskWidgetProvider: AppIntentTimelineProvider {
    private let log = Logger(subsystem: "me.craigpeters.clarity", category: "Widget")
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
        log.debug("Timeline loading...")
        
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
    
    private func fetchEntry(for filter: ToDoTask.TaskFilter) async -> TaskWidgetEntry {
        // Fetch tasks first; if this fails, we’ll return an empty entry
        let tasks: [ToDoTask]
        do {
            log.info("Fetching tasks for widget, filter: \(String(describing: filter), privacy: .public)")
            tasks = try await StaticDataStore.shared.fetchTasks(filter)
            log.info("Fetched tasks: \(tasks.count, privacy: .public)")
        } catch {
            log.error("Widget: Error fetching tasks: \(error.localizedDescription, privacy: .public)")
            return TaskWidgetEntry(
                date: Date(),
                filter: filter,
                taskCount: 0,
                tasks: [],
                weeklyProgress: nil
            )
        }

        // Fetch weekly progress separately; if it fails, we’ll still show tasks
        var weeklyProgress: WeeklyProgress? = nil
        do {
            weeklyProgress = try await StaticDataStore.shared.fetchWeeklyProgress()
            log.info("Weekly progress loaded")
        } catch {
            log.error("Widget: Error fetching weekly progress: \(error.localizedDescription, privacy: .public)")
            weeklyProgress = WeeklyProgress(completed: 0, target: 0, categories: [])
        }

        // Map tasks defensively to avoid crashes on unexpected nils
        let formatter = DateFormatter()
        formatter.timeStyle = .short

        let taskInfos: [TaskWidgetEntry.TaskInfo] = tasks.prefix(10).compactMap { task in
            guard let name = task.name else {
                log.error("Task name nil for id \(String(describing: task.id), privacy: .public)")
                return nil
            }
            let dueTime = formatter.string(from: task.due)
            let categoryColors = (task.categories ?? []).compactMap { $0.color?.rawValue }
            return TaskWidgetEntry.TaskInfo(
                id: String(describing: task.id),
                name: name,
                dueTime: dueTime,
                categoryColors: categoryColors,
                pomodoroMinutes: Int(task.pomodoroTime / 60)
            )
        }

        return TaskWidgetEntry(
            date: Date(),
            filter: filter,
            taskCount: tasks.count,
            tasks: taskInfos,
            weeklyProgress: weeklyProgress
        )
    }
    
    private func createSampleEntry(for filter: ToDoTask.TaskFilter) -> TaskWidgetEntry {
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
        
        let sampleProgress = WeeklyProgress(
            completed: 3,
            target: 7,
            categories: [
                (name: "Work", completed: 2, target: 4, color: "Blue"),
                (name: "Personal", completed: 1, target: 3, color: "Green")
            ]
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


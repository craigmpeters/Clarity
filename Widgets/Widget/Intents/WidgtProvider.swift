//
//  WidgetProvider.swift
//  Clarity
//
//  Created by Craig Peters on 03/09/2025.
//

import AppIntents
import WidgetKit
import SwiftUI

struct TaskWidgetEntry: TimelineEntry {
    let date: Date
    let todos: [ToDoTaskDTO]
    let progress: WeeklyProgress
    let filter: TaskFilterOption
}

struct ClarityWidgetProvider: AppIntentTimelineProvider {
    
    func placeholder(in context: Context) -> TaskWidgetEntry {
        TaskWidgetEntry(date: .now, todos: [], progress: WeeklyProgress(completed: 0, target: 0, categories: []),filter: .all)
    }
    
    func snapshot(for configuration: TaskWidgetIntent, in context: Context) async -> TaskWidgetEntry {
        // For previews, return sample data
        let todos = await ClarityServices.snapshotTasksAsync(filter: configuration.filter.toTaskFilter())
        let progress = ClarityServices.fetchWeeklyProgress()
        return TaskWidgetEntry(date: .now, todos: todos, progress: progress, filter: configuration.filter)
    }
    
    func timeline(for configuration: TaskWidgetIntent, in context: Context) async -> Timeline<TaskWidgetEntry> {
        let todos = await ClarityServices.snapshotTasksAsync()
        let progress = ClarityServices.fetchWeeklyProgress()
        let entry = TaskWidgetEntry(date: .now, todos: todos, progress: progress, filter: configuration.filter)
        
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
}


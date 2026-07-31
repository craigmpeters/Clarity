//
//  TaskHistoryWidgetProvider.swift
//  Clarity
//
//  Created by Craig Peters on 10/05/2026.
//

import WidgetKit
import Foundation


struct TaskHistoryWidgetProvider: AppIntentTimelineProvider {
    
    func placeholder(in context: Context) -> TaskHistoryEntry {
        return TaskHistoryEntry(date: .now, uuid: UUID(), tasks: [])
    }
    
    func snapshot(for configuration: TaskHistoryWidgetIntent, in context: Context) async -> TaskHistoryEntry {
        let uuid = configuration.task.flatMap { UUID(uuidString: $0.id) } ?? UUID()
        var tasks: [ToDoTaskDTO] = []
        do {
            tasks = try WidgetFileCoordinator.shared.readTaskHistory(id: uuid) ?? []
        } catch {
            LogManager.shared.log.error(error)
        }
        return TaskHistoryEntry(date: .now, uuid: uuid, tasks: tasks)
    }
    
    func timeline(for configuration: TaskHistoryWidgetIntent, in context: Context) async -> Timeline<TaskHistoryEntry> {
        let uuid = configuration.task.flatMap { UUID(uuidString: $0.id) } ?? UUID()
        var tasks: [ToDoTaskDTO] = []
        do {
            tasks = try WidgetFileCoordinator.shared.readTaskHistory(id: uuid) ?? []
        } catch {
            LogManager.shared.log.error(error)
        }
        
        let calendar = Calendar.current
        let now = Date()
        let entry = TaskHistoryEntry(date: .now, uuid: uuid, tasks: tasks)

        // Always update at midnight (when day changes)
        let nextMidnight = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: now) ?? now)
        return Timeline(entries: [entry], policy: .after(nextMidnight))
    }
    
}

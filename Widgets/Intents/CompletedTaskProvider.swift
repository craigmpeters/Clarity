//
//  CompletedTaskProvider.swift
//  Clarity
//
//  Created by Craig Peters on 10/02/2026.
//


import AppIntents
import WidgetKit
import SwiftUI
import XCGLogger


struct CompletedTaskProvider: AppIntentTimelineProvider {
    
    func placeholder(in context: Context) -> CompletedTaskEntry {
        CompletedTaskEntry(date: .now, tasks: [], progress: WeeklyProgress(completed: 0, target: 0, error: "", categories: []), filter: .Today, showWeeklyProgress: true)
    }
    
    func snapshot(for configuration: CompletedTaskWidgetIntent, in context: Context) async -> CompletedTaskEntry {
        var tasks : [ToDoTaskDTO] = []
        do {
            tasks = try WidgetFileCoordinator.shared.readTasks(kind: .completed)
            LogManager.shared.log.debug("Found \(tasks.count) completed tasks")
        } catch {
            LogManager.shared.log.error("Could not read completed tasks: \(error.localizedDescription)")
        }
        let progress = ClarityServices.fetchWeeklyProgress()
        return CompletedTaskEntry(date: .now, tasks: tasks, progress: progress, filter: configuration.completedFilter, showWeeklyProgress: configuration.showProgress)
    }
    
    func timeline(for configuration: CompletedTaskWidgetIntent, in context: Context) async -> Timeline<CompletedTaskEntry> {
        var tasks : [ToDoTaskDTO] = []
        do {
            tasks = try WidgetFileCoordinator.shared.readTasks(kind: .completed)
            tasks = tasks.filter { configuration.completedFilter.matches($0) }
        } catch {
            LogManager.shared.log.error("Could not read completed tasks: \(error.localizedDescription)")
        }
        
        let selectedCategories: [CategoryEntity] = configuration.categoryFilter
        if selectedCategories.count > 0 {
            let selectedCategoryNames = Set(selectedCategories.map(\.name))
            tasks = tasks.filter { task in
                let taskCategories = Set((task.categories).compactMap(\.name))
                return !taskCategories.isDisjoint(with: selectedCategoryNames)
            }
        }
        
        let progress = ClarityServices.fetchWeeklyProgress()
        let entry = CompletedTaskEntry(date: .now, tasks: tasks, progress: progress, filter: configuration.completedFilter, showWeeklyProgress: configuration.showProgress)
        
        let calendar = Calendar.current
        let now = Date()
        
        let nextMidnight = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: now) ?? now)
        
        let next15Minutes = calendar.date(byAdding: .minute, value: 15, to: now) ?? now
        
        let nextUpdate = min(nextMidnight, next15Minutes)
        return Timeline(entries: [entry], policy: .after(nextUpdate))
        
    }
    
}


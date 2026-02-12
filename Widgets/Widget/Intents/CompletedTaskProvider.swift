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

struct CompletedTaskEntry : TimelineEntry {
    let date: Date
    let completed: [ToDoTaskDTO]
    let progress: WeeklyProgress
}

struct CompletedTaskProvider: AppIntentTimelineProvider {
    
    func placeholder(in context: Context) -> CompletedTaskEntry {
        CompletedTaskEntry(date: .now, completed: [], progress: WeeklyProgress(completed: 0, target: 0, error: "", categories: []))
    }
    
    func snapshot(for configuration: CompletedTaskWidgetIntent in context: Context) async -> CompletedTaskEntry {
        var tasks : [ToDoTaskDTO] = []
        do {
            tasks = try WidgetFileCoordinator.shared.readTasks(for: .completed)
        }
    }
    
}

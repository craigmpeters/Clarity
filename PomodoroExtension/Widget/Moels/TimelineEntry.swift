//
//  TimelineEntry.swift
//  Clarity
//
//  Created by Craig Peters on 03/09/2025.
//

import WidgetKit
import SwiftUI
import SwiftData
import AppIntents

struct TaskWidgetEntry: TimelineEntry {
    let date: Date
    let filter: ToDoStore.TaskFilter
    let taskCount: Int
    let tasks: [TaskInfo]
    let weeklyProgress: WeeklyProgress?
    
    struct TaskInfo: Identifiable {
        let id: String
        let name: String
        let dueTime: String
        let categoryColors: [String]
        let pomodoroMinutes: Int
    }
    
    struct WeeklyProgress {
        let completed: Int
        let target: Int
    }
}

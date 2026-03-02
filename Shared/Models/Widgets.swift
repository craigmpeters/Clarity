//
//  Widgets.swift
//  Clarity
//
//  Created by Craig Peters on 25/02/2026.
//

import WidgetKit
struct WatchDueEntry: TimelineEntry {
    let date: Date
    let todos: [ToDoTaskDTO]
    let filter: ToDoTask.TaskFilterOption
}

struct WatchCompleteEntry: TimelineEntry {
    let date: Date
    let todos: [ToDoTaskDTO]
    let filter: ToDoTask.CompletedTaskFilter
}

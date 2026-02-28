//
//  Widgets.swift
//  Clarity
//
//  Created by Craig Peters on 25/02/2026.
//

import WidgetKit
struct WatchWidgetEntry: TimelineEntry {
    let date: Date
    let todos: [ToDoTaskDTO]
    let filter: ToDoTask.TaskFilterOption
}

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
    let progress: WeeklyProgress
}

struct WatchCompleteEntry: TimelineEntry {
    let date: Date
    let todos: [ToDoTaskDTO]
    let filter: ToDoTask.CompletedTaskFilter
    let progress: WeeklyProgress
}

struct TaskProgress : TimelineEntry {
    let date: Date
    let task: [ToDoTaskDTO]
}


public struct WatchUserInfo: Sendable {
    var tasks: [ToDoTaskDTO]
    var progress: WeeklyProgress
}

extension WatchUserInfo: Codable {
    enum CodingKeys: String, CodingKey { case tasks, progress }
    nonisolated public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.tasks = try c.decode([ToDoTaskDTO].self, forKey: .tasks)
        self.progress = try c.decode(WeeklyProgress.self, forKey: .progress)
    }
    nonisolated public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(tasks, forKey: .tasks)
        try c.encode(progress, forKey: .progress)
    }
}

public struct WatchWidgetData: Sendable {
    public var due: Int
    public var completed: Int
    public var progress: Int
    public var target: Int
}

extension WatchWidgetData: Codable {
    enum CodingKeys: String, CodingKey { case due, completed, progress, target }
    nonisolated public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.due = try c.decode(Int.self, forKey: .due)
        self.completed = try c.decode(Int.self, forKey: .completed)
        self.progress = try c.decode(Int.self, forKey: .progress)
        self.target = try c.decode(Int.self, forKey: .target)
    }
    nonisolated public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(due, forKey: .due)
        try c.encode(completed, forKey: .completed)
        try c.encode(progress, forKey: .progress)
        try c.encode(target, forKey: .target)
    }
}



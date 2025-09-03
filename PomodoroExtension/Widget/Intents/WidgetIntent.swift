//
//  WidgetIntent.swift
//  Clarity
//
//  Created by Craig Peters on 03/09/2025.
//

import WidgetKit
import AppIntents

struct TaskWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Task Filter"
    static var description = IntentDescription("Choose which tasks to display")
    
    @Parameter(title: "Filter", default: .today)
    var filter: TaskFilterOption
    
    // Add this initializer to help with intent mapping
    init() {
        self.filter = .today
    }
    
    init(filter: TaskFilterOption) {
        self.filter = filter
    }
}

enum TaskFilterOption: String, AppEnum, CaseIterable {
    case today = "Today"
    case tomorrow = "Tomorrow"
    case thisWeek = "This Week"
    case overdue = "Overdue"
    case all = "All Tasks"
    
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Filter")
    static var caseDisplayRepresentations: [TaskFilterOption: DisplayRepresentation] = [
        .today: DisplayRepresentation(title: "Today"),
        .tomorrow: DisplayRepresentation(title: "Tomorrow"),
        .thisWeek: DisplayRepresentation(title: "This Week"),
        .overdue: DisplayRepresentation(title: "Overdue"),
        .all: DisplayRepresentation(title: "All Tasks")
    ]
    
    func toTaskFilter() -> ToDoStore.TaskFilter {
        switch self {
        case .today: return .today
        case .tomorrow: return .tomorrow
        case .thisWeek: return .thisWeek
        case .overdue: return .overdue
        case .all: return .all
        }
    }
}

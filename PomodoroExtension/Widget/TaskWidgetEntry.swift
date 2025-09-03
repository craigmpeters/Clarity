//
//  TaskWidgetEntry.swift
//  Clarity
//
//  Created by Craig Peters on 02/09/2025.
//

import WidgetKit
import SwiftUI
import SwiftData
import AppIntents

// MARK: - Widget Entry
struct TaskWidgetEntry: TimelineEntry {
    let date: Date
    let taskCount: Int
    let tasks: [TaskInfo]
    let filter: WidgetTaskFilter
    let category: CategoryEntity?
    
    struct TaskInfo: Identifiable {
        let id: String
        let name: String
        let dueDate: Date
        let categoryColors: [Category.CategoryColor]
        let categoryNames: [String]
        let pomodoroTime: TimeInterval
    }
}

enum WidgetTaskFilter: String, CaseIterable, AppEnum {
    case today = "Today"
    case tomorrow = "Tomorrow"
    case thisWeek = "This Week"
    case overdue = "Overdue"
    
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Task Filter")
    static var caseDisplayRepresentations: [WidgetTaskFilter: DisplayRepresentation] = [
        .today: DisplayRepresentation(title: "Today", subtitle: "Tasks due today"),
        .tomorrow: DisplayRepresentation(title: "Tomorrow", subtitle: "Tasks due tomorrow"),
        .thisWeek: DisplayRepresentation(title: "This Week", subtitle: "Tasks due this week"),
        .overdue: DisplayRepresentation(title: "Overdue", subtitle: "Past due tasks")
    ]
    
    var systemImage: String {
        switch self {
        case .today: return "calendar.circle"
        case .tomorrow: return "calendar.badge.plus"
        case .thisWeek: return "calendar"
        case .overdue: return "exclamationmark.triangle"
        }
    }
    
    var accentColor: Color {
        switch self {
        case .today: return .blue
        case .tomorrow: return .green
        case .thisWeek: return .purple
        case .overdue: return .red
        }
    }
}

// MARK: - Widget Configuration Intent
struct TaskWidgetConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Configure Task Widget"
    static var description = IntentDescription("Select which tasks to display")
    
    @Parameter(title: "Filter", default: .today)
    var filter: WidgetTaskFilter
    
    @Parameter(title: "Category", optionsProvider: CategoryOptionsProvider())
    var category: CategoryEntity?
}

// Category options provider
struct CategoryOptionsProvider: DynamicOptionsProvider {
    func results() async throws -> [CategoryEntity] {
        return await SharedDataActor.shared.getCategories().map { CategoryEntity(from: $0) }
    }
}

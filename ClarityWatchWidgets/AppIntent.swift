//
//  AppIntent.swift
//  ClarityWatchWidgets
//
//  Created by Craig Peters on 22/02/2026.
//

import AppIntents
import WidgetKit

struct WatchDueWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource {
        "Clarity Tasks"
    }

    static var description: IntentDescription {
        "Show what tasks are due"
    }

    static var parameterSummary: some ParameterSummary {
        Summary("\(\.$filter)")
    }

    @Parameter(title: "Date Filter", default: .overdue)
    var filter: ToDoTask.TaskFilterOption

    @Parameter(title: "Category Filter", default: [])
    var categoryFilter: [CategoryEntity]

    init() {
        filter = .overdue
        categoryFilter = []
    }

    init(_ filter: ToDoTask.TaskFilterOption, categoryFilter: [CategoryEntity]) {
        self.filter = filter
        self.categoryFilter = categoryFilter
    }
}

struct WatchCompleteWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource {
        "Clarity Tasks"
    }

    static var description: IntentDescription {
        "Show what tasks are complete"
    }

    static var parameterSummary: some ParameterSummary {
        Summary("\(\.$dateFilter)")
    }

    @Parameter(title: "Date Filter", default: .Today)
    var dateFilter: ToDoTask.CompletedTaskFilter

    init() {
        dateFilter = .Today
    }

    init(_ filter: ToDoTask.CompletedTaskFilter) {
        dateFilter = filter
    }
}

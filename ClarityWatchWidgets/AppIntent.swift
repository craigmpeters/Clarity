//
//  AppIntent.swift
//  ClarityWatchWidgets
//
//  Created by Craig Peters on 22/02/2026.
//

import WidgetKit
import AppIntents

struct WatchDueWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Clarity Tasks" }
    static var description: IntentDescription { "Show what tasks are due" }
    
    @Parameter(title: "Date Filter", default: .all)
    var filter: ToDoTask.TaskFilterOption
    
    @Parameter(title: "Category Filter", default: [])
    var categoryFilter: [CategoryEntity]
    
    init() {
        self.filter = .all
        self.categoryFilter = []
    }
    
    init(filter: ToDoTask.TaskFilterOption, categoryFilter: [CategoryEntity]) {
        self.filter = filter
        self.categoryFilter = categoryFilter
    }
}

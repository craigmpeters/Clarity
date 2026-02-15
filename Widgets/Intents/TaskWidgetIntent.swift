//
//  WidgetIntent.swift
//  Clarity
//
//  Created by Craig Peters on 03/09/2025.
//

import WidgetKit
import AppIntents
import SwiftUI
import XCGLogger

struct TaskWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Task Filter"
    static var description = IntentDescription("Choose which tasks to display")
    
    @Parameter(title: "Date Filter", default: .all)
    var filter: ToDoTask.TaskFilterOption

    @Parameter(title: "Category Filter", default: [])
    var categoryFilter: [CategoryEntity]
    
    @Parameter(title: "Show Weekly Progress", default: true)
    var showWeeklyProgress: Bool
    
    // Add this initializer to help with intent mapping
    init() {
        self.filter = .all
        self.categoryFilter = []
        self.showWeeklyProgress = true
    }
    
    init(filter: ToDoTask.TaskFilterOption, categoryFilter: [CategoryEntity], showWeeklyProgress: Bool) {
        self.filter = filter
        self.categoryFilter = categoryFilter
        self.showWeeklyProgress = showWeeklyProgress
        LogManager.shared.log.debug("Widget Intent Loaded")
    }
}


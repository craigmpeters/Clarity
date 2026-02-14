//
//  CompletedTaskWidgetIntent.swift
//  Clarity
//
//  Created by Craig Peters on 10/02/2026.
//

import WidgetKit
import AppIntents
import SwiftUI
import XCGLogger


struct CompletedTaskWidgetIntent : WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Completed Tasks"
    static var description = IntentDescription("See your completed tasks")
    
    @Parameter(title: "Category Filter", default: [])
    var categoryFilter: [CategoryEntity]
    
    @Parameter(title: "Completed Tasks to Display", default: .PastWeek)
    var completedFilter: ToDoTask.CompletedTaskFilter
    
    init() {
        self.categoryFilter = []
        self.completedFilter = .PastWeek
    }
    
    init(categoryFilter: [CategoryEntity], completedFilter: ToDoTask.CompletedTaskFilter) {
        self.categoryFilter = categoryFilter
        self.completedFilter = completedFilter
        LogManager.shared.log.debug("Completed Task Widget Loaded")
    }
    
    
}

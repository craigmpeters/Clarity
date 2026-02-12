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
    
    init() {
        self.categoryFilter = []
    }
    
    init(categoryFilter: [CategoryEntity]) {
        self.categoryFilter = categoryFilter
        LogManager.shared.log.debug("Completed Task Widget Loaded")
    }
    
    
}

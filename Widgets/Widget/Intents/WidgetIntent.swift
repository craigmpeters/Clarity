//
//  WidgetIntent.swift
//  Clarity
//
//  Created by Craig Peters on 03/09/2025.
//

import WidgetKit
import AppIntents
import SwiftUI

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



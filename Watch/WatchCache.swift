//
//  WatchCache.swift
//  Clarity
//
//  Created by Craig Peters on 22/02/2026.
//

import SwiftData

@Model
class WatchCache {
    var tasks: [ToDoTaskDTO]
    var widgetData: WatchWidgetData
    
    init(tasks: [ToDoTaskDTO], widgetData: WatchWidgetData) {
        self.tasks = tasks
        self.widgetData = widgetData
    }
}

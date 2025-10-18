//
//  Statistics.swift
//  Clarity
//
//  Created by Craig Peters on 01/09/2025.
//

import SwiftData
import Foundation

@Model
public final class GlobalTargetSettings {
    var weeklyGlobalTarget: Int = 0 // Total tasks per week across all categories
    var created: Date = Date()
    
    init(weeklyGlobalTarget: Int = 0) {
        self.weeklyGlobalTarget = weeklyGlobalTarget
        self.created = Date()
    }
}

struct WeeklyProgress {
    let completed: Int
    let target: Int
    let categories: [(name: String, completed: Int, target: Int, color: String)]
}

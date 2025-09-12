//
//  GlobalTargetSettings.swift
//  Clarity
//
//  Created by CloudKit Integration
//

import Foundation
import SwiftData
import CloudKit

@Model
class GlobalTargetSettings {
    var weeklyGlobalTarget: Int = 0
    
    init(weeklyGlobalTarget: Int = 0) {
        self.weeklyGlobalTarget = weeklyGlobalTarget
    }
}
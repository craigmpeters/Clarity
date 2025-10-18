//
//  PomodoroAttributes.swift
//  Clarity
//
//  Created by Craig Peters on 23/08/2025.
//

import Foundation
import ActivityKit

struct PomodoroAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var taskName: String
        var startTime: Date
        var endTime: Date
    }
    var sessionId: String
}

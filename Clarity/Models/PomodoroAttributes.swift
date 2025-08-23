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
        var remainingTime: TimeInterval
        var totalTime: TimeInterval
        var isRunning: Bool
        var taskTitle: String
        var startTime: Date
    }
    var sessionId: String
}

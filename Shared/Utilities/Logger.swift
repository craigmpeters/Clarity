//
//  Logger.swift
//  Clarity
//
//  Created by Craig Peters on 26/10/2025.
//

import os
import Foundation

extension Logger {
    static var subsystem = Bundle.main.bundleIdentifier ?? "Clarity"
    
    static let WatchConnectivity = Logger(subsystem: subsystem, category: "WatchConnectivity")
    static let LogViewer = Logger(subsystem: subsystem, category: "Stetttings.LogView")
    static let ModelActor = Logger(subsystem: subsystem, category: "ModelActor")
    static let ClarityServices = Logger(Sub)
}

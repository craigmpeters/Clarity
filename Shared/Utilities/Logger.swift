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
    // static let ModelActor = Logger(subsystem: subsystem, category: "ModelActor")
    static let ClarityServices = Logger(subsystem: subsystem, category: "Data Model")
    static let Intelligence = Logger(subsystem: subsystem, category: "Apple Intelligence")
    static let UserInterface = Logger(subsystem: subsystem, category: "User Interface")
    static let AppIntents = Logger(subsystem: subsystem, category: "App Intents")
    static let FocusFilter = Logger(subsystem: subsystem, category: "Focus Filter")
}

//
//  Logger.swift
//  Clarity
//
//  Created by Craig Peters on 26/10/2025.
//

import os
import Foundation
import XCGLogger

extension Logger {
    static var subsystem = Bundle.main.bundleIdentifier ?? "me.craigpeters.Clarity"
    
    static let WatchConnectivity = Logger(subsystem: subsystem, category: "WatchConnectivity")
    static let LogViewer = Logger(subsystem: subsystem, category: "Settings.LogView")
    // static let ModelActor = Logger(subsystem: subsystem, category: "ModelActor")
    static let ClarityServices = Logger(subsystem: subsystem, category: "Data Model")
    static let Intelligence = Logger(subsystem: subsystem, category: "Apple Intelligence")
    static let UserInterface = Logger(subsystem: subsystem, category: "User Interface")
    static let AppIntents = Logger(subsystem: subsystem, category: "App Intents")
    static let FocusFilter = Logger(subsystem: subsystem, category: "Focus Filter")
}

final class LogManager {
    static let shared = LogManager()
    let log: XCGLogger

    private init() {
        // 1) Create the logger
        let logger = XCGLogger.default

        // 3) Console / unified logging destination (shows in Xcode/Console.app)
        let systemDestination = AppleSystemLogDestination(identifier: "me.craigpeters.clarity.systemLog")
        systemDestination.outputLevel = .debug
        systemDestination.showLogIdentifier = false
        systemDestination.showFunctionName = true
        systemDestination.showThreadName = false
        systemDestination.showLevel = true
        systemDestination.showFileName = true
        systemDestination.showLineNumber = true
        systemDestination.showDate = true

        #if INTERNAL
        // 4) File destination (visible in Files app under your app’s Documents)
        let fileURL = LogManager.defaultLogFileURL()
        let fileDestination = AutoRotatingFileDestination(writeToFile: fileURL,
                                                          identifier: "me.craigpeters.clarity.fileLog",
                                                          shouldAppend: true,
                                                          maxFileSize: 10 * 1024 * 1024, // 10 MB
                                                          maxTimeInterval: 24 * 60 * 60,  // rotate daily
                                                          targetMaxLogFiles: 5)           // keep up to 5 files
        fileDestination.outputLevel = .debug
        fileDestination.showLogIdentifier = false
        fileDestination.showFunctionName = true
        fileDestination.showThreadName = false
        fileDestination.showLevel = true
        fileDestination.showFileName = true
        fileDestination.showLineNumber = true
        fileDestination.showDate = true
        
        logger.add(destination: fileDestination)
        #endif

        // Optional: Add a formatter for consistent timestamps or JSON, etc.
        // let formatter = PrePostFixLogFormatter()
        // formatter.apply(prefix: "[MyApp] ", postfix: nil)
        // systemDestination.formatters = [formatter]
        // fileDestination.formatters = [formatter]

        // 5) Add destinations
        logger.add(destination: systemDestination)
        

        // 6) Start the logger
        logger.logAppDetails()

        self.log = logger
    }

    // Location: Documents/MyAppLogs/app.log (visible in Files app)
    static func defaultLogFileURL() -> URL {
        let fm = FileManager.default
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
        let logsDir = docs.appendingPathComponent("ClarityLogs", isDirectory: true)

        // Ensure directory exists
        if !fm.fileExists(atPath: logsDir.path) {
            try? fm.createDirectory(at: logsDir, withIntermediateDirectories: true)
        }

        return logsDir.appendingPathComponent("clarity.log")
    }
}

//
//  Logger.swift
//  Clarity
//
//  Created by Craig Peters on 26/10/2025.
//

import os
import Foundation

extension Logger {
    private static var subsystem = Bundle.main.bundleIdentifier ?? "Clarity"
    
    static let WatchConnectivity = Logger(subsystem: subsystem, category: "WatchConnectivity")
}

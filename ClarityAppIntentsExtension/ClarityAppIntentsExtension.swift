//
//  ClarityAppIntentsExtensionExtension.swift
//  ClarityAppIntentsExtension
//
//  Created by Craig Peters on 14/12/2025.
//

import AppIntents
import ExtensionFoundation
import OSLog
import XCGLogger

@main
struct ClarityAppIntentsExtension: AppIntentsExtension {
    init() {
        LogManager.shared.log.debug("Launched AppIntents")
    }
}

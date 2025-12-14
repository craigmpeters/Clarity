//
//  ClarityAppIntentsExtensionExtension.swift
//  ClarityAppIntentsExtension
//
//  Created by Craig Peters on 14/12/2025.
//

import AppIntents
import ExtensionFoundation
import OSLog

@main
struct ClarityAppIntentsExtension: AppIntentsExtension {
    init() {
        Logger.AppIntents.debug("Launched AppIntents")
    }
}

//
//  WatchClarityApp.swift
//  WatchClarity Watch App
//
//  Created by Craig Peters on 23/09/2025.
//

import SwiftUI
import SwiftData

@main
struct WatchClarity_Watch_AppApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(SharedDataActor.shared.modelContainer)
        }
    }
}

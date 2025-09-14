//
//  ClarityAppIntentsProvider.swift
//  Clarity
//
//  Created by Craig Peters on 03/09/2025.
//

import AppIntents

/// App Shortcuts Provider for Clarity
/// This provides shortcuts and ensures proper App Intent discovery
struct ClarityShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CreateTaskIntent(),
            phrases: [
                "Create a task in \(.applicationName)",
                "Add a new task in \(.applicationName)",
                "New task in \(.applicationName)"
            ],
            shortTitle: "New Task",
            systemImageName: "plus.circle"
        )

//        AppShortcut(
//            intent: StartPomodoroIntent(),
//            phrases: [
//                "Start pomodoro in \(.applicationName)",
//                "Begin focus session in \(.applicationName)",
//                "Start timer in \(.applicationName)"
//            ],
//            shortTitle: "Start Timer",
//            systemImageName: "timer"
//        )
    }
}

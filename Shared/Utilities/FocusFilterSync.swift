//
//  FocusFilterSync.swift
//  Clarity
//
//  Cross-process focus filter change notification (App Intents extension -> iPhone app).
//

import Foundation

/// Posts and observes a Darwin notification when the focus filter changes.
/// Shared between the iPhone app and the App Intents extension.
enum FocusFilterSync {
    /// Posted by the App Intents extension (via CFNotificationCenter) after the
    /// focus filter changed, so the phone immediately rebroadcasts to the watch.
    static let changedNotification = CFNotificationName("me.craigpeters.clarity.focusFilterChanged" as CFString)

    /// Called from the App Intents extension after it persists new focus-filter
    /// settings; wakes the app (if needed) to rebroadcast to the watch.
    nonisolated static func postChanged() {
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            changedNotification,
            nil,
            nil,
            true
        )
    }
}

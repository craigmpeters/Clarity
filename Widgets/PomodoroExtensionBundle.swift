//
//  PomodoroExtensionBundle.swift
//  PomodoroExtension
//
//  Created by Craig Peters on 21/08/2025.
//

import SwiftUI
import WidgetKit

@main
struct PomodoroExtensionBundle: WidgetBundle {
    var body: some Widget {
        PomodoroLiveActivityWidget()
        DueWidget()
        CompletedWidget()
        TaskHistoryWidget()
    }
}

//
//  PomodoroExtensionBundle.swift
//  PomodoroExtension
//
//  Created by Craig Peters on 21/08/2025.
//

import WidgetKit
import SwiftUI

@main
struct PomodoroExtensionBundle: WidgetBundle {
    var body: some Widget {
        PomodoroLiveActivityWidget()
        ClarityTaskWidget()
    }
}

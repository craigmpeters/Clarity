//
//  ClarityWatchWidgetsBundle.swift
//  ClarityWatchWidgets
//
//  Created by Craig Peters on 22/02/2026.
//

import SwiftUI
import WidgetKit

@main
struct ClarityWatchWidgetsBundle: WidgetBundle {
    var body: some Widget {
        WatchDueWidget()
        WatchCompleteWidget()
    }
}

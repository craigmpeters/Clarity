//
//  PomodoroExtensionLiveActivity.swift
//  PomodoroExtension
//
//  Created by Craig Peters on 21/08/2025.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct PomodoroExtensionAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct PomodoroExtensionLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PomodoroExtensionAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension PomodoroExtensionAttributes {
    fileprivate static var preview: PomodoroExtensionAttributes {
        PomodoroExtensionAttributes(name: "World")
    }
}

extension PomodoroExtensionAttributes.ContentState {
    fileprivate static var smiley: PomodoroExtensionAttributes.ContentState {
        PomodoroExtensionAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: PomodoroExtensionAttributes.ContentState {
         PomodoroExtensionAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: PomodoroExtensionAttributes.preview) {
   PomodoroExtensionLiveActivity()
} contentStates: {
    PomodoroExtensionAttributes.ContentState.smiley
    PomodoroExtensionAttributes.ContentState.starEyes
}

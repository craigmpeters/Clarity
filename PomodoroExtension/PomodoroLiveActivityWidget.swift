//
//  PomodoroExtensionLiveActivity.swift
//  PomodoroExtension
//
//  Created by Craig Peters on 21/08/2025.
//
//  TARGET MEMBERSHIP: ✅ Widget Extension ONLY

import Foundation
import ActivityKit
import WidgetKit
import SwiftUI

struct PomodoroLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PomodoroAttributes.self) { context in
            // Lock screen/banner UI
            VStack(spacing: 8) {
                HStack {
                    VStack(alignment: .leading) {
                        Text(context.state.taskName.isEmpty ? "Pomodoro" : context.state.taskName)
                            .font(.headline)
                            .lineLimit(1)
                        // Native countdown timer - no updates needed!
                        Text(context.state.endTime, style: .timer)
                            .font(.title2)
                            .fontWeight(.bold)
                            .monospacedDigit()
                    }
                    Spacer()
                    Image("clarity")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 80, height: 80)
                }
            }
            .padding()
            .background(Color.black.opacity(0.1))
            .cornerRadius(12)
            
        } dynamicIsland: { context in
            DynamicIsland {
                // Minimal expanded region - just the timer
                DynamicIslandExpandedRegion(.center) {
                    HStack() {
                        VStack(alignment: .leading) {
                            Text(context.state.taskName)
                                .font(.subheadline)  // Smaller than .headline
                                .lineLimit(1)
                            Text(context.state.endTime, style: .timer)
                                .font(.title3)       // Smaller than .title2
                                .fontWeight(.semibold)
                                .monospacedDigit()
                        }
                        Image("clarity")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 80, height: 80)

                    }
                    .padding(.vertical, -15.0)
                }
                
                
            } compactLeading: {
                Image("clarity")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    
                
            } compactTrailing: {
                Text(context.state.endTime, style: .timer)
                    .monospacedDigit()
                    .font(.caption2)
                    .frame(maxWidth: .minimum(50, 50), alignment: .leading)
                
            } minimal: {
                Image("clarity")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    
            }
        }
        
        
        
    }
    
}

// MARK: - Preview
#Preview("Live Activity", as: .content, using: PomodoroAttributes(sessionId: "preview")) {
    PomodoroLiveActivityWidget()
} contentStates: {
    PomodoroAttributes.ContentState(
        taskName: "Complete SwiftUI Project",
        startTime: Date(),
        endTime: Date().addingTimeInterval(20)
    )
}

#Preview("Dynamic Island Compact", as: .dynamicIsland(.compact), using: PomodoroAttributes(sessionId: "preview")) {
    PomodoroLiveActivityWidget()
} contentStates: {
    PomodoroAttributes.ContentState(
        taskName: "Complete SwiftUI Project",
        startTime: Date(),
        endTime: Date().addingTimeInterval(25 * 60)
    )
}

#Preview("Dynamic Island Expanded", as: .dynamicIsland(.expanded), using: PomodoroAttributes(sessionId: "preview")) {
    PomodoroLiveActivityWidget()
} contentStates: {
    PomodoroAttributes.ContentState(
        taskName: "Complete SwiftUI Project",
        startTime: Date(),
        endTime: Date().addingTimeInterval(25 * 60)
    )
}

#Preview("Dynamic Island Minimal", as: .dynamicIsland(.minimal), using:
            PomodoroAttributes(sessionId: "preview")) {
    PomodoroLiveActivityWidget()
} contentStates: {
    PomodoroAttributes.ContentState(
        taskName: "Complete SwiftUI Project",
        startTime: Date(),
        endTime: Date().addingTimeInterval(25 * 60)
    )
}

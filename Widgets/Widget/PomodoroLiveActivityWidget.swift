//
//  PomodoroExtensionLiveActivity.swift
//  PomodoroExtension
//
//  Created by Craig Peters on 21/08/2025.
//
//  TARGET MEMBERSHIP: ✅ Widget Extension ONLY

import ActivityKit
import Foundation
import SwiftUI
import WidgetKit

struct PomodoroLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PomodoroAttributes.self) { context in
            PomodoroLiveActivityView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Minimal expanded region - just the timer
                DynamicIslandExpandedRegion(.center) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(context.state.taskName)
                                .font(.subheadline) // Smaller than .headline
                                .lineLimit(1)
                            if context.isStale {
                                Text("Timer Finished!")
                                    .font(.title3) // Smaller than .title2
                                    .fontWeight(.semibold)
                                    .monospacedDigit()
                            } else {
                                Text(context.state.endTime, style: .timer)
                                    .font(.title3) // Smaller than .title2
                                    .fontWeight(.semibold)
                                    .monospacedDigit()
                            }
                        }
                        Image("clarity-teeny")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    }
                }

            } compactLeading: {
                Image("clarity-teeny")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } compactTrailing: {
                if context.isStale {
                    Text("✅")
                } else {
                    Text(context.state.endTime, style: .timer)
                        .monospacedDigit()
                        .font(.caption2)
                        .frame(maxWidth: .minimum(50, 50), alignment: .leading)
                }

            } minimal: {
                if context.isStale {
                    Text("✅")
                } else {
                    Text(context.state.endTime, style: .timer)
                        .monospacedDigit()
                        .font(.caption2)
                        .frame(maxWidth: .minimum(50, 50), alignment: .leading)
                }
            }
        }
        .supplementalActivityFamilies([.small, .medium])
    }
}

// MARK: - Live Activity Content View

struct PomodoroLiveActivityView: View {
    @Environment(\.activityFamily) var activityFamily
    let context: ActivityViewContext<PomodoroAttributes>

    var body: some View {
        switch activityFamily {
        case .small:
            // watchOS Smart Stack — no image, just text
            VStack(spacing: 4) {
                Text(context.state.taskName.isEmpty ? "Pomodoro" : context.state.taskName)
                    .font(.caption2)
                    .lineLimit(1)
                if context.isStale {
                    Text("Timer Finished!")
                        .font(.caption)
                        .fontWeight(.bold)
                } else {
                    Text(context.state.endTime, style: .timer)
                        .font(.caption)
                        .fontWeight(.bold)
                        .monospacedDigit()
                }
            }
        default:
            // Lock screen / banner UI
            VStack(spacing: 8) {
                HStack {
                    VStack(alignment: .leading) {
                        Text(context.state.taskName.isEmpty ? "Pomodoro" : context.state.taskName)
                            .font(.headline)
                            .lineLimit(1)
                        if context.isStale {
                            Text("Timer Finished!")
                                .font(.title2)
                                .fontWeight(.bold)
                                .monospacedDigit()
                        } else {
                            Text(context.state.endTime, style: .timer)
                                .font(.title2)
                                .fontWeight(.bold)
                                .monospacedDigit()
                        }
                    }
                    Spacer()
                    Image("clarity-teeny")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 80, height: 80)
                }
            }
            .padding()
            .background(Color.black.opacity(0.1))
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
    PomodoroAttributes(sessionId: "preview"))
{
    PomodoroLiveActivityWidget()
} contentStates: {
    PomodoroAttributes.ContentState(
        taskName: "Complete SwiftUI Project",
        startTime: Date(),
        endTime: Date().addingTimeInterval(25 * 60)
    )
}

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
                    Text(context.state.taskTitle.isEmpty ? "Pomodoro" : context.state.taskTitle)
                        .font(.headline)
                        .lineLimit(1)
                    Spacer()
                    Text("📝")
                        .font(.title2)
                }
                
                HStack {
                    Text(formatTime(context.state.remainingTime))
                        .font(.title2)
                        .fontWeight(.bold)
                        .monospacedDigit()
                    
                    Spacer()
                    
                    Image(systemName: context.state.isRunning ? "play.fill" : "pause.fill")
                        .foregroundColor(context.state.isRunning ? .green : .orange)
                        .font(.caption)
                }
                
                // Progress bar
                ProgressView(value: progressValue(context.state))
                    .progressViewStyle(LinearProgressViewStyle(tint: .red))
            }
            .padding()
            .background(Color.black.opacity(0.1))
            .cornerRadius(12)
            
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI
                DynamicIslandExpandedRegion(.leading) {
                    VStack {
                        Text("📝")
                            .font(.title2)
                        Text(context.state.isRunning ? "Running" : "Paused")
                            .font(.caption2)
                            .foregroundColor(context.state.isRunning ? .green : .orange)
                    }
                }
                
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing) {
                        Text(formatTime(context.state.remainingTime))
                            .font(.title3)
                            .fontWeight(.semibold)
                            .monospacedDigit()
                        Text("\(Int(progressValue(context.state) * 100))%")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.taskTitle)
                        .font(.body)
                        .fontWeight(.medium)
                        .lineLimit(1)
                }
                
                DynamicIslandExpandedRegion(.bottom) {
                    ProgressView(value: progressValue(context.state))
                        .progressViewStyle(LinearProgressViewStyle(tint: .red))
                        .scaleEffect(x: 1, y: 0.5)
                }
                
            } compactLeading: {
                Text("📝")
                    .font(.body)
                
            } compactTrailing: {
                Text(formatTime(context.state.remainingTime))
                    .monospacedDigit()
                    .font(.caption)
                    .fontWeight(.semibold)
                
            } minimal: {
                Text("📝")
                    .font(.caption)
            }
        }
    }
    
    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private func progressValue(_ state: PomodoroAttributes.ContentState) -> Double {
        guard state.totalTime > 0 else { return 0 }
        return 1.0 - (state.remainingTime / state.totalTime)
    }
}

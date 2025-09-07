//
//  SmallWidgetView.swift
//  PomodoroExtensionExtension
//
//  Created by Craig Peters on 02/09/2025.
//

import SwiftUI

struct SmallTaskWidgetView: View {
    let entry: TaskWidgetEntry
    
    var body: some View {
        // For small widgets, we'll use a Link to open the app with filtered tasks
        // Since there's limited space for interactive elements
        Link(destination: widgetURL) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: entry.filter.systemImage)
                        .font(.title3)
                        .foregroundStyle(entry.filter.color)
                    
                    Spacer()
                    
                    // If there's a single task today, show play button
                    // ToDo: Fix Pomodoro Widget
//                    if entry.filter == .today && entry.tasks.count == 1 {
//                        Button(intent: StartPomodoroIntent(taskId: entry.tasks.first!.id)) {
//                            Image(systemName: "play.circle.fill")
//                                .font(.title3)
//                                .foregroundStyle(.blue)
//                        }
//                        .buttonStyle(.plain)
//                    }
                }
                
                Spacer()
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(entry.taskCount)")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                    
                    Text(entry.filter.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
        }
    }
    
    private var widgetURL: URL {
        URL(string: "clarity://tasks?filter=\(entry.filter.rawValue)")!
    }
}

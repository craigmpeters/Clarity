//
//  MediumWidgetView.swift
//  PomodoroExtensionExtension
//
//  Created by Craig Peters on 02/09/2025.
//

import SwiftUI

struct MediumTaskWidgetView: View {
    let entry: TaskWidgetEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Label(entry.filter.rawValue, systemImage: entry.filter.systemImage)
                    .font(.headline)
                    .foregroundStyle(entry.filter.color)
                
                Spacer()
                
                Text("\(entry.taskCount)")
                    .font(.title2.bold())
            }
            
            Divider()
            
            // Task list (show up to 2 with buttons)
            if entry.tasks.isEmpty {
                Spacer()
                Text("No tasks")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                Spacer()
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(entry.tasks.prefix(2)) { task in
                        MediumTaskRowInteractive(task: task)
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .padding()
    }
}

struct MediumTaskRowInteractive: View {
    let task: TaskWidgetEntry.TaskInfo
    
    var body: some View {
        HStack(spacing: 8) {
            // Complete button
            Button(intent: CompleteTaskIntent(taskId: task.id)) {
                Image(systemName: "circle")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(task.name)
                    .font(.caption)
                    .lineLimit(1)
                
                HStack(spacing: 4) {
                    if !task.categoryColors.isEmpty {
                        Circle()
                            .fill(WidgetColorUtility.colorFromString(task.categoryColors.first!))
                            .frame(width: 6, height: 6)
                    }
                    
                    Text(task.dueTime)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            // Timer button - Now uses StartPomodoroIntent
            Button(intent: StartPomodoroIntent(taskId: task.id)) {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.blue)
            }
            .buttonStyle(.plain)
        }
    }
}

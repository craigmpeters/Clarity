//
//  LargeWidgetView.swift
//  PomodoroExtensionExtension
//
//  Created by Craig Peters on 02/09/2025.
//

import SwiftUI

struct LargeTaskWidgetView: View {
    let entry: TaskWidgetEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Label(entry.filter.rawValue, systemImage: entry.filter.systemImage)
                    .font(.headline)
                    .foregroundStyle(entry.filter.color)
                
                Spacer()
                
                Text("\(entry.taskCount) tasks")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Divider()
            
            // Task list (show up to 4 with buttons)
            if !entry.tasks.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(entry.tasks.prefix(4)) { task in
                        LargeTaskRowInteractive(task: task)
                    }
                }
            } else {
                Text("No tasks")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical)
            }
            
            Spacer()
            
            // Weekly Progress
            if let progress = entry.weeklyProgress {
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label("Weekly Target", systemImage: "target")
                            .font(.caption.bold())
                            .foregroundStyle(.orange)
                        
                        Spacer()
                        
                        Text("\(progress.completed) / \(progress.target)")
                            .font(.caption)
                    }
                    
                    // Progress bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.secondary.opacity(0.2))
                                .frame(height: 6)
                            
                            RoundedRectangle(cornerRadius: 4)
                                .fill(progressColor(for: progress))
                                .frame(
                                    width: geometry.size.width * progressPercentage(for: progress),
                                    height: 6
                                )
                        }
                    }
                    .frame(height: 6)
                }
            }
        }
        .padding()
    }
    
    private func progressColor(for progress: TaskWidgetEntry.WeeklyProgress) -> Color {
        let percentage = progressPercentage(for: progress)
        if percentage >= 1.0 { return .green }
        if percentage >= 0.7 { return .blue }
        if percentage >= 0.4 { return .orange }
        return .red
    }
    
    private func progressPercentage(for progress: TaskWidgetEntry.WeeklyProgress) -> Double {
        guard progress.target > 0 else { return 0 }
        return min(Double(progress.completed) / Double(progress.target), 1.0)
    }
}

struct LargeTaskRowInteractive: View {
    let task: TaskWidgetEntry.TaskInfo
    
    var body: some View {
        HStack(spacing: 8) {
            // Complete button
            Button(intent: CompleteTaskIntent(taskId: task.id)) {
                Image(systemName: "circle")
                    .font(.system(size: 24))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            
            Text(task.name)
                .font(.caption)
                .lineLimit(1)
            
            Spacer()
            
            HStack(spacing: 4) {
                if !task.categoryColors.isEmpty {
                    Circle()
                        .fill(WidgetColorUtility.colorFromString(task.categoryColors.first!))
                        .frame(width: 6, height: 6)
                }
                
                Text("\(task.pomodoroMinutes)m")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
            
            // Timer button - Now uses StartPomodoroIntent
            // ToDo: Fix Pomodoro Widget
//            Button(intent: StartPomodoroIntent(taskId: task.id)) {
//                Image(systemName: "play.circle.fill")
//                    .font(.system(size: 18))
//                    .foregroundStyle(.blue)
//            }
            .buttonStyle(.plain)
        }
    }
}

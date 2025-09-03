//
//  LargeWidgetView.swift
//  PomodoroExtensionExtension
//
//  Created by Craig Peters on 02/09/2025.
//

import SwiftUI

struct LargeWidgetView: View {
    let entry: TaskWidgetEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Label {
                    HStack(spacing: 4) {
                        Text(entry.category?.name ?? entry.filter.rawValue)
                        if let category = entry.category {
                            Circle()
                                .fill(Category.CategoryColor(rawValue: category.colorRawValue)?.SwiftUIColor ?? .gray)
                                .frame(width: 10, height: 10)
                        }
                    }
                } icon: {
                    Image(systemName: entry.filter.systemImage)
                }
                .font(.headline)
                .foregroundStyle(entry.filter.accentColor)
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("\(entry.taskCount)")
                        .font(.title2.bold())
                    Text("tasks")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Divider()
            
            // Task list with timer buttons
            if entry.tasks.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle")
                        .font(.largeTitle)
                        .foregroundStyle(.green)
                    Text("All done!")
                        .font(.headline)
                    Text("No tasks for \(entry.filter.rawValue.lowercased())")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                Spacer()
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(entry.tasks.prefix(5)) { task in
                        LargeTaskRow(task: task)
                        
                        if task.id != entry.tasks.prefix(5).last?.id {
                            Divider()
                        }
                    }
                }
                
                Spacer(minLength: 0)
                
                if entry.taskCount > 5 {
                    Link(destination: viewAllURL) {
                        HStack {
                            Text("View all \(entry.taskCount) tasks")
                                .font(.caption)
                            Image(systemName: "arrow.right")
                                .font(.caption)
                        }
                        .foregroundStyle(entry.filter.accentColor)
                    }
                }
            }
        }
        .padding()
    }
    
    private var viewAllURL: URL {
        var components = URLComponents(string: "clarity://tasks")!
        components.queryItems = [
            URLQueryItem(name: "filter", value: entry.filter.rawValue)
        ]
        return components.url!
    }
}

struct LargeTaskRow: View {
    let task: TaskWidgetEntry.TaskInfo
    
    var body: some View {
        HStack(spacing: 12) {
            // Task info
            VStack(alignment: .leading, spacing: 4) {
                Text(task.name)
                    .font(.subheadline)
                    .lineLimit(2)
                    .foregroundStyle(.primary)
                
                HStack(spacing: 6) {
                    // Categories
                    if !task.categoryColors.isEmpty {
                        HStack(spacing: 4) {
                            ForEach(task.categoryColors.prefix(3), id: \.self) { color in
                                Circle()
                                    .fill(color.SwiftUIColor)
                                    .frame(width: 8, height: 8)
                            }
                        }
                    }
                    
                    // Time
                    Text(formatDueTime(task.dueDate))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    // Duration
                    Label("\(Int(task.pomodoroTime / 60))m", systemImage: "timer")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }
            
            Spacer()
            
            // Timer button
            Link(destination: timerURL) {
                Image(systemName: "play.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.blue)
            }
        }
    }
    
    private var timerURL: URL {
        URL(string: "clarity://task/\(task.id)?action=timer")!
    }
    
    private func formatDueTime(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return formatter.string(from: date)
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter.string(from: date)
        }
    }
}

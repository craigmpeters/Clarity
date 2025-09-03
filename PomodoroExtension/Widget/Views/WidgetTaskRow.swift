//
//  WidgetTaskRow.swift
//  Clarity
//
//  Created by Craig Peters on 03/09/2025.
//

import SwiftUI
struct WidgetTaskRow: View {
    let task: TaskWidgetEntry.TaskInfo
    var compact: Bool = false
    
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .strokeBorder(Color.secondary.opacity(0.3), lineWidth: 1)
                .frame(width: compact ? 12 : 14, height: compact ? 12 : 14)
            
            Text(task.name)
                .font(compact ? .caption2 : .caption)
                .lineLimit(1)
            
            Spacer()
            
            if !task.categoryColors.isEmpty {
                Circle()
                    .fill(colorFromString(task.categoryColors.first!))
                    .frame(width: 6, height: 6)
            }
            
            Text("\(task.pomodoroMinutes)m")
                .font(.caption2)
                .foregroundStyle(.orange)
        }
    }
    
    private func colorFromString(_ colorName: String) -> Color {
        switch colorName {
        case "Red": return .red
        case "Blue": return .blue
        case "Green": return .green
        case "Yellow": return .yellow
        case "Brown": return .brown
        case "Cyan": return .cyan
        case "Pink": return Color(red: 1.0, green: 0.08, blue: 0.58)
        case "Purple": return Color(red: 0.58, green: 0.0, blue: 0.83)
        case "Orange": return .orange
        default: return .gray
        }
    }
}

extension ToDoStore.TaskFilter {
    var systemImage: String {
        switch self {
        case .all: return "tray.full"
        case .today: return "calendar.circle"
        case .tomorrow: return "calendar.badge.plus"
        case .thisWeek: return "calendar"
        case .overdue: return "exclamationmark.triangle"
        }
    }
    
    var color: Color {
        switch self {
        case .all: return .gray
        case .today: return .blue
        case .tomorrow: return .green
        case .thisWeek: return .purple
        case .overdue: return .red
        }
    }
}

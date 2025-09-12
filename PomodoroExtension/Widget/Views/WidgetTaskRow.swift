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
                    .fill(WidgetColorUtility.colorFromString(task.categoryColors.first!))
                    .frame(width: 6, height: 6)
            }
            
            Text("\(task.pomodoroMinutes)m")
                .font(.caption2)
                .foregroundStyle(.orange)
        }
    }
}



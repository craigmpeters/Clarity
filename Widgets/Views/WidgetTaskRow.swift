//
//  WidgetTaskRow.swift
//  Clarity
//
//  Created by Craig Peters on 03/09/2025.
//

import SwiftUI

struct WidgetTaskRow: View {
    let task: ToDoTaskDTO
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
            
            if !task.categories.isEmpty {
                Circle()
                    .fill(task.categories.first?.color.SwiftUIColor ?? Color.primary)
                    .frame(width: 6, height: 6)
            }
            
            Text("\(task.pomodoroTime / 60)m")
                .font(.caption2)
                .foregroundStyle(.orange)
        }
    }
}

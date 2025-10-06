//
//  TaskRowInteractive.swift
//  Clarity
//
//  Created by Craig Peters on 14/09/2025.
//


import SwiftUI

struct TaskRowInteractive: View {
    let task: ToDoTaskDTO
    
    var body: some View {
        HStack(spacing: 8) {
            // Complete button
            Button(intent: CompleteTaskIntent(id: task.id!)) {
                Image(systemName: "circle")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            
            Text(task.name)
                .font(.caption)
                .lineLimit(1)
            
            Spacer()
            
            HStack(spacing: 4) {
                if !task.categories.isEmpty {
                    Circle()
                        .fill(task.categories.first?.color.SwiftUIColor ?? Color.primary)
                        .frame(width: 6, height: 6)
                }
                
                Text("\(task.pomodoroTime/60)m")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
            
            // Timer button - Now uses StartPomodoroIntent
            // TODO: Fix Pomodoro Widget
//            Button(intent: StartPomodoroIntent(taskId: task.id)) {
//                Image(systemName: "play.circle.fill")
//                    .font(.system(size: 18))
//                    .foregroundStyle(.blue)
//            }
            .buttonStyle(.plain)
        }
    }
}

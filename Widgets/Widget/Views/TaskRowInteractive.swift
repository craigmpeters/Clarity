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
            // Complete button (sends encoded ID via App Intent). Falls back to “Task not found” if id is nil.
            Button(intent: task.id.map(CompleteTaskIntent.init) ?? CompleteTaskIntent()) {
                Image(systemName: "circle")
            }
            .buttonStyle(.plain)

            Text(task.name)
                .font(.caption)
                .lineLimit(1)

            Spacer()

            HStack(spacing: 4) {
                if let first = task.categories.first {
                    Circle()
                        .fill(first.color.SwiftUIColor ?? .primary)
                        .frame(width: 6, height: 6)
                }

                Text("\(Int(task.pomodoroTime / 60))m")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        }
        .task {
            let idDesc = task.id.map { String(describing: $0) } ?? "Unknown ID"
            print("Row for \(task.name) — ID: \(idDesc)")
        }
    }
}

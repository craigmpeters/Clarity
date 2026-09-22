//  TaskRowInteractive.swift
//  Clarity
//
//  Created by Craig Peters on 14/09/2025.
//

import SwiftUI
import XCGLogger

struct TaskRowInteractive: View {
    let task: ToDoTaskDTO

    var body: some View {
        Grid(horizontalSpacing: 8, verticalSpacing: 0) {
            GridRow {
                // Column 1: Complete button
                Button(intent: CompleteTaskIntent(task: TaskEntity(id: task.uuid.uuidString, name: task.name, date: task.due, repeating: task.repeating))) {
                    Image(systemName: "circle")
                }
                .buttonStyle(.plain)
                .gridColumnAlignment(.leading)

                // Column 2: Title
                Text(task.name)
                    .font(.caption)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .gridColumnAlignment(.leading)

                // Column 3: Category dot + duration
                HStack(spacing: 4) {
                    if let first = task.categories.first {
                        Circle()
                            .fill(first.color.SwiftUIColor)
                            .frame(width: 6, height: 6)
                    }

                    Text("\(Int(task.pomodoroTime / 60))m")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
                .gridColumnAlignment(.trailing)

                // Column 4: Play button
                Button(intent: StartPomodoroIntent(task: TaskEntity(id: task.uuid.uuidString, name: task.name, date: task.due, repeating: task.repeating))) {
                    Image(systemName: "play.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
                .buttonStyle(.plain)
                .gridColumnAlignment(.trailing)
            }
        }
        .task {
            
            LogManager.shared.log.debug("Row for \(task.name) — ID: \(task.uuid.uuidString)")
        }
    }
}


//
//  TaskRowView.swift
//  Clarity
//
//  Created by Craig Peters on 18/09/2025.
//

import SwiftUI
struct TaskRowView: View {
    let task: ToDoTask
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onComplete: () -> Void
    let onStartTimer: () -> Void
    
    private func formatDate(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        formatter.doesRelativeDateFormatting = true
        return formatter.string(from: date)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(task.name)
                    .lineLimit(1)
                Spacer()
                RecurrenceIndicatorBadge(task: task)
            }
                
            HStack(spacing: 6) {
                ForEach(task.categories) { category in
                    Text(category.name)
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(category.color.SwiftUIColor)
                        )
                        .foregroundColor(category.color.contrastingTextColor)
                }
                Spacer()
                Text(formatDate(date: task.due))
                    .foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onEdit)
        .swipeActions(edge: .leading) {
            Button(action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
            .tint(.red)
        }
        .swipeActions(edge: .trailing) {
            Button(action: onStartTimer) {
                Label("Start Timer", systemImage: "timer")
            }
            .tint(.blue)
            
            Button(action: onComplete) {
                Label("Complete", systemImage: "checkmark")
            }
            .tint(.green)
        }
    }
}

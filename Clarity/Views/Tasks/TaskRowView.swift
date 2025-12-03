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
    
    @State private var showingDeleteAlert = false
    @State private var isDismissing = false
    
    var body: some View {
        HStack(spacing:12) {
            VStack(spacing: 2) {
                Text(task.due, format: .dateTime.day())
                    .font(.title3.weight(.bold))
                Text(task.due, format: .dateTime.month(.abbreviated))
                    .font(.caption2.weight(.semibold))
                    .textCase(.uppercase)
            }
            .foregroundStyle(dateAccentTextColor(task.due))
            .frame(width: 56, height: 48)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(dateAccentBackgroundColor(task.due))
            )
            VStack(alignment: .leading, spacing: 6) {
                Text(task.name ?? "")
                    .font(.headline)
                    .lineLimit(2)
                
                HStack(spacing: 6) {
                    if task.categories?.count ?? 0 >= 3 {
                        ForEach(task.categories!) { category in
                            ZStack {
                                Circle()
                                    .fill(category.color?.SwiftUIColor ?? .gray)
                                    .frame(width: 25, height: 25)
                                Text(String(category.name!.first!))
                                    .textCase(.uppercase)
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.black)
                                        .blendMode(.colorBurn)
                            }
                            .clipShape(Circle())
                        }
                    } else {
                        ForEach(task.categories!) { category in
                            Text(category.name!)
                                .font(.caption2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule().fill(category.color?.SwiftUIColor ?? .gray.opacity(0.2))
                                )
                                .foregroundStyle(category.color!.contrastingTextColor)
                        }
                    }
                    Spacer()
                    HStack(spacing: 8) {
                        RecurrenceIndicatorBadge(task: task)
                        TimerIndicatorBadge(task: task)
                    }
                }
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
            .onTapGesture(perform: onEdit)
            .swipeActions(edge: .trailing) {
                Button {
                    showingDeleteAlert = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .tint(.red)
            }
            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                Button(action: onStartTimer, label: {
                    Label("Start Timer", systemImage: "timer")
                })
                .tint(.blue)
                
                Button(action: onComplete, label: {
                    Label("Complete", systemImage: "checkmark")
                })
                .tint(.green)
            }
            .confirmationDialog(
                "Are you sure you want to delete \(task.name ?? "task")?",
                isPresented: $showingDeleteAlert,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    withAnimation {
                        onDelete()
                    }
                }
                Button("Cancel", role: .cancel) { }
            }
        }
    }
}

func dateAccentTextColor(_ due: Date) -> Color {
    let isToday = Calendar.current.isDateInToday(due)
    let isPast = Date.now.midnight > due.midnight
    
    if isPast { return .red }
    if isToday { return .primary }

    return .primary
}

func dateAccentBackgroundColor(_ due: Date) -> Color {
    let isToday = Calendar.current.isDateInToday(due)
    let isPast = Date.now.midnight > due.midnight
    
    if isPast { return .red.opacity(0.15) }
    if isToday { return .green.opacity(0.15) }
    return Color.accentColor.opacity(0.12)
}
#if DEBUG
#Preview("Default") {
    HStack() {
        TaskRowView(
            task: PreviewData.shared.getToDoTask(),
            onEdit: { print("Task Edited") },
            onDelete: { print("Task Deleted") },
            onComplete: { print("Task Completed") },
            onStartTimer: { print("Timer Started") }
        )
    }
    .padding(30)
}

#Preview("Overdue") {
    HStack() {
        TaskRowView(
            task: PreviewData.shared.getOverDueToDoTask(),
            onEdit: { print("Task Edited") },
            onDelete: { print("Task Deleted") },
            onComplete: { print("Task Completed") },
            onStartTimer: { print("Timer Started") }
        )
    }
    .padding(30)
}

#Preview("Many Categories") {
    HStack() {
        TaskRowView(
            task: PreviewData.shared.makeEveryMonday(PreviewData.shared.getTaskWithManyCategories()) ,
            onEdit: { print("Task Edited") },
            onDelete: { print("Task Deleted") },
            onComplete: { print("Task Completed") },
            onStartTimer: { print("Timer Started") }
        )
    }
    .padding(30)
}
#endif


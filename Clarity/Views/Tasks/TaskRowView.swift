//
//  TaskRowView.swift
//  Clarity
//
//  Created by Craig Peters on 18/09/2025.
//

import SwiftUI
import SwiftData
import os

struct TaskRowView: View {
    let task: ToDoTask
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onComplete: () -> Void
    let onStartTimer: () -> Void
    
    @Environment(\.modelContext) private var context
    @State private var showingDeleteAlert = false
    @State private var isDismissing = false
    @Query private var taskSwipeAndTapOptions: [TaskSwipeAndTapOptions]
    private var currentTaskSwipeAndTapOptions: TaskSwipeAndTapOptions {
        if let existing = taskSwipeAndTapOptions.first {
            return existing
        }
        // No options persisted yet — create a default one, insert into the model context, and return it.
        let defaults = TaskSwipeAndTapOptions()
        context.insert(defaults)
        // Attempt to save; if save fails, we still return the in-memory defaults so UI can function.
        try? context.save()
        return defaults
    }
    
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
            .onTapGesture {
                performAction(.Tap)
            }
            .swipeActions(edge: .trailing,  allowsFullSwipe: false) {
                Button {
                    performAction(.TrailingPrimary)
                    
                } label: {
                    Label(currentTaskSwipeAndTapOptions.primarySwipeTrailing.title, systemImage: currentTaskSwipeAndTapOptions.primarySwipeTrailing.systemImage)
                }
                .tint(currentTaskSwipeAndTapOptions.primarySwipeTrailing.color)
                
                // TODO: Trailing Button Secondary
            }
            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                Button{
                    performAction(.LeadingPrimary)
                } label: {
                    Label(currentTaskSwipeAndTapOptions.primarySwipeLeading.title, systemImage: currentTaskSwipeAndTapOptions.primarySwipeLeading.systemImage)
                }
                .tint(currentTaskSwipeAndTapOptions.primarySwipeLeading.color)
                Button{
                    performAction(.LeadingSecondary)
                } label: {
                    Label(currentTaskSwipeAndTapOptions.secondarySwipeLeading.title, systemImage: currentTaskSwipeAndTapOptions.secondarySwipeLeading.systemImage)
                }
                .tint(currentTaskSwipeAndTapOptions.secondarySwipeLeading.color)
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
    
    func performAction(_ action: ActionOption) {
        Logger.UserInterface.debug("Perform action: \(String(describing: action))")
        switch action {
        case .LeadingPrimary: performActionOption(currentTaskSwipeAndTapOptions.primarySwipeLeading)
        case .LeadingSecondary: performActionOption(currentTaskSwipeAndTapOptions.secondarySwipeLeading)
        case .TrailingPrimary: performActionOption(currentTaskSwipeAndTapOptions.primarySwipeTrailing)
        case .TrailingSecondary: performActionOption(currentTaskSwipeAndTapOptions.secondarySwipeTrailing)
        case .Tap: performActionOption(currentTaskSwipeAndTapOptions.tap)
        }
    }
    
    func performActionOption(_ action: SwipeAction) {
        switch action {
        case .complete:
            onComplete()
        case .delete:
            showingDeleteAlert = true
        case .edit:
            onEdit()
        case .startTimer:
            onStartTimer()
        case .none:
            return
        }
    }
}

enum ActionOption: CustomStringConvertible {
    case LeadingPrimary
    case LeadingSecondary
    case TrailingPrimary
    case TrailingSecondary
    case Tap
    
    var description: String {
        switch self {
        case .LeadingPrimary: return "Leading Primary"
        case .LeadingSecondary: return "Leading Secondary"
        case .TrailingPrimary: return "Trailing Primary"
        case .TrailingSecondary: return "Trailing Secondary"
        case .Tap: return "Tap"
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
        .modelContainer(PreviewData.shared.previewContainer)
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
        .modelContainer(PreviewData.shared.previewContainer)
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
        .modelContainer(PreviewData.shared.previewContainer)
    }
    .padding(30)
}
#endif


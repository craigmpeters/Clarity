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
    let swipeOptions: TaskSwipeAndTapOptions
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onComplete: () -> Void
    let onStartTimer: () -> Void

    @Environment(CompanionService.self) private var companion
    @State private var showingDeleteAlert = false
    @State private var isDismissing = false

    var body: some View {
        HStack(spacing: 12) {
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
                    if task.categories?.count ?? 0 >= 2 {
                        ForEach(task.categories!) { category in
                            CategoryCompactIcon(category: category)
                        }
                    } else {
                        ForEach(task.categories!) { category in
                            CategoryIconPill(category: category)
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
                performAction(.tap)
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                if swipeOptions.primarySwipeTrailing != .none {
                    Button {
                        performAction(.trailingPrimary)
                    } label: {
                        Label(swipeOptions.primarySwipeTrailing.title, systemImage: swipeOptions.primarySwipeTrailing.systemImage)
                    }
                    .tint(swipeOptions.primarySwipeTrailing.color)
                }
                if swipeOptions.secondarySwipeTrailing != .none {
                    Button {
                        performAction(.trailingSecondary)
                    } label: {
                        Label(swipeOptions.secondarySwipeTrailing.title, systemImage: swipeOptions.secondarySwipeTrailing.systemImage)
                    }
                    .tint(swipeOptions.secondarySwipeTrailing.color)
                }
            }
            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                if swipeOptions.primarySwipeLeading != .none {
                    Button {
                        performAction(.leadingPrimary)
                    } label: {
                        Label(swipeOptions.primarySwipeLeading.title, systemImage: swipeOptions.primarySwipeLeading.systemImage)
                    }
                    .tint(swipeOptions.primarySwipeLeading.color)
                }
                if swipeOptions.secondarySwipeLeading != .none {
                    Button {
                        performAction(.leadingSecondary)
                    } label: {
                        Label(swipeOptions.secondarySwipeLeading.title, systemImage: swipeOptions.secondarySwipeLeading.systemImage)
                    }
                    .tint(swipeOptions.secondarySwipeLeading.color)
                }
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
        LogManager.shared.log.debug("Perform action: \(String(describing: action))")
        switch action {
        case .leadingPrimary: performActionOption(swipeOptions.primarySwipeLeading)
        case .leadingSecondary: performActionOption(swipeOptions.secondarySwipeLeading)
        case .trailingPrimary: performActionOption(swipeOptions.primarySwipeTrailing)
        case .trailingSecondary: performActionOption(swipeOptions.secondarySwipeTrailing)
        case .tap: performActionOption(swipeOptions.tap)
        }
    }

    func performActionOption(_ action: SwipeAction) {
        switch action {
        case .complete:
            Task { await companion.refreshContext() }
            companion.trigger(.taskCompleted(taskName: task.name ?? "task"))
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

struct CategoryIconPill: View {
    let category: Category

    var body: some View {
        HStack(spacing: 4) {
            if let iconName = category.iconName, !iconName.isEmpty {
                CategoryIcon.image(for: iconName)
                    .frame(width: 10, height: 10)
            } else if let first = category.name?.first {
                Text(String(first))
                    .textCase(.uppercase)
                    .font(.system(size: 10, weight: .bold))
            }

            Text(category.name ?? "")
                .font(.caption2)
        }
        .foregroundStyle(category.color?.contrastingTextColor ?? .primary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(category.color?.SwiftUIColor ?? .gray.opacity(0.2))
        )
    }
}

struct CategoryCompactIcon: View {
    let category: Category

    var body: some View {
        ZStack {
            Circle()
                .fill(category.color?.SwiftUIColor ?? .gray)
                .frame(width: 25, height: 25)

            if let iconName = category.iconName, !iconName.isEmpty {
                CategoryIcon.image(for: iconName)
                    .frame(width: 14, height: 14)
                    .foregroundStyle(category.color?.contrastingTextColor ?? .primary)
            } else if let first = category.name?.first {
                Text(String(first))
                    .textCase(.uppercase)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.black)
                    .blendMode(.colorBurn)
            }
        }
        .clipShape(Circle())
    }
}

enum ActionOption: CustomStringConvertible {
    case leadingPrimary
    case leadingSecondary
    case trailingPrimary
    case trailingSecondary
    case tap

    var description: String {
        switch self {
        case .leadingPrimary: return "Leading Primary"
        case .leadingSecondary: return "Leading Secondary"
        case .trailingPrimary: return "Trailing Primary"
        case .trailingSecondary: return "Trailing Secondary"
        case .tap: return "Tap"
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
    HStack {
        TaskRowView(
            task: PreviewData.shared.getToDoTask(),
            swipeOptions: TaskSwipeAndTapOptions(),
            onEdit: { print("Task Edited") },
            onDelete: { print("Task Deleted") },
            onComplete: { print("Task Completed") },
            onStartTimer: { print("Timer Started") }
        )
        .modelContainer(PreviewData.shared.previewContainer)
        .environment(CompanionService.shared)
    }
    .padding(30)
}

#Preview("Overdue") {
    HStack {
        TaskRowView(
            task: PreviewData.shared.getOverDueToDoTask(),
            swipeOptions: TaskSwipeAndTapOptions(),
            onEdit: { print("Task Edited") },
            onDelete: { print("Task Deleted") },
            onComplete: { print("Task Completed") },
            onStartTimer: { print("Timer Started") }
        )
        .modelContainer(PreviewData.shared.previewContainer)
        .environment(CompanionService.shared)
    }
    .padding(30)
}

#Preview("Many Categories") {
    HStack {
        TaskRowView(
            task: PreviewData.shared.makeEveryMonday(PreviewData.shared.getTaskWithManyCategories()),
            swipeOptions: TaskSwipeAndTapOptions(),
            onEdit: { print("Task Edited") },
            onDelete: { print("Task Deleted") },
            onComplete: { print("Task Completed") },
            onStartTimer: { print("Timer Started") }
        )
        .modelContainer(PreviewData.shared.previewContainer)
        .environment(CompanionService.shared)
    }
    .padding(30)
}
#endif

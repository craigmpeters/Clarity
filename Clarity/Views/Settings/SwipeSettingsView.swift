//
//  SwipeSettingsView.swift
//  Clarity
//
//  Created by Craig Peters on 12/12/2025.
//

import SwiftUI
import SwiftData

struct SwipeSettingsView: View {
    @Environment(\.modelContext) private var context
    @Query private var taskSwipeAndTapOptions: [TaskSwipeAndTapOptions]
    @State private var optionsRef: TaskSwipeAndTapOptions? = nil

    private var currentTaskSwipeAndTapOptions: TaskSwipeAndTapOptions {
        if let existing = optionsRef ?? taskSwipeAndTapOptions.first {
            return existing
        }
        let defaults = TaskSwipeAndTapOptions()
        context.insert(defaults)
        try? context.save()
        optionsRef = defaults
        return defaults
    }

    var body: some View {
        Form {
            Section("Current Configuration") {
                SwipePreviewTask(currentTaskSwipeAndTapOptions: currentTaskSwipeAndTapOptions)
            }
            Section("Swipe Configuration") {
                    //Text("First Left")
                    //Spacer()
                    Picker("First Left", selection: Binding<SwipeAction>(
                        get: { currentTaskSwipeAndTapOptions.primarySwipeLeading },
                        set: { newValue in
                            currentTaskSwipeAndTapOptions.primarySwipeLeading = newValue
                            try? context.save()
                        }
                    )) {
                        ForEach(SwipeAction.allCases, id: \.self) { action in
                            Text(action.title).tag(action)
                        }
                    }
                    .pickerStyle(.menu)
                    
                    Picker("Second Left", selection: Binding<SwipeAction>(
                        get: {currentTaskSwipeAndTapOptions.secondarySwipeLeading},
                        set: { newValue in
                            currentTaskSwipeAndTapOptions.secondarySwipeLeading = newValue
                            try? context.save()
                        }
                    )) {
                        ForEach(SwipeAction.allCases, id: \.self) { action in
                            Text(action.title).tag(action)}
                    }
                    .pickerStyle(.menu)
                
                Picker("First Right", selection: Binding<SwipeAction>(
                    get: {currentTaskSwipeAndTapOptions.primarySwipeTrailing},
                    set: { newValue in
                        currentTaskSwipeAndTapOptions.primarySwipeTrailing = newValue
                        try? context.save()
                    }
                )) {
                    ForEach(SwipeAction.allCases, id: \.self) { action in
                        Text(action.title).tag(action)}
                }
                .pickerStyle(.menu)
                
                Picker("Second Right", selection: Binding<SwipeAction>(
                    get: {currentTaskSwipeAndTapOptions.secondarySwipeTrailing},
                    set: { newValue in
                        currentTaskSwipeAndTapOptions.secondarySwipeTrailing = newValue
                        try? context.save()
                    }
                )) {
                    ForEach(SwipeAction.allCases, id: \.self) { action in
                        Text(action.title).tag(action)}
                }
                .pickerStyle(.menu)
            }
            Section("Tap Configuration") {
                Picker("Tap", selection: Binding<SwipeAction>(
                    get: {currentTaskSwipeAndTapOptions.tap},
                    set: { newValue in
                        currentTaskSwipeAndTapOptions.tap = newValue
                        try? context.save()
                    }
                )) {
                    ForEach(SwipeAction.allCases, id: \.self) { action in
                        Text(action.title).tag(action)}
                }
            }
            .pickerStyle(.menu)
        }
        .navigationTitle("Swipe Settings")
        
    }
}

struct SwipePreviewTask: View {
    @Environment(\.modelContext) private var context
    var currentTaskSwipeAndTapOptions: TaskSwipeAndTapOptions
    let task = ToDoTask(name: "Example Habit", pomodoro: true, pomodoroTime: 5 * 60, repeating: true, recurrenceInterval: .daily, customRecurrenceDays: 0, due: Date.now, categories: [])
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
                // performAction(.Tap)
            }
            .swipeActions(edge: .trailing,  allowsFullSwipe: false) {
                Button {
                    //performAction(.TrailingPrimary)
                    
                } label: {
                    Label(currentTaskSwipeAndTapOptions.primarySwipeTrailing.title, systemImage: currentTaskSwipeAndTapOptions.primarySwipeTrailing.systemImage)
                }
                .tint(currentTaskSwipeAndTapOptions.primarySwipeTrailing.color)
                
                Button {
                    //performAction(.TrailingPrimary)
                    
                } label: {
                    Label(currentTaskSwipeAndTapOptions.secondarySwipeTrailing.title, systemImage: currentTaskSwipeAndTapOptions.secondarySwipeTrailing.systemImage)
                }
                .tint(currentTaskSwipeAndTapOptions.secondarySwipeTrailing.color)
                
            }
            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                Button{
                    // performAction(.LeadingPrimary)
                } label: {
                    Label(currentTaskSwipeAndTapOptions.primarySwipeLeading.title, systemImage: currentTaskSwipeAndTapOptions.primarySwipeLeading.systemImage)
                }
                .tint(currentTaskSwipeAndTapOptions.primarySwipeLeading.color)
                Button{
                    // performAction(.LeadingSecondary)
                } label: {
                    Label(currentTaskSwipeAndTapOptions.secondarySwipeLeading.title, systemImage: currentTaskSwipeAndTapOptions.secondarySwipeLeading.systemImage)
                }
                .tint(currentTaskSwipeAndTapOptions.secondarySwipeLeading.color)
            }
//            .confirmationDialog(
//                "Are you sure you want to delete \(task.name ?? "task")?",
//                isPresented: $showingDeleteAlert,
//                titleVisibility: .visible
//            ) {
//                Button("Delete", role: .destructive) {
//                    withAnimation {
//                        onDelete()
//                    }
//                }
//                Button("Cancel", role: .cancel) { }
//            }
        }
    }
    
}

#Preview {
    SwipeSettingsView()
}

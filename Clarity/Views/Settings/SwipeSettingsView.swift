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
    var currentTaskSwipeAndTapOptions: TaskSwipeAndTapOptions
    let task = ToDoTask(name: "Example Habit", pomodoro: true, pomodoroTime: 5 * 60, repeating: true, recurrenceInterval: .daily, customRecurrenceDays: 0, due: Date.now, categories: [])

    var body: some View {
        TaskRowView(
            task: task,
            swipeOptions: currentTaskSwipeAndTapOptions,
            showDemo: true,
            onEdit: {},
            onDelete: {},
            onComplete: {},
            onStartTimer: {}
        )
    }
}

#Preview {
    SwipeSettingsView()
}

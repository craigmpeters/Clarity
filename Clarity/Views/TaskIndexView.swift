//
//  SwiftUIView.swift
//  Clarity
//
//  Created by Craig Peters on 17/08/2025.
//

import ActivityKit
import SwiftData
import SwiftUI
import UserNotifications

struct TaskIndexView: View {
    @Environment(\.modelContext) private var context
    @Bindable var toDoStore: ToDoStore
    @State private var taskToAdd = ToDoTask(name: "")
    @State private var showSheet = false
    @State private var pomodoro = Pomodoro()
    @State private var selectedTask: ToDoTask? = nil
    @State private var selectedDuration: TimeInterval = 25 * 60

    var body: some View {
        VStack(spacing: 0) {
            // Main content area
            List(toDoStore.toDoTasks, id: \.id) { task in
                HStack {
                    Text(task.name)
                    Spacer()
                    if task.pomodoro {
                        Text("🍅")
                    }
                    if task.repeating {
                        Image(systemName: "repeat")
                    }
                    Text(task.friendlyDue)
                        .foregroundStyle(.secondary)
                }
                .swipeActions(edge: .leading) {
                    Button {
                        context.delete(task)
                    } label: {
                        Label("Complete", systemImage: "checkmark")
                    }
                    .tint(.green)
                }
                .swipeActions(edge: .trailing) {
                    Button {
                        selectedTask = task
                    } label: {
                        Label("Start Timer", systemImage: "timer")
                    }
                }
            }

            // Bottom form - no Spacer needed here
            Form {
                HStack {
                    TextField("Add Task", text: $taskToAdd.name)
                        .onSubmit {
                            guard !taskToAdd.name.isEmpty else { return }
                            toDoStore.addTodoTask(toDoTask: taskToAdd)
                            taskToAdd = ToDoTask(name: "")
                        }
                        .toolbar {
                            ToolbarItemGroup(placement: .keyboard) {
                                HStack {
                                    MinutePickerView(selectedTimeInterval: $taskToAdd.pomodoroTime)
                                        .lineLimit(1)
                                    Spacer()
                                    Toggle(isOn: $taskToAdd.repeating) {
                                        Image(systemName: "repeat")
                                            .foregroundStyle(.primary)
                                    }
                                    .toggleStyle(.switch)
                                }
                            }
                        }
                    Button(action: {
                        guard !taskToAdd.name.isEmpty else { return }
                        withAnimation(.easeInOut(duration: 0.2)) {
                            toDoStore.addTodoTask(toDoTask: taskToAdd)
                            taskToAdd = ToDoTask(name: "")
                        }
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(.blue.gradient)
                            .font(.system(size: 24, weight: .medium))
                    }
                }
            }
            .frame(maxHeight: 80) // Limit the form height
        }
        .task {
            await requestNotificationPermission()
        }
        .sheet(item: $selectedTask) { task in
            PomodoroView(task: task, toDoStore: toDoStore)
        }
    }

    func requestNotificationPermission() async {
        do {
            _ = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
        } catch {
            print("Error requesting notification permission: \(error)")
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: ToDoTask.self, configurations: config)

    var previewTomorrowDate: Date {
        .now.addingTimeInterval(60 * 60 * 24)
    }

    var previewYesterdayDate: Date {
        .now.addingTimeInterval(-60 * 60 * 24)
    }

    // Create sample data
    let sampleTasks = [
        ToDoTask(name: "Twenty Second Task", pomodoro: true, pomodoroTime: 20, repeating: true, due: previewYesterdayDate),
        ToDoTask(name: "Review code changes", pomodoro: false, pomodoroTime: 15 * 60),
        ToDoTask(name: "Write unit tests", pomodoro: true, pomodoroTime: 30 * 60, due: previewYesterdayDate),
        ToDoTask(name: "Update documentation", pomodoro: true, pomodoroTime: 20 * 60, due: previewTomorrowDate)
    ]

    // Add sample tasks to the container
    for task in sampleTasks {
        container.mainContext.insert(task)
    }

    // Create the ToDoStore with the container's context
    let toDoStore = ToDoStore(modelContext: container.mainContext)

    return TaskIndexView(toDoStore: toDoStore)
        .modelContainer(container)
}

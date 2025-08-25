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
    @State private var taskToAdd = ""
    @State private var showSheet = false
    @State private var pomodoro = Pomodoro()
    @State private var selectedTask: ToDoTask? = nil
    @State private var selectedDuration: TimeInterval = 25 * 60

    var body: some View {
        VStack {
            List(toDoStore.toDoTasks, id: \.id) { task in
                HStack {
                    Text(task.name)
                    Spacer()
                    if task.pomodoro {
                        Text("🍅")
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
            HStack {
                TextField("Add Task", text: $taskToAdd)
                    .onSubmit {
                        let newTask = ToDoTask(name: taskToAdd, pomodoro: true, pomodoroTime: selectedDuration)
                        toDoStore.addTodoTask(toDoTask: newTask)
                        taskToAdd = ""
                    }
                Spacer()
                MinutePickerView(selectedTimeInterval: $selectedDuration)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color(.systemGray4), lineWidth: 0.5)
                    )
            )
        }
        .task {
            await requestNotificationPermission()
        }
        .sheet(item: $selectedTask) { task in
            PomodoroView(task: task,
                         toDoStore: toDoStore)
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

    // Create sample data
    let sampleTasks = [
        ToDoTask(name: "Twenty Second Task", pomodoro: true, pomodoroTime: 20),
        ToDoTask(name: "Review code changes", pomodoro: false, pomodoroTime: 15 * 60),
        ToDoTask(name: "Write unit tests", pomodoro: true, pomodoroTime: 30 * 60),
        ToDoTask(name: "Update documentation", pomodoro: true, pomodoroTime: 20 * 60)
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

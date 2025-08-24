//
//  SwiftUIView.swift
//  Clarity
//
//  Created by Craig Peters on 17/08/2025.
//

import SwiftData
import SwiftUI
import UserNotifications
import ActivityKit

struct TaskIndexView: View {
  @Query private var tasks: [ToDoTask]
  @Environment(\.modelContext) private var context
  @State private var taskToAdd = ""
  @State private var showSheet = false
  @State private var pomodoro = Pomodoro()
  @State private var selectedTask: ToDoTask?
  @StateObject private var liveActivityManager = PomodoroLiveActivityManager()

  var body: some View {
      VStack {
          List(tasks, id: \.id) { task in
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
                      showSheet = true
                      pomodoro.startPomodoro(task: task, description: "Timer is up!")
                      liveActivityManager.startLiveActivity(for: pomodoro)
                  } label: {
                      Label("Start Timer", systemImage: "timer")
                  }
              }
          }
          TextField("Add Task", text: $taskToAdd)
              .onSubmit {
                  let newTask = ToDoTask(name: taskToAdd)
                  context.insert(newTask)
                  taskToAdd = ""
              }
              .padding()
      }
      .task {
          await requestNotificationPermission()
      }
      .sheet(isPresented: $showSheet) {
          PomodoroView(pomodoro: pomodoro, task: selectedTask ?? ToDoTask(name: ""))
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
  TaskIndexView()
      .modelContainer(for: ToDoTask.self, inMemory: true)
}

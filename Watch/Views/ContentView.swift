//
//  ContentView.swift
//  WatchClarity Watch App
//
//  Created by Craig Peters on 23/09/2025.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject private var connectivity = ClarityWatchConnectivity.shared
    @State private var todos: [ToDoTaskDTO] = []

    var body: some View {
        NavigationStack {
            List(todos, id: \.id) { task in
                WatchTaskRow(task: task,
                             onComplete: { completeTask(task)},
                             onStartTimer: { startTimer(task)})

            }
            .navigationTitle("Tasks")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        // Filter Action
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        // Add Task
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .onAppear {
                connectivity.start()
                connectivity.requestListAll { result in
                    if case .success(let list) = result { DispatchQueue.main.async { todos = list } }
                }
            }
        }
    }



    private func completeTask(_ task: ToDoTaskDTO) {
        print("Attempting to complete task \(task.name)")
        connectivity.sendComplete(id: task.id!)
    }

    private func startTimer(_ task: ToDoTaskDTO) {
        print("Attempting to start timer \(task.name)")
        connectivity.sendPomodoroStart(id: task.id!)
    }
}

struct WatchTaskRow: View {
    let task: ToDoTaskDTO
    let onComplete: () -> Void
    let onStartTimer: () -> Void
    
    var body: some View {
        Text(task.name)
            .foregroundStyle(accentTextColor(task.due))
            .listItemTint(accentBackgroundColor(task.due))
            .swipeActions(edge: .leading) {
                Button(action: onStartTimer, label: {
                    Label("Start Timer", systemImage: "timer")
                })
                .tint(.blue)
            }
            .swipeActions(edge: .trailing) {
                Button(action: onComplete, label: {
                    Label("Complete", systemImage: "checkmark")
                })
                .tint(.green)
            }
        
    }
    
    private func accentTextColor(_ due: Date) -> Color {
        let isToday = Calendar.current.isDateInToday(due)
        let isPast = Date.now.midnight > due.midnight

        if isPast { return .red }
        if isToday { return .primary }

        return .primary
    }

    private func accentBackgroundColor(_ due: Date) -> Color {
        let isToday = Calendar.current.isDateInToday(due)
        let isPast = Date.now.midnight > due.midnight

        if isPast { return .red.opacity(0.15) }
        if isToday { return .green.opacity(0.15) }
        return Color.accentColor.opacity(0.12)
    }
}

#if DEBUG
//#Preview {
//    let c = ClarityWatchConnectivity.shared
//    c.lastReceivedTasks = [
//        .init(id: "1", name: "Buy milk", pomodoroTime: 1500, due: .now, categories: ["Home"]),
//        .init(id: "2", name: "Read book", pomodoroTime: 1500, due: Date().addingTimeInterval(86400), categories: [])
//    ]
//    return ContentView()
//}
#endif


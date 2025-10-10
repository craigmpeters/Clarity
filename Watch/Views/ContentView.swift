//
//  ContentView.swift
//  WatchClarity Watch App
//
//  Created by Craig Peters on 23/09/2025.
//

import SwiftUI
import WatchConnectivity
import Combine

struct ContentView: View {
    @ObservedObject private var connectivity = ClarityWatchConnectivity.shared
    @State private var todos: [ToDoTaskDTO] = []
    @State private var isRefreshing = false

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
                    Button(action: refresh) {
                        if isRefreshing {
                            Image(systemName: "arrow.clockwise.circle.fill")
                        } else {
                            Image(systemName: "arrow.clockwise.circle")
                        }
                    }
                    .disabled(isRefreshing)
                }
            }
            .onReceive(connectivity.$lastSnapshot.receive(on: DispatchQueue.main)) { new in
                todos = new
            }
            .onReceive(connectivity.$lastSnapshot) { _ in
                if isRefreshing { isRefreshing = false }
            }
            .overlay {
                if todos.isEmpty {
                    ContentUnavailableView("No Tasks", systemImage: "tray", description: Text("Tap Refresh"))
                }
            }
            .task {
                connectivity.start()
                connectivity.requestListAll { result in
                    if case .success(let list) = result {
                        DispatchQueue.main.async { todos = list }
                    }
                }
            }
        }
    }

    private func completeTask(_ task: ToDoTaskDTO) {
        print("Attempting to complete task \(task.name)")
        guard let encodedId = task.encodedId else { return }
        // Optimistically remove from local list
        if let idx = todos.firstIndex(where: { $0.id == task.id }) {
            todos.remove(at: idx)
        }
        // Use reliable transfer only for completion
        print("📮 Queueing reliable complete for id=\(encodedId)")
        connectivity.sendComplete(id: encodedId)

        // Also schedule a follow-up refresh to reconcile state
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
            connectivity.requestListAll { result in
                if case .success(let list) = result { DispatchQueue.main.async { todos = list } }
            }
        }
    }

    private func startTimer(_ task: ToDoTaskDTO) {
        print("Attempting to start timer \(task.name)")
        guard let encodedId = task.encodedId else { return }
        connectivity.sendPomodoroStart(id: encodedId)
    }

    private func refresh() {
        isRefreshing = true
        connectivity.requestListAll(preferReliable: true) { _ in
            // Prefer relying on applicationContext snapshot to update list; add safety timeout
            DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
                if isRefreshing { isRefreshing = false }
            }
        }
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


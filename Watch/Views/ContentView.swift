//
//  ContentView.swift
//  WatchClarity Watch App
//
//  Created by Craig Peters on 23/09/2025.
//

import SwiftUI
import WatchConnectivity
import XCGLogger
import WidgetKit

struct ContentView: View {
    @State private var store = WatchSnapshotStore.shared
    @State private var isRefreshing = false
    @State private var selectedTab = 0

    var body: some View {
        NavigationStack {
            TabView(selection: $selectedTab) {
                WatchTaskView()
                    .tag(0)
                WatchHabitsView()
                    .tag(1)
                #if INTERNAL
                WatchLogTransferView()
                    .tag(2)
                #endif
            }
            .tabViewStyle(.verticalPage)
            .navigationTitle(selectedTab == 0 ? "Tasks" : "Habits")
            .refreshable(action: refresh)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        selectedTab = selectedTab == 0 ? 1 : 0
                    } label: {
                        Image(systemName: selectedTab == 0 ? "checklist" : "list.bullet")
                    }
                }
//                ToolbarItem(placement: .topBarTrailing) {
//                    Button {
//                        transferLogButton()
//                        refresh()
//                    } label: {
//                        Image(systemName: isRefreshing ? "arrow.clockwise.circle.fill" : "arrow.clockwise.circle")
//                    }
//                    .disabled(isRefreshing)
//                }
            }
            .sheet(item: Binding(
                get: { store.activePomodoro.map(IdentifiedPomodoro.init) },
                set: { _ in WatchSnapshotStore.shared.dismissPomodoro() }
            )) { identified in
                PomodoroView(identified.dto)
            }
            .task {
                LogManager.shared.log.debug("[WATCH] ContentView.task: starting connectivity")
                store.start()
                await store.requestInitialSnapshot()
                LogManager.shared.log.debug("[WATCH] ContentView.task: done")
            }
        }
    }
    
    struct WatchTaskView : View {
        @State private var store = WatchSnapshotStore.shared
        
        var body: some View {
            List {
                ForEach(currentTasks, id: \.id) { task in
                    WatchTaskRow(task: task,
                                 onComplete: { store.complete(task) },
                                 onStartTimer: {store.startPomodoro(task) }
                    )
                }
            }
            .overlay {
                if currentTasks.isEmpty {
                    ContentUnavailableView("No Tasks", systemImage: "tray", description: Text("Tap Refresh"))
                }
            }
            .focusable()
        }
        
        private var currentTasks: [ToDoTaskDTO] {
            store.snapshot.tasks
                .filter { !$0.completed && !store.optimisticallyCompleted.contains($0.uuid) }
                .sorted { $0.due < $1.due }
        }
    }


    private func refresh() {
        isRefreshing = true
        Task {
            await store.requestInitialSnapshot()
            isRefreshing = false
        }
    }
}

#if INTERNAL

struct WatchLogTransferView: View {

    var body : some View {
        VStack {
            Button(action: transferLogButton, label: {
                Text("Send Logs")
            })
        }
    }
    
    private func transferLogButton() {
        LogManager.shared.log.debug("Sending Logs to Phone")
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.me.craigpeters.clarity") else {
            LogManager.shared.log.error("Cannot create Container URL")
            return
        }
        let logData = WidgetFileCoordinator.shared.collectlogs()
        WatchSnapshotStore.shared.sendLogs(logData)
    }
}
#endif


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
            .task {
                LogManager.shared.log.debug("\(task.name) is \(task.completed ? "completed" : "not completed")")
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

private struct IdentifiedPomodoro: Identifiable {
    var id: Date { dto.startTime ?? .distantPast }
    let dto: PomodoroDTO
    init(dto: PomodoroDTO) { self.dto = dto }
}

#if DEBUG
//#Preview {
//    let c = WatchSnapshotStore.shared
//    c.snapshot = Snapshot(revision: 0, tasks: [
//        .init(id: UUID(), name: "Buy milk", pomodoroTime: 1500, due: .now, categories: [], uuid: UUID(), completed: false),
//        .init(id: UUID(), name: "Read book", pomodoroTime: 1500, due: Date().addingTimeInterval(86400), categories: [], uuid: UUID(), completed: false)
//    ], progress: WeeklyProgress(completed: 0, target: 0, error: nil, categories: []), activePomodoro: nil)
//    return ContentView()
//}
#endif

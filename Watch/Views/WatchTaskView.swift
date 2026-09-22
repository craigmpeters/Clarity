//
//  WatchTaskView.swift
//  Clarity
//
//  Created by Craig Peters on 22/09/2026.
//

import SwiftUI


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
            .refreshable {
                await store.requestInitialSnapshot()
            }
        }
        
        private var currentTasks: [ToDoTaskDTO] {
            store.snapshot.tasks
                .filter { !$0.completed && !store.optimisticallyCompleted.contains($0.uuid) }
                .sorted { $0.due < $1.due }
        }
    }

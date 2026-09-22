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

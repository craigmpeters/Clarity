import os
import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject var appState: AppState
    @State private var selectedTask: ToDoTaskDTO? = nil
    @State private var showingPomodoro = false
    @State private var showingFirstRun = !UserDefaults.hasCompletedOnboarding

    @State private var store: ClarityModelActor? = nil

    var body: some View {
        ZStack {
            TabView {
                NavigationStack {
                    TaskIndexView(
                        selectedTask: $selectedTask,
                        showingPomodoro: $showingPomodoro
                    )
                    .navigationTitle("Tasks")
                }
                .tabItem {
                    Image(systemName: "list.bullet")
                    Text("Tasks")
                }
                NavigationStack {
                    StatsView()
                        .navigationTitle("Statistics")
                }
                .tabItem {
                    Image(systemName: "chart.bar")
                    Text("Stats")
                }
                NavigationStack {
                    SettingsView()
                        .navigationTitle("Settings")
                }
                .tabItem {
                    Image(systemName: "gear")
                    Text("Settings")
                }
            }
            .opacity(showingPomodoro ? 0 : 1)
            .scaleEffect(showingPomodoro ? 0.95 : 1.0)

            // Pomodoro View Overlay
            if appState.showingPomodoro {
                PomodoroView()
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    ))
                    .zIndex(1)
            }
        }
        .sheet(isPresented: $showingFirstRun) {
            FirstRunView()
                .interactiveDismissDisabled()
        }
        .animation(.easeInOut(duration: 0.3), value: showingPomodoro)
        .onOpenURL { url in
            LogManager.shared.log.debug("Got URL: \(url)")
            if url.scheme == "clarityapp" {
                LogManager.shared.log.debug("clarityapp")
                if url.host == "timer",
                   let taskId = url.pathComponents.last
                {
                    LogManager.shared.log.debug("timer")
                    Task {
                        LogManager.shared.log.info("Recieved Start Pomodoro for \(taskId)")

//                        if let store = store {
//                            guard let uuid = UUID(from: taskId as! Decoder) else {
//                                return
//                            }
//                            let dtutask = store.fetchTaskByUuid(uuid)
//                            Logger.UserInterface.debug("Starting Pomodoro for \(dtutask?.name)")
//
//                        }
                    }
                }
            }
        }
        .task {
            if store == nil {
                let bg = await ClarityModelActorFactory.makeBackground(container: context.container)
                store = bg
            }
        }
    }
}

#if DEBUG
 #Preview("Demo View") {
    ContentView()
        .modelContainer(PreviewData.shared.previewContainer)
        .environmentObject(AppState())
 }

#endif

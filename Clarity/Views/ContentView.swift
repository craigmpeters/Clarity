import os
import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject var appState: AppState
    @Environment(CompanionService.self) private var companion
    @StateObject private var pomodoroService: PomodoroService = .shared
    @State private var selectedTask: ToDoTaskDTO? = nil
    @State private var showingFirstRun = !UserDefaults.hasCompletedOnboarding

    @State private var store: ClarityModelActor? = nil

    var body: some View {
        TabView(selection: $appState.selectedTab) {
            NavigationStack {
                TaskIndexView(
                    selectedTask: $selectedTask
                )
                .navigationTitle("Tasks")
            }
            .tabItem {
                Image(systemName: "list.bullet")
                Text("Tasks")
            }
            .tag(0)

            PomodoroView()
                .tabItem {
                    Image(systemName: "timer")
                    Text("Focus")
                }
                .tag(1)
                .badge(pomodoroService.isActive ? 1 : 0)

            NavigationStack {
                StatsView()
                    .navigationTitle("Statistics")
            }
            .tabItem {
                Image(systemName: "chart.bar")
                Text("Stats")
            }
            .tag(2)

            NavigationStack {
                SettingsView()
                    .navigationTitle("Settings")
            }
            .tabItem {
                Image(systemName: "gear")
                Text("Settings")
            }
            .tag(3)
        }
        .sheet(isPresented: $showingFirstRun) {
            FirstRunView()
                .interactiveDismissDisabled()
        }
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
                    }
                }
            }
        }
        .task {
            if store == nil {
                let bg = await ClarityModelActorFactory.makeBackground(container: context.container)
                store = bg
                companion.setStore(bg)
                await companion.loadContext(from: bg)
                // Fire appLaunch only after context is ready, so Otto has task data
                companion.trigger(.appLaunch)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            // Guard against the notification that fires immediately on first launch
            // (store will be nil then; the .task block handles that case)
            guard store != nil else { return }
            Task { await companion.refreshContext() }
        }
        .overlay {
            CompanionOverlayView(companion: companion)
                .ignoresSafeArea()
        }
    }
}

#if DEBUG
 #Preview("Demo View") {
    ContentView()
        .modelContainer(PreviewData.shared.previewContainer)
        .environmentObject(AppState())
        .environment(CompanionService.shared)
 }

#endif

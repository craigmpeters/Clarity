import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
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
            if showingPomodoro, let selectedTask = selectedTask {
                PomodoroView(
                    task: selectedTask,
                    showingPomodoro: $showingPomodoro
                )
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
            if url.scheme == "clarity" {
                if url.host == "timer",
                   let taskId = url.pathComponents.last
                {
                    Task {
                        if let store = store, let id = try ToDoTaskDTO.decodeId(taskId) {
                            selectedTask = try await store.fetchTaskById(id)
                        }
                    }
                }
            }
        }
        .task {
            if store == nil {
                let bg = await ClarityModelActorFactory.makeBackground(container: modelContext.container)
                store = bg
            }
        }
    }
}

#if DEBUG
//#Preview {
//    ContentView(store: ClarityModelActor)
//        .modelContainer(PreviewData.shared.previewContainer)
//}
#endif


import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedTask: ToDoTask? = nil
    @State private var showingPomodoro = false
    @State private var showingFirstRun = !UserDefaults.hasCompletedOnboarding
    
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
                        if let task = await findTask(withId: taskId) {
                            selectedTask = task
                            showingPomodoro = true
                        }
                    }
                }
            }
        }
    }

    func findTask(withId id: String) async -> ToDoTask? {
        // Search through your tasks for matching ID
        do {
            let tasks = try await MainDataActor.shared.fetchTasks(ToDoTask.TaskFilter.all)
            return tasks.first { task in
                String(describing: task.id) == id
            }
        } catch {
            return nil
        }

    }

    func handleWidgetDeepLink(_ url: URL) {
        guard url.scheme == "clarity" else { return }
        
        if url.host == "task" {
            // Parse task ID and action
            let pathComponents = url.pathComponents
            if pathComponents.count > 1 {
                let taskId = pathComponents[1]
                
                if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                   let action = components.queryItems?.first(where: { $0.name == "action" })?.value
                {
                    if action == "timer" {
                        // Start timer for task
                        // Find task by ID and start pomodoro
                    } else if action == "view" {
                        // Navigate to task detail
                    }
                }
            }
        } else if url.host == "tasks" {
            // Parse filter and category
            if let components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
                let filter = components.queryItems?.first(where: { $0.name == "filter" })?.value
                let categoryId = components.queryItems?.first(where: { $0.name == "categoryId" })?.value
                
                // Navigate to filtered task list
            }
        }
    }
}

#if DEBUG
#Preview {
    return ContentView()
        .modelContainer(PreviewData.shared.previewContainer)
}
#endif

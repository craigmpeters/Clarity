import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var toDoStore: ToDoStore?
    @State private var selectedTask: ToDoTask? = nil
    @State private var showingPomodoro = false
    @State private var showingFirstRun = !UserDefaults.hasCompletedOnboarding
    
    var body: some View {
        ZStack {
            // Main TabView
            TabView {
                // Tasks Tab
                NavigationStack {
                    if let toDoStore = toDoStore {
                        TaskIndexView(
                            toDoStore: toDoStore,
                            selectedTask: $selectedTask,
                            showingPomodoro: $showingPomodoro
                        )
                        .navigationTitle("Tasks")
                    } else {
                        ProgressView("Loading...")
                    }
                }
                .tabItem {
                    Image(systemName: "list.bullet")
                    Text("Tasks")
                }
                
                // Stats Tab
                NavigationStack {
                    StatsView()
                        .navigationTitle("Statistics")
                }
                .tabItem {
                    Image(systemName: "chart.bar")
                    Text("Stats")
                }
                
                // Settings Tab
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
            if showingPomodoro, let selectedTask = selectedTask, let toDoStore = toDoStore {
                PomodoroView(
                    task: selectedTask,
                    toDoStore: toDoStore,
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
        .onAppear {
            if toDoStore == nil {
                toDoStore = ToDoStore(modelContext: modelContext)
            }
        }
        // In your TaskIndexView or ContentView
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            toDoStore?.loadToDoTasks() // Refresh the data when app becomes active
        }
        
        .onOpenURL { url in
            if url.scheme == "clarity" {
                if url.host == "timer",
                   let taskId = url.pathComponents.last
                {
                    // Find the task and start the timer
                    if let task = findTask(withId: taskId) {
                        selectedTask = task
                        showingPomodoro = true
                    }
                }
            }
        }
    }

    func findTask(withId id: String) -> ToDoTask? {
        // Search through your tasks for matching ID
        return toDoStore!.toDoTasks.first {
            String(describing: $0.id) == id
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

// Placeholder views - replace with your actual views
struct TimerView: View {
    var body: some View {
        VStack {
            Text("Timer View")
                .font(.largeTitle)
            Text("Pomodoro timer will go here")
                .foregroundColor(.secondary)
        }
    }
}

//#Preview {
//    let config = ModelConfiguration(isStoredInMemoryOnly: true)
//    let container = try! ModelContainer(for: ToDoTask.self, configurations: config)
//    
//    // Add some sample data
//    let sampleTasks = [
//        ToDoTask(name: "Complete SwiftUI project", pomodoro: true, pomodoroTime: 25 * 60),
//        ToDoTask(name: "Review code changes", pomodoro: false, pomodoroTime: 15 * 60),
//        ToDoTask(name: "Write unit tests", pomodoro: true, pomodoroTime: 30 * 60)
//    ]
//    
//    for task in sampleTasks {
//        container.mainContext.insert(task)
//    }
//    
//    return ContentView()
//        .modelContainer(container)
//}

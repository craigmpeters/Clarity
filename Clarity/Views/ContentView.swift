import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var toDoStore: ToDoStore?
    @State private var selectedTask: ToDoTask? = nil
    @State private var showingPomodoro = false
    
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

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: ToDoTask.self, configurations: config)
    
    // Add some sample data
    let sampleTasks = [
        ToDoTask(name: "Complete SwiftUI project", pomodoro: true, pomodoroTime: 25 * 60),
        ToDoTask(name: "Review code changes", pomodoro: false, pomodoroTime: 15 * 60),
        ToDoTask(name: "Write unit tests", pomodoro: true, pomodoroTime: 30 * 60)
    ]
    
    for task in sampleTasks {
        container.mainContext.insert(task)
    }
    
    return ContentView()
        .modelContainer(container)
}

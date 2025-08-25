import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var toDoStore: ToDoStore?
    
    var body: some View {
        TabView {
            Group {
                if let store = toDoStore {
                    TaskIndexView(toDoStore: store)
                } else {
                    ProgressView("Loading...")
                }
            }
            .tabItem {
                Image(systemName: "checkmark.square")
                Text("Tasks")
            }
        }
        .onAppear {
            if toDoStore == nil {
                toDoStore = ToDoStore(modelContext: modelContext)
            }
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

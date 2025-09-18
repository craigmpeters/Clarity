import ActivityKit
import SwiftData
import SwiftUI
import UserNotifications

struct TaskIndexView: View {
    @Environment(\.modelContext) private var context
    @Bindable var toDoStore: ToDoStore
    
    @Binding var selectedTask: ToDoTask?
    @Binding var showingPomodoro: Bool
    
    @State private var showingTaskForm = false
    @State private var taskToEdit: ToDoTask?
    @State private var selectedFilter: ToDoStore.TaskFilter = .all
    @State private var selectedCategory: Category?
    
    @Query private var allCategories: [Category]
    
    private var filteredTasks: [ToDoTask] {
        let filtered = toDoStore.toDoTasks.filter { task in
            let dueDateMatches = selectedFilter.matches(task: task)
            let categoryMatches = selectedCategory == nil ||
                task.categories.contains { $0.name == selectedCategory?.name }
            
            return dueDateMatches && categoryMatches
        }
        print("Total tasks: \(toDoStore.toDoTasks.count), Filtered: \(filtered.count)")
        return filtered
    }

    var body: some View {
        List(filteredTasks, id: \.id) { task in
            TaskRowView(
                task: task,
                onEdit: { editTask(task) },
                onDelete: { deleteTask(task) },
                onComplete: { completeTask(task) },
                onStartTimer: { startTimer(for: task) }
            )
        }
        .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        FilterMenuView(
                            selectedFilter: $selectedFilter,
                            selectedCategory: $selectedCategory,
                            allCategories: allCategories,
//                            onFilterChange: { filter in
//                                    toDoStore.loadFilteredTasks(filter)
//                            }
                        )
                    }
                    
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: { showingTaskForm = true }) {
                            Image(systemName: "plus")
                                .foregroundStyle(.blue)
                        }
                    }
                }
        .task {
            await requestNotificationPermission()
        }
        //.refreshable(action: toDoStore.loadToDoTasks())
        .sheet(isPresented: $showingTaskForm, onDismiss: {
            taskToEdit = nil
        }) {
            // Swift UI Evaluation Hack
            [showingTaskForm] in
            TaskFormView(toDoStore: toDoStore, task: taskToEdit)
        }
    }
    
    // MARK: - Actions (moved to background)
    
    private func editTask(_ task: ToDoTask) {
        taskToEdit = task
        showingTaskForm = true
    }
    
    private func deleteTask(_ task: ToDoTask) {
        Task {
            toDoStore.deleteToDoTask(toDoTask: task)
        }
    }
    
    private func completeTask(_ task: ToDoTask) {
        Task {
            toDoStore.completeToDoTask(toDoTask: task)
        }
    }
    
    private func startTimer(for task: ToDoTask) {
        selectedTask = task
        withAnimation(.easeInOut(duration: 0.3)) {
            showingPomodoro = true
        }
    }
    
    private func requestNotificationPermission() async {
        do {
            _ = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
        } catch {
            print("Error requesting notification permission: \(error)")
        }
    }
}

#Preview {
    @Previewable @State var showingPomodoro = false
    @Previewable @State var selectedTask: ToDoTask? = nil
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: ToDoTask.self, Category.self, configurations: config) // Add Category.self
    
    // Add some sample categories for testing
    let workCategory = Category(name: "Work", color: .Blue)
    let personalCategory = Category(name: "Personal", color: .Green)
    container.mainContext.insert(workCategory)
    container.mainContext.insert(personalCategory)
    
    // Create sample task with categories
    let sampleTask = ToDoTask(name: "Sample Task", pomodoroTime: 20.0, repeating: true)
    sampleTask.categories = [workCategory]
    container.mainContext.insert(sampleTask)
    
    let toDoStore = ToDoStore(modelContext: container.mainContext)
    
    return TaskIndexView(
        toDoStore: toDoStore,
        selectedTask: .constant(selectedTask),
        showingPomodoro: .constant(showingPomodoro)
    )
    .modelContainer(container)
}

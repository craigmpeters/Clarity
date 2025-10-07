import ActivityKit
import SwiftData
import SwiftUI
import UserNotifications

struct TaskIndexView: View {
    @Environment(\.modelContext) private var context
    
    @Binding var selectedTask: ToDoTaskDTO?
    @Binding var showingPomodoro: Bool
    
    @State private var showingTaskForm = false
    @State private var taskToEdit: ToDoTaskDTO?
    @State private var selectedFilter: ToDoTask.TaskFilter = .all
    @State private var selectedCategory: Category?
    @State private var store: ClarityModelActor?
    
    @Query private var allCategories: [Category]
    @Query(filter: #Predicate<ToDoTask> { !$0.completed }, sort: \ToDoTask.due, order: .forward) private var allTasks: [ToDoTask]
    
    private var filteredTasks: [ToDoTask] {
        let filtered = allTasks.filter { task in
            let dueDateMatches = selectedFilter.matches(task: task)
            let categoryMatches: Bool = {
                guard let selectedCategory else { return true }
                let taskCategories = task.categories ?? []
                return taskCategories.contains { $0.name == selectedCategory.name }
            }()
            
            return dueDateMatches && categoryMatches
        }
        print("Total tasks: \(allTasks.count), Filtered: \(filtered.count)")
        return filtered
    }

    var body: some View {
        List(filteredTasks) { task in
            TaskRowView(
                task: task,
                onEdit: { editTask(task) },
                onDelete: { deleteTask(ToDoTaskDTO(from: task)) },
                onComplete: { completeTask(ToDoTaskDTO(from: task)) },
                onStartTimer: { startTimer(for: ToDoTaskDTO(from: task)) }
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
            store = await StoreRegistry.shared.store(for: context.container)
        }
        // .refreshable(action: toDoStore.loadToDoTasks())
        .sheet(isPresented: $showingTaskForm, onDismiss: {
            taskToEdit = nil
        }) {
            // Swift UI Evaluation Hack
            [showingTaskForm] in
            TaskFormView(task: taskToEdit)
        }
    }
    
    // MARK: - Actions (moved to background)
    
    private func editTask(_ task: ToDoTask) {
        print("Editing \(task.name)")
        taskToEdit = ToDoTaskDTO(from: task)
        showingTaskForm = true
    }
    
    private func deleteTask(_ task: ToDoTaskDTO) {
        print("Deleting: (\(task.name))")
        Task {
            try? await store?.deleteTask(task.id!)
        }
    }
    
    private func completeTask(_ task: ToDoTaskDTO) {
        print("Attempting to complete task for ID: \(task.id.debugDescription)")
        guard let store = store else { return }
        guard let id = task.id else { return }
        print("Attempting to complete task \(task.name)")
        Task {
            try? await store.completeTask(id)
        }
        
    }
    
    private func startTimer(for task: ToDoTaskDTO) {
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

#if DEBUG
#Preview {
    @Previewable @State var showingPomodoro = false
    @Previewable @State var selectedTask: ToDoTaskDTO? = nil
    TaskIndexView(
        selectedTask: .constant(selectedTask),
        showingPomodoro: .constant(showingPomodoro)
    )
    .modelContainer(PreviewData.shared.previewContainer)
}
#endif

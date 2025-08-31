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
            
            print("Task: \(task.name)")
            print("  Due: \(task.due)")
            print("  Task categories: \(task.categories.map { $0.name })")  // Add this line
            print("  Selected filter: \(selectedFilter.rawValue)")
            print("  Due date matches: \(dueDateMatches)")
            print("  Selected category: \(selectedCategory?.name ?? "nil")")
            print("  Category matches: \(categoryMatches)")
            print("  Overall match: \(dueDateMatches && categoryMatches)")
            print("---")
            
            return dueDateMatches && categoryMatches
        }
        print("Total tasks: \(toDoStore.toDoTasks.count), Filtered: \(filtered.count)")
        return filtered
    }

    var body: some View {
        List(filteredTasks, id: \.id) { task in
            VStack(alignment: .leading, spacing: 6) {
                // First line - task info
                HStack {
                    Text(task.name)
                        .lineLimit(1)
                    Spacer()
                    if task.repeating {
                        Image(systemName: "repeat")
                    }
                    Text(task.friendlyDue())
                        .foregroundStyle(.secondary)
                }
                    
                // Second line - compact categories
//                    if !task.categories.isEmpty {
                HStack(spacing: 6) {
                    ForEach(task.categories) { category in
                        Text(category.name)
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(category.color.SwiftUIColor)
                            )
                            .foregroundColor(category.color.contrastingTextColor)
                    }
                    Spacer()
                }
//                    }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                taskToEdit = task
                showingTaskForm = true
            }
            
            .swipeActions(edge: .leading) {
                Button {
                    toDoStore.deleteToDoTask(toDoTask: task)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .tint(.red)
            }
            .swipeActions(edge: .trailing) {
                Button {
                    selectedTask = task
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showingPomodoro = true
                    }
                } label: {
                    Label("Start Timer", systemImage: "timer")
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Menu {
                    // Due date filters
                    Section("Due Date") {
                        ForEach(ToDoStore.TaskFilter.allCases, id: \.self) { filter in
                            Button(action: { selectedFilter = filter }) {
                                HStack {
                                    Text(filter.rawValue)
                                    if selectedFilter == filter {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    }
                                
                    // Category filters
                    if !allCategories.isEmpty {
                        Section("Category") {
                            Button(action: { selectedCategory = nil }) {
                                HStack {
                                    Text("All Categories")
                                    if selectedCategory == nil {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                                        
                            ForEach(allCategories, id: \.id) { category in
                                Button(action: { selectedCategory = category }) {
                                    HStack {
                                        Circle()
                                            .fill(category.color.SwiftUIColor)
                                            .frame(width: 12, height: 12)
                                        Text(category.name)
                                        if selectedCategory?.name == category.name {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        }
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .foregroundStyle(.blue)
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    taskToEdit = nil
                    showingTaskForm = true
                }) {
                    Image(systemName: "plus")
                        .foregroundStyle(.blue)
                }
            }
        }
        .task {
            await requestNotificationPermission()
        }
        .sheet(isPresented: $showingTaskForm, onDismiss: {
            taskToEdit = nil
        }) {
            // Swift UI Evaluation Hack
            [showingTaskForm] in
            TaskFormView(toDoStore: toDoStore, task: taskToEdit)
        }
    }

    func requestNotificationPermission() async {
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

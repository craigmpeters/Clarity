import ActivityKit
import SwiftData
import SwiftUI
import UserNotifications

struct TaskIndexView: View {
    @Environment(\.modelContext) private var context
    @Bindable var toDoStore: ToDoStore
    
    @Binding var selectedTask: ToDoTask?
    @Binding var showingPomodoro: Bool
    @State private var showingAddTask = false

    var body: some View {
        List(toDoStore.toDoTasks, id: \.id) { task in
            VStack(alignment: .leading, spacing: 6) {
                    // First line - task info
                    HStack {
                        Text(task.name)
                            .lineLimit(1)
                        Spacer()
                        if task.repeating {
                            Image(systemName: "repeat")
                        }
                        Text(task.friendlyDue)
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
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showingAddTask = true
                }) {
                    Image(systemName: "plus")
                        .foregroundStyle(.blue)
                }
            }
        }
        .task {
            await requestNotificationPermission()
        }
        .sheet(isPresented: $showingAddTask) {
            AddTaskView(toDoStore: toDoStore)
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

struct AddTaskView: View {
    @Bindable var toDoStore: ToDoStore
    @Environment(\.dismiss) private var dismiss
    @State private var taskToAdd = ToDoTask(name: "")
    @State private var selectedCategories: [Category] = []
    
    var body: some View {
        NavigationView {
            Form {
                Section("Task Details") {
                    TextField("Task name", text: $taskToAdd.name)
                        .textFieldStyle(.roundedBorder)
                }
                
                Section("Task Settings") {
                    HStack {
                        Image(systemName: "timer")
                            .foregroundStyle(.orange)
                        Text("Duration")
                        Spacer()
                        MinutePickerView(selectedTimeInterval: $taskToAdd.pomodoroTime)
                    }
                    
                    Toggle(isOn: $taskToAdd.repeating) {
                        HStack {
                            Image(systemName: "repeat")
                                .foregroundStyle(.blue)
                            Text("Repeating Task")
                        }
                    }
                    CategorySelectionView(selectedCategories: $selectedCategories)
                }
            }
            .navigationTitle("Add Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            taskToAdd.categories = selectedCategories
                            toDoStore.addTodoTask(toDoTask: taskToAdd)
                        }
                        dismiss()
                    }
                    .disabled(taskToAdd.name.isEmpty)
                    .fontWeight(.semibold)
                }
            }
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

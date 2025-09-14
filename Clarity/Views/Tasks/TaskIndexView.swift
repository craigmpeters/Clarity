import ActivityKit
import SwiftData
import SwiftUI
import UserNotifications

struct DayChangeTimelineSchedule: TimelineSchedule {
    func entries(from startDate: Date, mode: TimelineScheduleMode) -> AnyIterator<Date> {
        let calendar = Calendar.current
        var current = startDate
        
        return AnyIterator {
            let result = current
            
            // Calculate next significant update time
            let nextMidnight = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: current) ?? current)
            let nextHour = calendar.date(bySettingHour: calendar.component(.hour, from: current) + 1, minute: 0, second: 0, of: current) ?? current
            
            // Choose whichever comes first - next hour or midnight
            current = min(nextMidnight, nextHour)
            
            return result
        }
    }
}

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
        // Pre-filter once with explicit steps to help the type-checker
        let tasks: [ToDoTask] = toDoStore.toDoTasks

        // Filter by due date first
        let dueFiltered: [ToDoTask] = tasks.filter { task in
            selectedFilter.matches(task: task)
        }

        // Then filter by category if one is selected
        let finalFiltered: [ToDoTask]
        if let selected = selectedCategory {
            let selectedName = selected.name
            finalFiltered = dueFiltered.filter { task in
                // Use nil-coalescing in case names are optional in your model
                    task.categories!.contains { cat in
                        (cat.name) == selectedName
                    }
            }
        } else {
            finalFiltered = dueFiltered
        }

        print("Total tasks: \(tasks.count), Filtered: \(finalFiltered.count)")
        return finalFiltered
    }

    var body: some View {
        List(filteredTasks) { task in
            TaskRow(task: task)
                .contentShape(Rectangle())
                .onTapGesture {
                    taskToEdit = task
                    showingTaskForm = true
                }
                .swipeActions(edge: .trailing) {
                    Button {
                        toDoStore.deleteToDoTask(toDoTask: task)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .tint(.red)
                }
                .swipeActions(edge: .leading, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        toDoStore.completeToDoTask(toDoTask: task)
                    } label: {
                        Label("Complete", systemImage: "checkmark")
                    }
                    .tint(.green)
                    Button {
                        selectedTask = task
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showingPomodoro = true
                        }
                    } label: {
                        Label("Start Timer", systemImage: "timer")
                    }
                    .tint(.blue)
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
                                        Text(category.name ?? "")
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

    private struct CategoryChips: View {
        let categories: [Category]

        var body: some View {
            HStack(spacing: 6) {
                ForEach(categories) { category in
                    Text(category.name ??  "")
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(category.color.SwiftUIColor)
                        )
                        .foregroundColor(category.color.contrastingTextColor)
                }
            }
        }
    }

    private struct TaskRow: View {
        let task: ToDoTask

        var body: some View {
            VStack(alignment: .leading, spacing: 6) {
                titleRow
                detailRow
            }
        }

        private var titleRow: some View {
            HStack {
                Text(task.name ?? "")
                    .lineLimit(1)
                Spacer()
                RecurrenceIndicatorBadge(task: task)
            }
        }

        private var detailRow: some View {
            HStack(spacing: 6) {
                CategoryChips(categories: task.categories ?? [])
                Spacer()
                Text(task.friendlyDue())
                    .foregroundStyle(.secondary)
            }
        }
    }
}

//#Preview {
//    @Previewable @State var showingPomodoro = false
//    @Previewable @State var selectedTask: ToDoTask? = nil
//    let config = ModelConfiguration(isStoredInMemoryOnly: true)
//    let container = try! ModelContainer(for: ToDoTask.self, Category.self, configurations: config) // Add Category.self
//    
//    // Add some sample categories for testing
//    let workCategory = Category(name: "Work", color: .Blue)
//    let personalCategory = Category(name: "Personal", color: .Green)
//    container.mainContext.insert(workCategory)
//    container.mainContext.insert(personalCategory)
//    
//    // Create sample task with categories
//    let sampleTask = ToDoTask(name: "Sample Task", pomodoroTime: 20.0, repeating: true)
//    sampleTask.categories = [workCategory]
//    container.mainContext.insert(sampleTask)
//    
//    let toDoStore = ToDoStore(modelContext: container.mainContext)
//    
//    return TaskIndexView(
//        toDoStore: toDoStore,
//        selectedTask: .constant(selectedTask),
//        showingPomodoro: .constant(showingPomodoro)
//    )
//    .modelContainer(container)
//}


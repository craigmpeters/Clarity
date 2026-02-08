import ActivityKit
import SwiftData
import SwiftUI
import UserNotifications
import XCGLogger

struct TaskIndexView: View {
    @Environment(\.modelContext) private var context
    
    @Binding var selectedTask: ToDoTaskDTO?
    @Binding var showingPomodoro: Bool
    
    @State private var showingTaskForm = false
    @State private var taskToEdit: ToDoTaskDTO?
    @State private var selectedFilter: ToDoTask.TaskFilter = .all
    @State private var selectedCategory: Category?
    @State private var store: ClarityModelActor?
    @State private var refreshID = UUID()
    
    @Query(sort: \Category.name, order: .forward) private var allCategories: [Category]
    
    @Query(filter: #Predicate<ToDoTask> { !$0.completed }, sort: \ToDoTask.due, order: .forward) private var allTasks: [ToDoTask]
    
    private var filteredTasks: [ToDoTask] {
        let tasks = ToDoTask.focusFilter(in: allTasks)

        // 4) Now filter tasks based on due date, allowed categories, and selectedCategory (if any)
        let filtered = tasks.filter { task in
            let dueDateMatches = selectedFilter.matches(task: task)
            let taskCategories = task.categories ?? []

            // If a specific category is selected, task must include it
            let matchesSelectedCategory: Bool = {
                guard let selectedCategory, let selectedName = selectedCategory.name else { return true }
                return taskCategories.contains { $0.name == selectedName }
            }()

            return dueDateMatches && matchesSelectedCategory
        }
        
        // #TODO: Change level back to verbose once sync issue sorted
        LogManager.shared.log.verbose("Total tasks: \(allTasks.count), Filtered: \(filtered.count)")
        #if INTERNAL
        // MARK: Duplicate task logging
        logDuplicateTasks(in: filtered)
        #endif
        
        return filtered
    }

    var body: some View {
        List(filteredTasks) { task in
            TaskRowView(
                task: task,
                onEdit: { editTask(ToDoTaskDTO(from: task)) },
                onDelete: { deleteTask(ToDoTaskDTO(from: task)) },
                onComplete: { completeTask(ToDoTaskDTO(from: task)) },
                onStartTimer: { startTimer(for: ToDoTaskDTO(from: task)) }
            )
        }
        .id(refreshID)
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
        .onReceive(NotificationCenter.default.publisher(for: .focusSettingsChanged)) { _ in
            // Force a view refresh so filtering re-evaluates with new focus settings
            LogManager.shared.log.debug("Refreshing View: focusSettingsChanged")
            refreshID = UUID()
        }
        .onReceive(NotificationCenter.default.publisher(for: .pomodoroCompleted)) { notification in
            if PomodoroService.shared.startedDevice == .watchOS { return }
            print("📱 Finishing task on Phone")
            guard let store = store else { return }
            if let id = notification.userInfo?["taskID"] as? UUID {
                Task { try? await store.completeTask(id) }
            } else if let id = PomodoroService.shared.toDoTask?.uuid {
                Task { try? await store.completeTask(id) }
            }
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
    
    
    
    private func editTask(_ task: ToDoTaskDTO) {
        LogManager.shared.log.debug("Editing \(task.name)")
        taskToEdit = task
        showingTaskForm = true
    }
    
    private func deleteTask(_ task: ToDoTaskDTO) {
        LogManager.shared.log.debug("Deleting: (\(task.name))")
        Task {
            try? await store?.deleteTask(task.id!)
        }
    }
    
    private func completeTask(_ task: ToDoTaskDTO) {
        LogManager.shared.log.debug("Attempting to complete task for ID: \(task.id.debugDescription) : \(task.name)")
        guard let store = store else { return }
        let id = task.uuid

        Task {
            try? await store.completeTask(id)
        }
        
    }
    
    private func startTimer(for task: ToDoTaskDTO) {
        LogManager.shared.log.debug("Starting Pomodoro for \(task.name)")
        selectedTask = task
        withAnimation(.easeInOut(duration: 0.3)) {
            // showingPomodoro = true
            PomodoroService.shared.startPomodoro(for: task, container: context.container, device: .iPhone)
        }
    }
    
    private func requestNotificationPermission() async {
        do {
            _ = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
        } catch {
            LogManager.shared.log.error("Error requesting notification permission: \(error)")
        }
    }
    
    // Logs detailed information for any duplicate (by UUID) incomplete tasks in the provided collection
    private func logDuplicateTasks(in tasks: [ToDoTask]) {
        // Group only tasks that have a UUID
        var groups: [UUID: [ToDoTask]] = [:]
        for task in tasks {
            guard let id = task.uuid else { continue }
            groups[id, default: []].append(task)
        }
        // Find duplicates
        for (uuid, group) in groups where group.count > 1 {
            LogManager.shared.log.error("Duplicate tasks detected for UUID=\(uuid.uuidString); count=\(group.count)")
            for (index, t) in group.enumerated() {
                let dump = dumpTask(t)
                LogManager.shared.log.error("  [\(index)] \n\(dump)")
            }
        }
    }
    
    // Produce a comprehensive, human-readable dump of a ToDoTask record
    private func dumpTask(_ t: ToDoTask) -> String {
        var lines: [String] = []
        // Known fields first (stable ordering)
        lines.append("id: \(t.id.debugDescription)")
        lines.append("uuid: \(t.uuid?.uuidString ?? "nil")")
        lines.append("name: \(t.name ?? "nil")")
        lines.append("due: \(t.due.formatted())")
        lines.append("completed: \(t.completed)")
        lines.append("completedAt: \(t.completedAt?.formatted() ?? "nil")")
        lines.append("pomodoro: \(t.pomodoro.description)")
        lines.append("pomodoroTime: \(t.pomodoroTime.description)")
        lines.append("repeating: \(t.repeating?.description ?? "nil")")
        lines.append("recurrenceInterval: \(String(describing: t.recurrenceInterval))")
        lines.append("customRecurrenceDays: \(t.customRecurrenceDays.description)")
        lines.append("everySpecificDayDay: \(t.everySpecificDayDay?.description ?? "nil")")
        let categoryNames = (t.categories ?? []).compactMap { $0.name }.joined(separator: ", ")
        lines.append("categories.count: \(t.categories?.count ?? 0)")
        lines.append("categories: [\(categoryNames)]")

        // Reflect any additional properties (best-effort; avoids duplicates by skipping known keys)
        let knownKeys: Set<String> = [
            "id","uuid","name","due","completed","completedAt","pomodoro","pomodoroTime","repeating","recurrenceInterval","customRecurrenceDays","everySpecificDayDay","categories"
        ]
        let mirror = Mirror(reflecting: t)
        for child in mirror.children {
            if let key = child.label, !knownKeys.contains(key) {
                lines.append("\(key): \(String(describing: child.value))")
            }
        }
        return lines.joined(separator: "\n")
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


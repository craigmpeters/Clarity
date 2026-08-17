import ActivityKit
import SwiftData
import SwiftUI
import UserNotifications

struct TaskIndexView: View {
    @Environment(\.modelContext) private var context
    @Binding var selectedTask: ToDoTaskDTO?

    @State private var viewModel = TaskIndexViewModel()
    @State private var swipeOptions: TaskSwipeAndTapOptions?

    @Query(sort: \Category.name, order: .forward) private var allCategories: [Category]
    @Query(filter: #Predicate<ToDoTask> { !$0.completed }, sort: \ToDoTask.due, order: .forward) private var allTasks: [ToDoTask]
    @Query private var taskSwipeAndTapOptions: [TaskSwipeAndTapOptions]

    var body: some View {
        let filtered = viewModel.filteredTasks(from: allTasks)
        List(filtered) { task in
            TaskRowView(
                task: task,
                swipeOptions: swipeOptions ?? TaskSwipeAndTapOptions(),
                onEdit: { viewModel.editTask(ToDoTaskDTO(from: task)) },
                onDelete: { viewModel.deleteTask(ToDoTaskDTO(from: task)) },
                onComplete: { viewModel.completeTask(ToDoTaskDTO(from: task)) },
                onStartTimer: { viewModel.startTimer(for: ToDoTaskDTO(from: task), selectedTask: &selectedTask, container: context.container) }
            )
        }
        .id(viewModel.refreshTrigger)
        .accessibilityIdentifier("task-list")
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                FilterMenuView(
                    selectedFilter: $viewModel.selectedFilter,
                    selectedCategory: $viewModel.selectedCategory,
                    allCategories: allCategories
                )
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { viewModel.showingTaskForm = true }) {
                    Image(systemName: "plus")
                        .foregroundStyle(.blue)
                }
                .accessibilityIdentifier("task-add")
            }
        }
        .task {
            await requestNotificationPermission()
            viewModel.setStore(await StoreRegistry.shared.store(for: context.container))
            swipeOptions = resolveSwipeOptions()
        }
        .onReceive(NotificationCenter.default.publisher(for: .focusSettingsChanged)) { _ in
            LogManager.shared.log.debug("Refreshing View: focusSettingsChanged")
            viewModel.triggerRefresh()
        }
        .onReceive(NotificationCenter.default.publisher(for: .pomodoroCompleted)) { notification in
            if PomodoroService.shared.startedDevice == .watchOS { return }
            LogManager.shared.log.debug("Finishing task on phone from Pomodoro completion")
            viewModel.completeTaskFromPomodoroNotification(userInfo: notification.userInfo)
        }
        .sheet(isPresented: $viewModel.showingTaskForm, onDismiss: {
            viewModel.taskToEdit = nil
        }) {
            TaskFormView(task: viewModel.taskToEdit)
        }
    }

    private func requestNotificationPermission() async {
        do {
            _ = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
        } catch {
            LogManager.shared.log.error("Error requesting notification permission: \(error)")
        }
    }

    private func resolveSwipeOptions() -> TaskSwipeAndTapOptions {
        if let existing = taskSwipeAndTapOptions.first {
            return existing
        }
        let defaults = TaskSwipeAndTapOptions()
        context.insert(defaults)
        try? context.save()
        return defaults
    }
}

#if DEBUG
#Preview {
    @Previewable @State var selectedTask: ToDoTaskDTO? = nil
    TaskIndexView(
        selectedTask: .constant(selectedTask)
    )
    .modelContainer(PreviewData.shared.previewContainer)
}
#endif

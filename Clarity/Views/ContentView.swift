import SwiftData
import SwiftUI
import os

struct ContentView: View {
  @Environment(\.modelContext) private var context
  @EnvironmentObject var appState: AppState
  @Environment(CompanionService.self) private var companion
  @StateObject private var pomodoroService: PomodoroService = .shared
  @State private var selectedTask: ToDoTaskDTO? = nil
  @State private var showingFirstRun = !UserDefaults.hasCompletedOnboarding

  @State private var store: ClarityModelActor? = nil
  @State private var undoableTask: (uuid: UUID, name: String)? = nil
  @State private var showUndoToast = false

  var body: some View {
    TabView(selection: $appState.selectedTab) {
      NavigationStack {
        TaskIndexView(
          selectedTask: $selectedTask
        )
        .navigationTitle("Tasks")
      }
      .tabItem {
        Image(systemName: "list.bullet")
        Text("Tasks")
      }
      .tag(0)
      .accessibilityIdentifier("tab-tasks")

      NavigationStack {
        HabitsIndexView()
          .navigationTitle("Habits")
      }
      .tabItem {
        Image(systemName: "checklist.checked")
        Text("Habits")
      }
      .tag(1)
      .accessibilityIdentifier("tab-habits")

      PomodoroView()
        .tabItem {
          Image(systemName: "timer")
          Text("Focus")
        }
        .tag(2)
        .accessibilityIdentifier("tab-focus")
        .badge(pomodoroService.isActive ? 1 : 0)

      NavigationStack {
        StatsView()
          .navigationTitle("Statistics")
      }
      .tabItem {
        Image(systemName: "chart.bar")
        Text("Stats")
      }
      .tag(3)
      .accessibilityIdentifier("tab-stats")

      NavigationStack {
        SettingsView()
          .navigationTitle("Settings")
      }
      .tabItem {
        Image(systemName: "gear")
        Text("Settings")
      }
      .tag(4)
      .accessibilityIdentifier("tab-settings")
    }
    .sheet(isPresented: $showingFirstRun) {
      FirstRunView()
        .interactiveDismissDisabled()
    }
    .onOpenURL { url in
      LogManager.shared.log.debug("Got URL: \(url)")
      if url.scheme == "clarityapp" {
        LogManager.shared.log.debug("clarityapp")
        if url.host == "timer",
          let taskId = url.pathComponents.last
        {
          LogManager.shared.log.debug("timer")
          Task {
            LogManager.shared.log.info("Recieved Start Pomodoro for \(taskId)")
          }
        }
      }
    }
    .task {
      if store == nil {
        let bg = await StoreRegistry.shared.store(for: context.container)
        store = bg
        companion.setStore(bg)
        await companion.loadContext(from: bg)
        companion.loadChatHistory()
        // Fire appLaunch only after context is ready, so Otto has task data.
        // A small delay keeps the first FoundationModels call off the launch critical path.
        Task { @MainActor in
          try? await Task.sleep(for: .seconds(2))
          companion.trigger(.appLaunch)
        }
      }
    }
    .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification))
    { _ in
      // Guard against the notification that fires immediately on first launch
      // (store will be nil then; the .task block handles that case)
      guard store != nil else { return }
      Task { await companion.refreshContext() }
    }
    .onChange(of: companion.startTaskRequest) { _, uuid in
      guard let uuid, let store else { return }
      companion.startTaskRequest = nil
      Task {
        guard let task = try? await store.fetchTaskByUuid(uuid) else { return }
        PomodoroService.shared.startPomodoro(
          for: task, container: context.container, device: .iPhone)
        appState.selectedTab = 2
      }
    }
    .overlay {
      CompanionOverlayView(companion: companion)
        .ignoresSafeArea()
    }
    .toast(
      isPresented: $showUndoToast,
      message: undoableTask.map { "\($0.name) completed" } ?? "Task completed",
      actionLabel: "Undo",
      action: {
        if let task = undoableTask {
          uncompleteTask(task.uuid, name: task.name)
        }
      }
    )
    .onReceive(NotificationCenter.default.publisher(for: .pomodoroCompleted)) { notification in
      guard let uuid = notification.userInfo?[Notification.Name.taskUUIDKey] as? UUID else {
        return
      }
      Task {
        await presentUndoToast(for: uuid)
      }
    }
  }

  private func presentUndoToast(for uuid: UUID) async {
    guard let store else { return }
    let name = await (try? store.fetchTaskNameByUuid(uuid)) ?? "Task"
    await MainActor.run {
      undoableTask = (uuid: uuid, name: name)
      showUndoToast = true
    }
  }

  private func uncompleteTask(_ uuid: UUID, name: String) {
    guard let store else { return }
    Task {
      do {
        try await store.uncompleteTask(uuid)
        LogManager.shared.log.info("Successfully uncompleted task \(uuid.uuidString)")
        await companion.refreshContext()
        companion.trigger(.taskUncompleted(taskName: name))
      } catch {
        LogManager.shared.log.error("Failed to uncomplete task: \(error.localizedDescription)")
      }
    }
  }
}

#if DEBUG
  #Preview("Demo View") {
    ContentView()
      .modelContainer(PreviewData.shared.previewContainer)
      .environmentObject(AppState())
      .environment(CompanionService.shared)
  }

#endif

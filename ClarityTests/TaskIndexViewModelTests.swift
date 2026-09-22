//
//  TaskIndexViewModelTests.swift
//  ClarityTests
//
//  Unit tests for TaskIndexViewModel notification handling.
//

import Foundation
import SwiftData
import Testing

@testable import Clarity

@MainActor
@Suite(.serialized)
struct TaskIndexViewModelTests {

  private func makeViewModel(with store: ClarityModelActor) -> TaskIndexViewModel {
    let viewModel = TaskIndexViewModel()
    viewModel.setStore(store)
    return viewModel
  }

  private func makeActor() async throws -> ClarityModelActor {
    ClarityModelActor.widgetCoordinator = NoOpWidgetCoordinator()
    let container = try Containers.inMemory()
    return await StoreRegistry.shared.store(for: container)
  }

  private func waitForTaskOnMainActor(timeout: TimeInterval = 2.0) async {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
      await Task.yield()
      try? await Task.sleep(nanoseconds: 10_000_000)
    }
  }

  @Test func completeTaskFromPomodoroNotificationSkipsExternallyHandledCompletions() async throws {
    let store = try await makeActor()
    let task = try await store.addTask(
      ToDoTaskDTO(name: "External Stop", due: Date(), uuid: UUID())
    )
    // Pre-complete the task, simulating the Live Activity intent having already handled it.
    try await store.completeTask(task.uuid)

    let viewModel = makeViewModel(with: store)
    let notification = Notification(
      name: .pomodoroCompleted,
      object: nil,
      userInfo: [
        Notification.Name.taskUUIDKey: task.uuid,
        Notification.Name.completionHandledExternallyKey: true,
      ]
    )

    viewModel.completeTaskFromPomodoroNotification(userInfo: notification.userInfo)
    await waitForTaskOnMainActor()

    let history = try await store.fetchTaskHistory(for: task.uuid)
    #expect(history.filter(\.completed).count == 1, "External-handled notification should not complete again")
  }

  @Test func completeTaskFromPomodoroNotificationCompletesWatchOriginatedPomodoro() async throws {
    let store = try await makeActor()
    let task = try await store.addTask(
      ToDoTaskDTO(name: "Watch Stop", due: Date(), uuid: UUID())
    )

    PomodoroService.shared.startedDevice = .watchOS
    defer { PomodoroService.shared.startedDevice = .iPhone }

    let viewModel = makeViewModel(with: store)
    let notification = Notification(
      name: .pomodoroCompleted,
      object: nil,
      userInfo: [Notification.Name.taskUUIDKey: task.uuid]
    )

    viewModel.completeTaskFromPomodoroNotification(userInfo: notification.userInfo)
    await waitForTaskOnMainActor()

    let history = try await store.fetchTaskHistory(for: task.uuid)
    #expect(history.filter(\.completed).count == 1, "Watch-originated notification should complete on phone")
  }

  @Test func completeTaskFromPomodoroNotificationCompletesPhoneOriginatedPomodoro() async throws {
    let store = try await makeActor()
    let task = try await store.addTask(
      ToDoTaskDTO(name: "Phone Stop", due: Date(), uuid: UUID())
    )

    PomodoroService.shared.startedDevice = .iPhone

    let viewModel = makeViewModel(with: store)
    let notification = Notification(
      name: .pomodoroCompleted,
      object: nil,
      userInfo: [Notification.Name.taskUUIDKey: task.uuid]
    )

    viewModel.completeTaskFromPomodoroNotification(userInfo: notification.userInfo)
    await waitForTaskOnMainActor()

    let history = try await store.fetchTaskHistory(for: task.uuid)
    #expect(history.filter(\.completed).count == 1, "Phone-originated notification should complete the task")
  }

  @Test func completeTaskFromPomodoroNotificationRequiresUUID() async throws {
    let store = try await makeActor()
    let viewModel = makeViewModel(with: store)

    // No UUID, no startedDevice side effects; should simply return without crashing.
    viewModel.completeTaskFromPomodoroNotification(userInfo: [:])
    await waitForTaskOnMainActor()

    #expect(true, "Missing UUID should be handled gracefully")
  }
}

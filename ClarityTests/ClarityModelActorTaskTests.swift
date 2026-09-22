//
//  ClarityModelActorTaskTests.swift
//  ClarityTests
//
//  Unit tests for ClarityModelActor task CRUD and completion APIs.
//

import Foundation
import SwiftData
import Testing

@testable import Clarity

@Suite(.serialized)
struct ClarityModelActorTaskTests {

  private func makeActor() async throws -> ClarityModelActor {
    ClarityModelActor.widgetCoordinator = NoOpWidgetCoordinator()
    let container = try Containers.inMemory()
    return ClarityModelActor(modelContainer: container)
  }

  private func makeTaskDTO(name: String = "Test") -> ToDoTaskDTO {
    ToDoTaskDTO(name: name, due: Date(), uuid: UUID())
  }

  @Test func completeTaskThenFetchNameByUuid() async throws {
    let actor = try await makeActor()
    let task = try await actor.addTask(makeTaskDTO(name: "Review Docs"))
    try await actor.completeTask(task.uuid)

    let name = try await actor.fetchTaskNameByUuid(task.uuid)
    #expect(name == "Review Docs")
  }

  @Test func completeTaskOnRepeatingTaskStagesExactlyOneOccurrence() async throws {
    let actor = try await makeActor()
    let task = try await actor.addTask(
      ToDoTaskDTO(
        name: "Daily Standup",
        repeating: true,
        recurrenceInterval: .daily,
        due: Date(),
        uuid: UUID()
      )
    )

    // First completion should mark the original complete and stage one next occurrence.
    // The cross-process double-completion bug for repeating tasks is guarded at the
    // notification layer (completionHandledExternallyKey), because the staged next
    // occurrence intentionally shares the same UUID as the base task.
    try await actor.completeTask(task.uuid)

    let history = try await actor.fetchTaskHistory(for: task.uuid)
    let completed = history.filter { $0.completed }
    let incomplete = history.filter { !$0.completed }
    #expect(completed.count == 1, "Expected exactly one completed task, found \(completed.count)")
    #expect(incomplete.count == 1, "Expected exactly one staged next occurrence, found \(incomplete.count)")
  }

  @Test func completeTaskIsIdempotentWhenNoIncompleteTaskMatches() async throws {
    let actor = try await makeActor()
    let task = try await actor.addTask(makeTaskDTO(name: "One-shot"))
    let firstExpectation = TaskNotificationExpectation(name: .taskCompleted)

    try await actor.completeTask(task.uuid)

    let historyBefore = try await actor.fetchTaskHistory(for: task.uuid)
    #expect(historyBefore.count == 1)
    await firstExpectation.wait(timeout: 2.0)

    // Second call finds no matching incomplete task and should be a no-op, including
    // not posting another .taskCompleted notification.
    let secondExpectation = TaskNotificationExpectation(name: .taskCompleted)
    try await actor.completeTask(task.uuid)

    let historyAfter = try await actor.fetchTaskHistory(for: task.uuid)
    #expect(historyAfter.count == historyBefore.count)
    await secondExpectation.wait(timeout: 0.5, expectFired: false)
  }

  // MARK: - Notification Expectation Helpers

  /// An actor-based helper that waits for a single notification to fire without
  /// pulling in XCTest expectation machinery.
  private final class TaskNotificationExpectation: @unchecked Sendable {
    private var continuation: CheckedContinuation<Void, Never>?
    private var didFire = false
    private let lock = NSLock()
    private var token: (any NSObjectProtocol)?

    init(name: Notification.Name) {
      token = NotificationCenter.default.addObserver(
        forName: name,
        object: nil,
        queue: nil
      ) { [weak self] _ in
        self?.fulfill()
      }
    }

    deinit {
      if let token {
        NotificationCenter.default.removeObserver(token)
      }
    }

    private func fulfill() {
      lock.withLock {
        didFire = true
        continuation?.resume()
        continuation = nil
      }
    }

    func wait(timeout: TimeInterval, expectFired: Bool = true) async {
      if expectFired {
        await withTimeout(seconds: timeout) { [weak self] in
          await self?.waitForFire()
        }
        let fired = lock.withLock { didFire }
        #expect(fired, "Expected notification to fire")
      } else {
        try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
        let fired = lock.withLock { didFire }
        #expect(fired == false, "Expected notification not to fire")
      }
    }

    private func waitForFire() async {
      let alreadyFired = lock.withLock { didFire }
      if alreadyFired { return }
      await withCheckedContinuation { continuation in
        lock.withLock { self.continuation = continuation }
      }
    }

    private func withTimeout(seconds: TimeInterval, operation: @escaping @Sendable () async -> Void) async {
      await withTaskGroup(of: Void.self) { group in
        group.addTask { await operation() }
        group.addTask {
          try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
        }
        await group.next()
        group.cancelAll()
      }
    }
  }

  @Test func uncompleteTaskRestoresIncompleteState() async throws {
    let actor = try await makeActor()
    let task = try await actor.addTask(makeTaskDTO(name: "Write Tests"))
    try await actor.completeTask(task.uuid)
    #expect(try await actor.fetchTaskByUuid(task.uuid) == nil)

    try await actor.uncompleteTask(task.uuid)
    let restored = try await actor.fetchTaskByUuid(task.uuid)
    #expect(restored?.name == "Write Tests")
    #expect(restored?.completed == false)
  }
}

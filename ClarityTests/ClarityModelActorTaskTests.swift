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

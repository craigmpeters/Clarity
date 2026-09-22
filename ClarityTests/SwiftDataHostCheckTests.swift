//
//  SwiftDataHostCheckTests.swift
//  ClarityTests
//
//  Created by OpenCode on 09/08/2026.
//

import Foundation
import SwiftData
import Testing
@testable import Clarity

struct SwiftDataHostCheckTests {

    @Test func inMemoryContainerCanInsertAndFetchCategory() async throws {
        ClarityModelActor.widgetCoordinator = NoOpWidgetCoordinator()
        let container = try Containers.inMemory()
        let actor = ClarityModelActor(modelContainer: container)

        let dto = try await actor.addCategory(
            CategoryDTO(id: nil, name: "Work", color: .Red, weeklyTarget: 5, uuid: UUID())
        )

        #expect(dto.name == "Work")
        let fetched = try await actor.getCategories()
        #expect(fetched.count == 1)
        #expect(fetched.first?.name == "Work")
    }

    @Test func inMemoryContainerCanInsertAndFetchHabit() async throws {
        ClarityModelActor.widgetCoordinator = NoOpWidgetCoordinator()
        let container = try Containers.inMemory()
        let actor = ClarityModelActor(modelContainer: container)

        let dto = HabitDTO(name: "Walk", dailyTarget: 1.0)
        let added = try await actor.addHabit(dto)

        #expect(added.name == "Walk")
        let fetched = try await actor.fetchHabits()
        #expect(fetched.count == 1)
    }
}

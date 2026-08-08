//
//  HabitEntity.swift
//  Clarity
//
//  Created by Craig Peters on 08/08/2026.
//

import AppIntents
import Foundation
import XCGLogger

struct HabitEntity: AppEntity, Identifiable, Sendable {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Habit"
    static let defaultQuery = HabitQuery()

    var id: String
    var name: String
    var unitLabel: String?
    var dailyTarget: Double
    var incrementStep: Double

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

struct HabitQuery: EntityQuery, Sendable {
    func entities(for identifiers: [String]) async throws -> [HabitEntity] {
        try await allEntities().filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [HabitEntity] {
        try await allEntities()
    }

    func allEntities() async throws -> [HabitEntity] {
        let habits = WidgetFileCoordinator.shared.readHabits()
        return habits.map { HabitEntity(
            id: $0.uuid.uuidString,
            name: $0.name,
            unitLabel: $0.unitLabel,
            dailyTarget: $0.dailyTarget,
            incrementStep: $0.incrementStep
        ) }
    }
}

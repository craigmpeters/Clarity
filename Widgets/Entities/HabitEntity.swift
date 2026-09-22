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
    var healthKitIdentifier: String?

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

struct HabitQuery: EntityQuery, EntityStringQuery, Sendable {
    func entities(for identifiers: [String]) async throws -> [HabitEntity] {
        try await allEntities().filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [HabitEntity] {
        try await allEntities()
    }

    func entities(matching string: String) async throws -> [HabitEntity] {
        let all = try await allEntities()
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return all }
        return all.filter {
            $0.name.localizedCaseInsensitiveContains(trimmed) ||
            ($0.unitLabel?.localizedCaseInsensitiveContains(trimmed) ?? false)
        }
    }

    func allEntities() async throws -> [HabitEntity] {
        let habits = try WidgetFileCoordinator.shared.readHabits()
        return habits.filter { !$0.isArchived }.map { HabitEntity(
            id: $0.uuid.uuidString,
            name: $0.name,
            unitLabel: $0.unitLabel,
            dailyTarget: $0.dailyTarget,
            incrementStep: $0.incrementStep,
            healthKitIdentifier: $0.healthKitIdentifier
        ) }
    }
}

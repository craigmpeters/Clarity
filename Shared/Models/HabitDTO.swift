//
//  HabitDTO.swift
//  Clarity
//
//  Created by Craig Peters on 08/08/2026.
//

import Foundation
import SwiftData
import os

struct HabitDTO: Sendable, Hashable, Codable {
    var id: PersistentIdentifier?
    var uuid: UUID
    var name: String
    var created: Date
    var unitLabel: String?
    var dailyTarget: Double
    var incrementStep: Double
    var weeklyFrequency: Int
    var streakFreezes: Int
    var freezesSpent: Int
    var healthKitIdentifier: String?
    var isArchived: Bool
    var artworkFilename: String?
    var categories: [CategoryDTO]

    nonisolated init(
        id: PersistentIdentifier? = nil,
        uuid: UUID = UUID(),
        name: String,
        created: Date = Date(),
        unitLabel: String? = nil,
        dailyTarget: Double,
        incrementStep: Double = 1.0,
        weeklyFrequency: Int = 7,
        streakFreezes: Int = 0,
        freezesSpent: Int = 0,
        healthKitIdentifier: String? = nil,
        isArchived: Bool = false,
        artworkFilename: String? = nil,
        categories: [CategoryDTO] = []
    ) {
        self.id = id
        self.uuid = uuid
        self.name = name
        self.created = created
        self.unitLabel = unitLabel
        self.dailyTarget = dailyTarget
        self.incrementStep = incrementStep
        self.weeklyFrequency = weeklyFrequency
        self.streakFreezes = streakFreezes
        self.freezesSpent = freezesSpent
        self.healthKitIdentifier = healthKitIdentifier
        self.isArchived = isArchived
        self.artworkFilename = artworkFilename
        self.categories = categories
    }

    var isTargetReached: Bool { currentAmount >= dailyTarget }
    var progressFraction: Double { min(currentAmount / max(dailyTarget, 1), 1.0) }
    var periodDescription: String { HabitFormatter.progressDescription(amount: currentAmount, target: dailyTarget, unit: unitLabel, healthKitIdentifier: healthKitIdentifier) }

    // Mutable value used for inline editing in the UI, not persisted in the DTO itself.
    var currentAmount: Double = 0
    var completed: Bool = false
    var completedAt: Date?
    var freezeUsed: Bool = false
    var source: String? = nil
    var periodStart: Date = Date()
    var currentStreak: Int = 0
    /// Rolling 7-day completion window: index 0 is 6 days ago, index 6 is today.
    var weekCompletionBitmap: [Bool] = []
}

extension HabitDTO {
    enum CodingKeys: String, CodingKey {
        case uuid, name, created, unitLabel, dailyTarget, incrementStep
        case weeklyFrequency, streakFreezes, freezesSpent, healthKitIdentifier
        case isArchived, artworkFilename, categories
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let uuid = try container.decodeIfPresent(UUID.self, forKey: .uuid) ?? UUID()
        let name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        let created = try container.decodeIfPresent(Date.self, forKey: .created) ?? Date()
        let unitLabel = try container.decodeIfPresent(String.self, forKey: .unitLabel)
        let dailyTarget = try container.decodeIfPresent(Double.self, forKey: .dailyTarget) ?? 1
        let incrementStep = try container.decodeIfPresent(Double.self, forKey: .incrementStep) ?? 1
        let weeklyFrequency = try container.decodeIfPresent(Int.self, forKey: .weeklyFrequency) ?? 7
        let streakFreezes = try container.decodeIfPresent(Int.self, forKey: .streakFreezes) ?? 0
        let freezesSpent = try container.decodeIfPresent(Int.self, forKey: .freezesSpent) ?? 0
        let healthKitIdentifier = try container.decodeIfPresent(String.self, forKey: .healthKitIdentifier)
        let isArchived = try container.decodeIfPresent(Bool.self, forKey: .isArchived) ?? false
        let artworkFilename = try container.decodeIfPresent(String.self, forKey: .artworkFilename)
        let categories = try container.decodeIfPresent([CategoryDTO].self, forKey: .categories) ?? []
        self.init(
            uuid: uuid,
            name: name,
            created: created,
            unitLabel: unitLabel,
            dailyTarget: dailyTarget,
            incrementStep: incrementStep,
            weeklyFrequency: weeklyFrequency,
            streakFreezes: streakFreezes,
            freezesSpent: freezesSpent,
            healthKitIdentifier: healthKitIdentifier,
            isArchived: isArchived,
            artworkFilename: artworkFilename,
            categories: categories
        )
    }

    nonisolated init(from model: Habit) {
        self.init(
            id: model.persistentModelID,
            uuid: model.uuid,
            name: model.name,
            created: model.created,
            unitLabel: model.unitLabel,
            dailyTarget: model.dailyTarget,
            incrementStep: model.incrementStep,
            weeklyFrequency: model.weeklyFrequency,
            streakFreezes: model.streakFreezes,
            freezesSpent: model.freezesSpent,
            healthKitIdentifier: model.healthKitIdentifier,
            isArchived: model.isArchived,
            artworkFilename: model.artworkFilename,
            categories: (model.categories ?? []).map(CategoryDTO.init(from:))
        )
    }
}

struct HabitOccurrenceDTO: Sendable, Hashable, Codable {
    var id: PersistentIdentifier?
    var uuid: UUID
    var habitUUID: UUID
    var periodStart: Date
    var currentAmount: Double
    var completed: Bool
    var completedAt: Date?
    var freezeUsed: Bool
    var source: String?

    nonisolated init(
        id: PersistentIdentifier? = nil,
        uuid: UUID = UUID(),
        habitUUID: UUID,
        periodStart: Date,
        currentAmount: Double = 0,
        completed: Bool = false,
        completedAt: Date? = nil,
        freezeUsed: Bool = false,
        source: String? = nil
    ) {
        self.id = id
        self.uuid = uuid
        self.habitUUID = habitUUID
        self.periodStart = periodStart
        self.currentAmount = currentAmount
        self.completed = completed
        self.completedAt = completedAt
        self.freezeUsed = freezeUsed
        self.source = source
    }
}

extension HabitOccurrenceDTO {
    enum CodingKeys: String, CodingKey {
        case uuid, habitUUID, periodStart, currentAmount, completed, completedAt, freezeUsed, source
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let uuid = try container.decodeIfPresent(UUID.self, forKey: .uuid) ?? UUID()
        let habitUUID = try container.decodeIfPresent(UUID.self, forKey: .habitUUID) ?? UUID()
        let periodStart = try container.decodeIfPresent(Date.self, forKey: .periodStart) ?? Date()
        let currentAmount = try container.decodeIfPresent(Double.self, forKey: .currentAmount) ?? 0
        let completed = try container.decodeIfPresent(Bool.self, forKey: .completed) ?? false
        let completedAt = try container.decodeIfPresent(Date.self, forKey: .completedAt)
        let freezeUsed = try container.decodeIfPresent(Bool.self, forKey: .freezeUsed) ?? false
        let source = try container.decodeIfPresent(String.self, forKey: .source)
        self.init(
            uuid: uuid,
            habitUUID: habitUUID,
            periodStart: periodStart,
            currentAmount: currentAmount,
            completed: completed,
            completedAt: completedAt,
            freezeUsed: freezeUsed,
            source: source
        )
    }

    nonisolated init?(from model: HabitOccurrence) {
        guard let habitUUID = model.habit?.uuid else {
            Logger(subsystem: "me.craigpeters.Clarity", category: "HabitDTO").error("HabitOccurrence missing habit UUID; skipping DTO conversion")
            return nil
        }
        self.init(
            id: model.persistentModelID,
            uuid: model.uuid,
            habitUUID: habitUUID,
            periodStart: model.periodStart,
            currentAmount: model.currentAmount,
            completed: model.completed,
            completedAt: model.completedAt,
            freezeUsed: model.freezeUsed,
            source: model.source
        )
    }
}

extension HabitDTO: Identifiable {}

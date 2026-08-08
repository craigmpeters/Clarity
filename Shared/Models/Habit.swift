//
//  Habit.swift
//  Clarity
//
//  Created by Craig Peters on 08/08/2026.
//

import Foundation
import SwiftData

/// A habit is a recurring daily goal with a weekly frequency target.
/// It is intentionally separate from `ToDoTask` and accumulates progress per day.
@Model
class Habit {
    var uuid: UUID = UUID()
    var name: String = ""
    var created: Date = Date()
    var unitLabel: String?
    var dailyTarget: Double = 1
    var incrementStep: Double = 1
    var weeklyFrequency: Int = 7
    var streakFreezes: Int = 0
    var freezesSpent: Int = 0
    var healthKitIdentifier: String?
    var isArchived: Bool = false
    var artworkFilename: String?

    @Relationship(deleteRule: .cascade, inverse: \HabitOccurrence.habit) var occurrences: [HabitOccurrence]?
    @Relationship var categories: [Category]?

    init(
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
        categories: [Category] = []
    ) {
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
}

/// A single day's occurrence of a habit.

@Model
class HabitOccurrence {
    var uuid: UUID = UUID()
    @Relationship var habit: Habit?
    var periodStart: Date = Date()
    var currentAmount: Double = 0
    var completed: Bool = false
    var completedAt: Date?
    var freezeUsed: Bool = false
    var source: String? = nil

    init(
        uuid: UUID = UUID(),
        habit: Habit? = nil,
        periodStart: Date,
        currentAmount: Double = 0,
        completed: Bool = false,
        completedAt: Date? = nil,
        freezeUsed: Bool = false,
        source: String? = nil
    ) {
        self.uuid = uuid
        self.habit = habit
        self.periodStart = periodStart
        self.currentAmount = currentAmount
        self.completed = completed
        self.completedAt = completedAt
        self.freezeUsed = freezeUsed
        self.source = source
    }
}

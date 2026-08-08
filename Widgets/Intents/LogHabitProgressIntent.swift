//
//  LogHabitProgressIntent.swift
//  Clarity
//
//  Created by Craig Peters on 08/08/2026.
//

import AppIntents
import Foundation
import XCGLogger

struct LogHabitProgressIntent: AppIntent {
    static let title: LocalizedStringResource = "Log Habit Progress"
    static let description = IntentDescription("Log progress toward a habit")
    static let openAppWhenRun = false

    @Parameter(title: "Habit")
    var habit: HabitEntity

    @Parameter(title: "Amount")
    var amount: Double?

    init() {}

    init(habit: HabitEntity, amount: Double? = nil) {
        self.habit = habit
        self.amount = amount
    }

    static var parameterSummary: some ParameterSummary {
        Summary("Log progress on a habit")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let uuid = UUID(uuidString: habit.id) else {
            return .result(dialog: IntentDialog(LocalizedStringResource("Invalid habit identifier.")))
        }

        do {
            let store = try await ClarityServices.store()
            let occurrence = try await store.logHabitProgress(uuid, amount: amount)
            let current = occurrence.currentAmount
            let target = habit.dailyTarget
            let dialog: IntentDialog
            if let unit = habit.unitLabel, !unit.isEmpty {
                dialog = IntentDialog(LocalizedStringResource("Logged — \(current, format: .number) of \(target, format: .number) \(unit)."))
            } else {
                dialog = IntentDialog(LocalizedStringResource("Logged — \(current, format: .number) of \(target, format: .number)."))
            }
            return .result(dialog: dialog)
        } catch {
            LogManager.shared.log.error("LogHabitProgressIntent error: \(error)")
            return .result(dialog: IntentDialog(LocalizedStringResource("Couldn’t log habit progress.")))
        }
    }
}

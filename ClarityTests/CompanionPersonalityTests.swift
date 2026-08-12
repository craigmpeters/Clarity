//
//  CompanionPersonalityTests.swift
//  ClarityTests
//
//  Created by OpenCode on 09/08/2026.
//

import Foundation
import Testing
@testable import Clarity

struct CompanionPersonalityTests {

    private let otto = OttoPersonality()
    private let goose = GoosePersonality()
    private let allPersonalities: [any CompanionPersonality] = [OttoPersonality(), GoosePersonality()]

    @Test func allPersonalitiesHaveUniqueIds() {
        let ids = allPersonalities.map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    @Test func allPersonalitiesHaveSupportedEmotions() {
        for personality in allPersonalities {
            #expect(personality.supportedEmotions.isEmpty == false)
        }
    }

    @Test func personalityMetadata() {
        #expect(otto.id == "otto")
        #expect(otto.displayName == "Otto")
        #expect(otto.defaultCompanionName == "Otto")
        #expect(otto.requiresPremium == false)
        #expect(otto.assetPrefix == "otter")
        #expect(otto.fallbackEmoji == "🦦")

        #expect(goose.id == "goose")
        #expect(goose.displayName == "Silly Goose")
        #expect(goose.defaultCompanionName == "Gerald")
        #expect(goose.requiresPremium == true)
        #expect(goose.assetPrefix == "goose")
        #expect(goose.fallbackEmoji == "🪿")
    }

    @Test func systemInstructionsContainNameAndContext() {
        for personality in allPersonalities {
            let instructions = personality.systemInstructions(name: "CustomName", contextBlock: "CONTEXT_BLOCK")
            #expect(instructions.contains("CustomName"))
            #expect(instructions.contains("CONTEXT_BLOCK"))
        }
    }

    @Test func promptForAllTriggersContainsAssociatedValues() {
        let triggers: [CompanionTrigger] = [
            .appLaunch,
            .taskCompleted(taskName: "Read Docs"),
            .taskUncompleted(taskName: "Read Docs"),
            .pomodoroCompleted(taskName: "Focus"),
            .streakMilestone(days: 30),
            .lowMoodDetected(averageValence: 0.3),
            .habitSuggestion(categories: ["A", "B", "C", "D", "E"], completedCount: 7),
            .habitCompleted(habitName: "Walk", state: .milestone(streak: 7))
        ]

        for trigger in triggers {
            let prompt = otto.prompt(for: trigger)
            #expect(prompt.isEmpty == false)

            switch trigger {
            case .taskCompleted(let name), .taskUncompleted(let name), .pomodoroCompleted(let name):
                #expect(prompt.contains(name))
            case .streakMilestone(let days):
                #expect(prompt.contains("\(days)"))
            case .lowMoodDetected(let avg):
                #expect(prompt.contains(String(format: "%.1f", avg)))
            case .habitSuggestion(let categories, let completedCount):
                #expect(prompt.contains(categories.prefix(3).joined(separator: ", ")))
                #expect(prompt.contains("\(completedCount)"))
            case .habitCompleted(let habitName, let state):
                #expect(prompt.contains(habitName))
                #expect(prompt.contains("\(state.streak)"))
            default:
                break
            }
        }
    }

    @Test func promptForSuggestionTruncatesCategoriesToThree() {
        let prompt = otto.prompt(for: .habitSuggestion(categories: ["1", "2", "3", "4", "5"], completedCount: 1))
        #expect(prompt.contains("1, 2, 3"))
        #expect(prompt.contains("4") == false)
        #expect(prompt.contains("5") == false)
    }

    @Test func promptSuggestionInstructionMatchesAllowance() {
        #expect(otto.prompt(for: .taskCompleted(taskName: "T")).contains("You may suggest one task"))
        #expect(otto.prompt(for: .pomodoroCompleted(taskName: "T")).contains("You may suggest one task"))
        #expect(otto.prompt(for: .appLaunch).contains("Do not set suggestedTaskName"))
        #expect(otto.prompt(for: .taskUncompleted(taskName: "T")).contains("Do not set suggestedTaskName"))
    }

    @Test func fallbackMessageEmotionsForOtto() {
        #expect(otto.fallbackMessage(for: .appLaunch).emotion == .encouraging)
        #expect(otto.fallbackMessage(for: .taskCompleted(taskName: "T")).emotion == .happy)
        #expect(otto.fallbackMessage(for: .taskUncompleted(taskName: "T")).emotion == .loving)
        #expect(otto.fallbackMessage(for: .pomodoroCompleted(taskName: "T")).emotion == .happy)
        #expect(otto.fallbackMessage(for: .streakMilestone(days: 7)).emotion == .encouraging)
        #expect(otto.fallbackMessage(for: .lowMoodDetected(averageValence: 0.0)).emotion == .caring)
        #expect(otto.fallbackMessage(for: .habitSuggestion(categories: [], completedCount: 0)).emotion == .determined)
    }

    @Test func fallbackMessageEmotionsForGoose() {
        #expect(goose.fallbackMessage(for: .appLaunch).emotion == .encouraging)
        #expect(goose.fallbackMessage(for: .taskCompleted(taskName: "T")).emotion == .silly)
        #expect(goose.fallbackMessage(for: .taskUncompleted(taskName: "T")).emotion == .silly)
        #expect(goose.fallbackMessage(for: .pomodoroCompleted(taskName: "T")).emotion == .happy)
        #expect(goose.fallbackMessage(for: .streakMilestone(days: 7)).emotion == .silly)
        #expect(goose.fallbackMessage(for: .lowMoodDetected(averageValence: 0.0)).emotion == .caring)
        #expect(goose.fallbackMessage(for: .habitSuggestion(categories: [], completedCount: 0)).emotion == .determined)
    }

    @Test func errorFallbackWithTaskIncludesNameAndSuggestedTask() {
        let summary = CompanionTaskContext.TaskSummary(
            uuid: UUID(),
            name: "Overdue Task",
            dueDate: Date(),
            pomodoroMinutes: 25,
            lastCompletedAt: nil,
            lastMoodValence: nil,
            categories: []
        )

        let ottoFallback = otto.errorFallback(overdueTask: summary)
        #expect(ottoFallback.text.contains("Overdue Task"))
        #expect(ottoFallback.suggestedTask?.name == "Overdue Task")

        let gooseFallback = goose.errorFallback(overdueTask: summary)
        #expect(gooseFallback.text.contains("Overdue Task"))
        #expect(gooseFallback.suggestedTask?.name == "Overdue Task")
    }

    @Test func errorFallbackWithoutTaskIsGeneric() {
        let ottoFallback = otto.errorFallback(overdueTask: nil)
        #expect(ottoFallback.suggestedTask == nil)
        #expect(ottoFallback.text.isEmpty == false)

        let gooseFallback = goose.errorFallback(overdueTask: nil)
        #expect(gooseFallback.suggestedTask == nil)
        #expect(gooseFallback.text.isEmpty == false)
    }

    @Test func chatFallbackIsNonEmpty() {
        #expect(otto.chatFallback.text.isEmpty == false)
        #expect(goose.chatFallback.text.isEmpty == false)
    }
}

private extension HabitStreakState {
    var streak: Int {
        switch self {
        case .continued(let streak), .milestone(let streak), .saved(let streak), .restarted(let streak):
            return streak
        }
    }
}

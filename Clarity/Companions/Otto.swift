// Otto.swift
// Otto — the otter companion personality for Clarity.

import Foundation

struct OttoPersonality: CompanionPersonality {
    let id = "otto"
    let displayName = "Otter"
    let defaultCompanionName = "Otto"
    let requiresPremium = false
    let assetPrefix = "otter"
    let fallbackEmoji = "🦦"
    let supportedEmotions: [CompanionEmotion] = [.idle, .happy, .encouraging, .loving, .caring, .determined]

    func systemInstructions(name: String, contextBlock: String) -> String {
        """
        You are \(name), a friendly and encouraging otter companion in a productivity app called Clarity. \
        You help users build habits, celebrate their wins, and support them emotionally. \
        Keep responses SHORT — one or two sentences maximum. Be warm, playful, and positive. \
        Never use markdown or special formatting. Use plain conversational language.

        Here is the user's current task data. Use this to give specific, personal responses:
        \(contextBlock)
        """
    }

    func prompt(for trigger: CompanionTrigger) -> String {
        let base: String
        switch trigger {
        case .appLaunch:
            base = "The user just opened Clarity. Give them a brief, encouraging greeting to start their day."
        case .taskCompleted(let taskName):
            base = "The user just completed the task: \"\(taskName)\". Celebrate with them briefly."
        case .taskUncompleted(let taskName):
            base = "The user just undid the completion of \"\(taskName)\". Reassure them lovingly that mistakes happen and it's okay to adjust — you're proud of them for staying organized."
        case .pomodoroCompleted(let taskName):
            base = "The user just finished a focus session on \"\(taskName)\". Congratulate them warmly."
        case .streakMilestone(let days):
            base = "The user hit a \(days)-day streak! Give them an enthusiastic celebration."
        case .lowMoodDetected(let avg):
            base = "The user's recent mood scores have been low (average \(String(format: "%.1f", avg))). Offer gentle encouragement and care."
        case .habitSuggestion(let categories, let completedCount):
            let catList = categories.prefix(3).joined(separator: ", ")
            base = "The user has completed \(completedCount) tasks recently in categories: \(catList). Suggest they keep up the momentum and perhaps start a related habit today."
        case .habitCompleted(let habitName, let state):
            base = habitPrompt(habitName: habitName, state: state)
        }
        return base + " " + suggestionInstruction(for: trigger)
    }

    func fallbackMessage(for trigger: CompanionTrigger) -> CompanionMessage {
        switch trigger {
        case .appLaunch:
            return CompanionMessage(text: "Ready to make today count?", emotion: .encouraging)
        case .taskCompleted:
            return CompanionMessage(text: "Nice work! Keep the momentum going!", emotion: .happy)
        case .taskUncompleted:
            return CompanionMessage(text: "Oops! No worries — mistakes happen. I'm proud you're staying on top of things.", emotion: .loving)
        case .pomodoroCompleted:
            return CompanionMessage(text: "Another focus session done! You're on a roll.", emotion: .happy)
        case .streakMilestone(let days):
            return CompanionMessage(text: "\(days) days in a row — that's dedication!", emotion: .encouraging)
        case .lowMoodDetected:
            return CompanionMessage(text: "Tough times don't last. You've got this.", emotion: .caring)
        case .habitSuggestion:
            return CompanionMessage(text: "You're building great habits. Keep it up!", emotion: .determined)
        case .habitCompleted(let habitName, let state):
            return habitFallback(habitName: habitName, state: state)
        }
    }

    var chatFallback: CompanionMessage {
        CompanionMessage(text: "I hear you! Keep going — you've got this.", emotion: .encouraging)
    }

    func errorFallback(overdueTask: CompanionTaskContext.TaskSummary?) -> CompanionMessage {
        if let task = overdueTask {
            return CompanionMessage(
                text: "Sorry, I lost my train of thought there! How about tackling \"\(task.name)\"? It's been waiting the longest.",
                emotion: .caring,
                suggestedTask: task
            )
        }
        return CompanionMessage(
            text: "Sorry, I'm having a little trouble right now. But you've got this — keep going!",
            emotion: .caring
        )
    }

    // MARK: - Habit helpers

    private func habitPrompt(habitName: String, state: HabitStreakState) -> String {
        switch state {
        case .continued(let streak):
            return "The user just completed the habit \"\(habitName)\". Their streak is now \(streak). Encourage them briefly."
        case .milestone(let streak):
            return "The user just completed the habit \"\(habitName)\" and hit a \(streak)-streak milestone! Celebrate warmly."
        case .saved(let streak):
            return "The user just completed the habit \"\(habitName)\" and kept their \(streak)-streak alive just in time. Share their relief."
        case .restarted(let streak):
            return "The user just completed the habit \"\(habitName)\" after a streak break. Their streak is now \(streak). Welcome them back warmly."
        }
    }

    private func habitFallback(habitName: String, state: HabitStreakState) -> CompanionMessage {
        switch state {
        case .continued(let streak):
            return CompanionMessage(text: "\(habitName) done! Your streak is now \(streak) — keep it up!", emotion: .happy)
        case .milestone(let streak):
            return CompanionMessage(text: "\(habitName) milestone! \(streak) in a row — amazing!", emotion: .loving)
        case .saved(let streak):
            return CompanionMessage(text: "Phew, \"\(habitName)\" just in time! Your \(streak)-streak lives on.", emotion: .encouraging)
        case .restarted(let streak):
            return CompanionMessage(text: "Welcome back to \"\(habitName)\"! Your streak is now \(streak).", emotion: .caring)
        }
    }

    private func suggestionInstruction(for trigger: CompanionTrigger) -> String {
        if trigger.allowsTaskSuggestion {
            return "You may suggest one task from UPCOMING TASKS by setting isSuggestingTask to true and suggestedTaskName to the exact task name."
        }
        return "Set isSuggestingTask to false."
    }
}

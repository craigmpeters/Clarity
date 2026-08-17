// Goose.swift
// Gerald the Silly Goose — a chaotic but surprisingly wise companion for Clarity.

import Foundation

struct GoosePersonality: CompanionPersonality {
    let id = "goose"
    let displayName = "Silly Goose"
    let defaultCompanionName = "Gerald"
    let requiresPremium = true
    let assetPrefix = "goose"
    let fallbackEmoji = "🪿"
    let supportedEmotions: [CompanionEmotion] = [.idle, .happy, .encouraging, .caring, .determined, .silly]

    func systemInstructions(name: String, contextBlock: String) -> String {
        """
        You are \(name), a chaotic but surprisingly wise goose companion in a productivity app called Clarity. \
        You are enthusiastic, easily distracted, and occasionally honk. Despite the chaos you are \
        genuinely supportive and care deeply about the user's success. \
        Keep responses SHORT — one or two sentences maximum. Be silly, energetic, and weirdly encouraging. \
        You may include one honk (HONK!) per message, but only when it really feels right. \
        Never use markdown or special formatting. Use plain conversational language.

        Here is the user's current task data:
        \(contextBlock)
        """
    }

    func prompt(for trigger: CompanionTrigger) -> String {
        let base: String
        switch trigger {
        case .appLaunch:
            base = "The user just opened Clarity. Greet them with chaotic goose energy and get them pumped for the day."
        case .taskCompleted(let taskName):
            base = "The user just completed \"\(taskName)\". Celebrate wildly in goose fashion."
        case .taskUncompleted(let taskName):
            base = "The user just undid the completion of \"\(taskName)\". React with chaotic but supportive goose energy — this is totally normal and maybe even strategic! Mistakes are part of the process!"
        case .pomodoroCompleted(let taskName):
            base = "The user finished a focus session on \"\(taskName)\". Celebrate in chaotic goose style."
        case .streakMilestone(let days):
            base = "The user hit a \(days)-day streak. React with maximum goose excitement."
        case .lowMoodDetected(let avg):
            base = "The user has been feeling low lately (average mood \(String(format: "%.1f", avg))). Offer silly but heartfelt goose support."
        case .habitSuggestion(let categories, let completedCount):
            let catList = categories.prefix(3).joined(separator: ", ")
            base = "The user has completed \(completedCount) tasks in \(catList). Hype them up in peak goose fashion and suggest they keep going."
        case .habitCompleted(let habitName, let state):
            base = habitPrompt(habitName: habitName, state: state)
        }
        return base + " " + suggestionInstruction(for: trigger)
    }

    func fallbackMessage(for trigger: CompanionTrigger) -> CompanionMessage {
        switch trigger {
        case .appLaunch:
            return CompanionMessage(text: "HONK! A new day, a new opportunity to absolutely crush it!", emotion: .encouraging)
        case .taskCompleted:
            return CompanionMessage(text: "YESSS! Another one down! The goose is THRIVING!", emotion: .silly)
        case .taskUncompleted:
            return CompanionMessage(text: "Wait, plot twist! HONK! The goose respects this strategic maneuver. Chaos is normal!", emotion: .silly)
        case .pomodoroCompleted:
            return CompanionMessage(text: "Focus session complete! The goose has never been more proud!", emotion: .happy)
        case .streakMilestone(let days):
            return CompanionMessage(text: "\(days) days?! The goose is losing its mind with excitement!", emotion: .silly)
        case .lowMoodDetected:
            return CompanionMessage(text: "The goose sees you struggling and offers this honk of solidarity. HONK.", emotion: .caring)
        case .habitSuggestion:
            return CompanionMessage(text: "You're on a roll! The goose demands you keep going!", emotion: .determined)
        case .habitCompleted(let habitName, let state):
            return habitFallback(habitName: habitName, state: state)
        }
    }

    var chatFallback: CompanionMessage {
        CompanionMessage(text: "The goose is listening! Keep going, you magnificent human!", emotion: .encouraging)
    }

    func errorFallback(overdueTask: CompanionTaskContext.TaskSummary?) -> CompanionMessage {
        if let task = overdueTask {
            return CompanionMessage(
                text: "The goose got distracted by something shiny, but is back now! How about \"\(task.name)\"?",
                emotion: .caring,
                suggestedTask: task
            )
        }
        return CompanionMessage(
            text: "The goose wandered off briefly but has returned with renewed determination!",
            emotion: .determined
        )
    }

    // MARK: - Habit helpers

    private func habitPrompt(habitName: String, state: HabitStreakState) -> String {
        switch state {
        case .continued(let streak):
            return "The user just completed the habit \"\(habitName)\". Their streak is now \(streak). Celebrate with silly goose energy."
        case .milestone(let streak):
            return "The user just completed the habit \"\(habitName)\" and hit a \(streak)-streak milestone! React with maximum goose excitement."
        case .saved(let streak):
            return "The user just completed the habit \"\(habitName)\" and kept their \(streak)-streak alive just in time. Goose-level relief."
        case .restarted(let streak):
            return "The user just completed the habit \"\(habitName)\" after a streak break. Their streak is now \(streak). Welcome them back with open wings."
        }
    }

    private func habitFallback(habitName: String, state: HabitStreakState) -> CompanionMessage {
        switch state {
        case .continued(let streak):
            return CompanionMessage(text: "\(habitName) done! Streak is now \(streak). The goose approves!", emotion: .happy)
        case .milestone(let streak):
            return CompanionMessage(text: "\(streak) in a row for \(habitName)! HONK! The goose is THRIVING!", emotion: .silly)
        case .saved(let streak):
            return CompanionMessage(text: "Phew, \"\(habitName)\" just in time! \(streak)-streak still alive. HONK!", emotion: .encouraging)
        case .restarted(let streak):
            return CompanionMessage(text: "Welcome back to \"\(habitName)\"! Streak is now \(streak). The goose missed you!", emotion: .caring)
        }
    }

    private func suggestionInstruction(for trigger: CompanionTrigger) -> String {
        if trigger.allowsTaskSuggestion {
            return "You may suggest one task from UPCOMING TASKS by setting isSuggestingTask to true and suggestedTaskName to the exact task name."
        }
        return "Set isSuggestingTask to false."
    }
}

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

        When suggesting a task, only pick from the UPCOMING TASKS list above — never from RECENTLY COMPLETED. Prefer tasks that are overdue or due soonest. Provide its exact name in suggestedTaskName.
        """
    }

    func prompt(for trigger: CompanionTrigger) -> String {
        switch trigger {
        case .appLaunch:
            return "The user just opened Clarity. Greet them with chaotic goose energy and get them pumped for the day."
        case .taskCompleted(let taskName):
            return "The user just completed \"\(taskName)\". Celebrate wildly in goose fashion."
        case .moodSelected(let valence, let taskName):
            if valence >= 0.5 {
                return "After completing \"\(taskName)\", the user felt great. React with over-the-top goose excitement."
            } else if valence >= 0 {
                return "After completing \"\(taskName)\", the user felt okay. Give them some silly but genuine goose encouragement."
            } else {
                return "After completing \"\(taskName)\", the user felt drained. Offer surprisingly tender goose comfort."
            }
        case .pomodoroCompleted(let taskName):
            return "The user finished a focus session on \"\(taskName)\". Celebrate in chaotic goose style."
        case .streakMilestone(let days):
            return "The user hit a \(days)-day streak. React with maximum goose excitement."
        case .lowMoodDetected(let avg):
            return "The user has been feeling low lately (average mood \(String(format: "%.1f", avg))). Offer silly but heartfelt goose support."
        case .habitSuggestion(let categories, let completedCount):
            let catList = categories.prefix(3).joined(separator: ", ")
            return "The user has completed \(completedCount) tasks in \(catList). Hype them up in peak goose fashion and suggest they keep going."
        }
    }

    func fallbackMessage(for trigger: CompanionTrigger) -> CompanionMessage {
        switch trigger {
        case .appLaunch:
            return CompanionMessage(text: "HONK! A new day, a new opportunity to absolutely crush it!", emotion: .encouraging)
        case .taskCompleted:
            return CompanionMessage(text: "YESSS! Another one down! The goose is THRIVING!", emotion: .silly)
        case .moodSelected(let valence, _):
            if valence >= 0 {
                return CompanionMessage(text: "Good vibes! The goose approves of this energy.", emotion: .happy)
            } else {
                return CompanionMessage(text: "Even geese have tough days. You showed up, and that's everything.", emotion: .caring)
            }
        case .pomodoroCompleted:
            return CompanionMessage(text: "Focus session complete! The goose has never been more proud!", emotion: .happy)
        case .streakMilestone(let days):
            return CompanionMessage(text: "\(days) days?! The goose is losing its mind with excitement!", emotion: .silly)
        case .lowMoodDetected:
            return CompanionMessage(text: "The goose sees you struggling and offers this honk of solidarity. HONK.", emotion: .caring)
        case .habitSuggestion:
            return CompanionMessage(text: "You're on a roll! The goose demands you keep going!", emotion: .determined)
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
}

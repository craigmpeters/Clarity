// CompanionService.swift
// On-device AI companion (otter) using Foundation Models

import SwiftUI
#if canImport(FoundationModels)
import FoundationModels
#endif

private nonisolated(unsafe) let log = LogManager.shared.log

// MARK: - Model availability

enum CompanionModelAvailability: Sendable, Equatable {
    case available
    case deviceNotEligible
    case appleIntelligenceNotEnabled
    case modelNotReady
    case unsupported   // FoundationModels not importable (older OS)

    var isAvailable: Bool { self == .available }

    var userFacingReason: String {
        switch self {
        case .available:
            return ""
        case .deviceNotEligible:
            return "This device doesn't support Apple Intelligence. \(UserDefaults.standard.string(forKey: "me.craigpeters.clarity.companionName") ?? "Otto") will use preset responses instead."
        case .appleIntelligenceNotEnabled:
            return "Apple Intelligence is turned off. Enable it in Settings → Apple Intelligence & Siri to unlock personalised responses."
        case .modelNotReady:
            return "The Apple Intelligence model is still downloading. \(UserDefaults.standard.string(forKey: "me.craigpeters.clarity.companionName") ?? "Otto") will use preset responses until it's ready."
        case .unsupported:
            return "Apple Intelligence requires iOS 26 or later. \(UserDefaults.standard.string(forKey: "me.craigpeters.clarity.companionName") ?? "Otto") will use preset responses instead."
        }
    }
}

// MARK: - Emotion State

enum CompanionEmotion: String, Sendable {
    case idle
    case thinking
    case happy
    case encouraging
    case loving
    case caring
    case determined
}

// MARK: - Trigger

enum CompanionTrigger: Sendable {
    case appLaunch
    case taskCompleted(taskName: String)
    case moodSelected(valence: Double, taskName: String)
    case pomodoroCompleted(taskName: String)
    case streakMilestone(days: Int)
    case lowMoodDetected(averageValence: Double)
    case habitSuggestion(categories: [String], completedCount: Int)
}

// MARK: - Message

struct CompanionMessage: Sendable {
    let text: String
    let emotion: CompanionEmotion
    var suggestedTask: CompanionTaskContext.TaskSummary? = nil
}

// MARK: - Guided generation output

#if canImport(FoundationModels)
@available(iOS 26.0, *)
@Generable(description: "A companion message from the otter")
struct CompanionOutput {
    @Guide(description: "One or two warm, conversational sentences. No markdown or special formatting.")
    var text: String

    @Guide(description: "The emotional tone. Must be exactly one of: idle, happy, encouraging, loving, caring, determined")
    var emotion: String

    @Guide(description: "If your message suggests the user work on a specific task, provide its exact name here. Otherwise leave this empty.")
    var suggestedTaskName: String
}
#endif

// MARK: - Task context snapshot

/// A compact, Sendable snapshot of the user's task data passed to the LLM as context.
struct CompanionTaskContext: Sendable {
    struct TaskSummary: Sendable {
        let uuid: UUID
        let name: String
        let dueDate: Date
        let pomodoroMinutes: Int
        let lastCompletedAt: Date?
        let lastMoodValence: Double?   // -1.0 to +1.0, nil if never logged
        let categories: [String]
    }

    let dueTasks: [TaskSummary]        // incomplete tasks, capped at 10
    let recentlyCompleted: [TaskSummary] // last 5 completed tasks
    let loadedAt: Date

    static let empty = CompanionTaskContext(dueTasks: [], recentlyCompleted: [], loadedAt: .distantPast)

    /// Human-readable summary injected into the system instructions.
    var instructionsBlock: String {
        guard !dueTasks.isEmpty || !recentlyCompleted.isEmpty else {
            return "The user has no tasks recorded yet."
        }

        var lines: [String] = []

        if !dueTasks.isEmpty {
            lines.append("UPCOMING TASKS (up to 10):")
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .abbreviated
            for t in dueTasks {
                let due = formatter.localizedString(for: t.dueDate, relativeTo: loadedAt)
                let mins = t.pomodoroMinutes
                var line = "- \"\(t.name)\" due \(due), focus time \(mins) min"
                if !t.categories.isEmpty {
                    line += " [\(t.categories.joined(separator: ", "))]"
                }
                if let mood = t.lastMoodValence {
                    let feel = mood >= 0.5 ? "great" : mood >= 0 ? "okay" : "drained"
                    if let last = t.lastCompletedAt {
                        let when = formatter.localizedString(for: last, relativeTo: loadedAt)
                        line += " — last done \(when), user felt \(feel)"
                    }
                }
                lines.append(line)
            }
        }

        if !recentlyCompleted.isEmpty {
            lines.append("RECENTLY COMPLETED:")
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .abbreviated
            for t in recentlyCompleted {
                var line = "- \"\(t.name)\""
                if let at = t.lastCompletedAt {
                    line += " completed \(formatter.localizedString(for: at, relativeTo: loadedAt))"
                }
                if let mood = t.lastMoodValence {
                    let feel = mood >= 0.5 ? "great" : mood >= 0 ? "okay" : "drained"
                    line += ", felt \(feel) (\(String(format: "%.1f", mood)))"
                }
                lines.append(line)
            }
        }

        return lines.joined(separator: "\n")
    }
}

// MARK: - Service

@MainActor
@Observable
final class CompanionService {

    static let shared = CompanionService()

    var currentMessage: CompanionMessage? = nil
    var isVisible: Bool = false
    var isGenerating: Bool = false
    var modelAvailability: CompanionModelAvailability = .unsupported
    var startTaskRequest: UUID? = nil

    // Opaque storage for LanguageModelSession (iOS 26+ only)
    private var _session: Any? = nil

    // Live task context — updated by call sites before triggering
    private var taskContext: CompanionTaskContext = .empty

    // Retained store reference so chat sheet can refresh context without prop-drilling
    private var modelStore: ClarityModelActor? = nil

    private init() {
        checkModelAvailability()
    }

    private func checkModelAvailability() {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available:
                modelAvailability = .available
                log.info("checkModelAvailability: Apple Intelligence available")
            case .unavailable(.deviceNotEligible):
                modelAvailability = .deviceNotEligible
                log.warning("checkModelAvailability: device not eligible for Apple Intelligence")
            case .unavailable(.appleIntelligenceNotEnabled):
                modelAvailability = .appleIntelligenceNotEnabled
                log.warning("checkModelAvailability: Apple Intelligence not enabled")
            case .unavailable(.modelNotReady):
                modelAvailability = .modelNotReady
                log.warning("checkModelAvailability: model not ready (still downloading)")
            case .unavailable(let other):
                modelAvailability = .modelNotReady
                log.warning("checkModelAvailability: unavailable for unknown reason — \(String(describing: other))")
            }
        } else {
            modelAvailability = .unsupported
            log.warning("checkModelAvailability: iOS 26 not available")
        }
        #else
        modelAvailability = .unsupported
        log.warning("checkModelAvailability: FoundationModels not importable")
        #endif
    }

    // MARK: - Store registration

    /// Register the SwiftData actor once (called from ContentView after creation).
    func setStore(_ store: ClarityModelActor) {
        modelStore = store
    }

    /// Refresh context using the previously registered store.
    func refreshContext() async {
        guard let store = modelStore else {
            log.warning("refreshContext: no store registered yet, skipping")
            return
        }
        await loadContext(from: store)
    }

    // MARK: - Context loading

    /// Call this from any actor that has a ClarityModelActor before triggering or chatting.
    func loadContext(from store: ClarityModelActor) async {
        log.debug("loadContext: fetching tasks")
        do {
            let incomplete = try await store.fetchTasks(filter: .all)
            let completed = try await store.fetchCompletedTasks()
            log.debug("loadContext: \(incomplete.count) incomplete, \(completed.count) completed tasks")

            let now = Date()

            // Build a name → last completed/mood lookup from completed tasks
            // (multiple completions of the same recurring task — keep most recent)
            var completionByName: [String: ToDoTaskDTO] = [:]
            for task in completed.sorted(by: { ($0.completedAt ?? .distantPast) < ($1.completedAt ?? .distantPast) }) {
                completionByName[task.name] = task
            }

            let dueSummaries = incomplete
                .filter { !$0.completed }
                .sorted { $0.due < $1.due }
                .prefix(10)
                .map { task -> CompanionTaskContext.TaskSummary in
                    let prev = completionByName[task.name]
                    return CompanionTaskContext.TaskSummary(
                        uuid: task.uuid,
                        name: task.name,
                        dueDate: task.due,
                        pomodoroMinutes: Int(task.pomodoroTime / 60),
                        lastCompletedAt: prev?.completedAt,
                        lastMoodValence: prev?.completionMoodValence,
                        categories: task.categories.map(\.name)
                    )
                }

            let recentSummaries = completed
                .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
                .prefix(5)
                .map { task in
                    CompanionTaskContext.TaskSummary(
                        uuid: task.uuid,
                        name: task.name,
                        dueDate: task.due,
                        pomodoroMinutes: Int(task.pomodoroTime / 60),
                        lastCompletedAt: task.completedAt,
                        lastMoodValence: task.completionMoodValence,
                        categories: task.categories.map(\.name)
                    )
                }

            taskContext = CompanionTaskContext(
                dueTasks: Array(dueSummaries),
                recentlyCompleted: Array(recentSummaries),
                loadedAt: now
            )
            log.debug("loadContext: context built — \(self.taskContext.dueTasks.count) due, \(self.taskContext.recentlyCompleted.count) recent")

            // Invalidate the session so the next request picks up fresh instructions
            #if canImport(FoundationModels)
            if #available(iOS 26.0, *) {
                _session = nil
                log.debug("loadContext: session invalidated for fresh instructions")
            }
            #endif
        } catch {
            log.error("loadContext: failed to fetch tasks — \(error)")
        }
    }

    // MARK: - Session management

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    private var session: LanguageModelSession? {
        get { _session as? LanguageModelSession }
        set { _session = newValue }
    }

    /// Returns the current session, creating one lazily with up-to-date instructions.
    @available(iOS 26.0, *)
    private func currentSession() -> LanguageModelSession {
        if let existing = session { return existing }
        let instructions = buildInstructions()
        log.debug("currentSession: creating new session")
        log.debug("currentSession: instructions —\n\(instructions)")
        let newSession = LanguageModelSession(instructions: instructions)
        session = newSession
        return newSession
    }
    #endif

    // MARK: - Public trigger entry point

    private var companionEnabled: Bool {
        if UserDefaults.standard.object(forKey: "me.craigpeters.clarity.companionEnabled") == nil { return true }
        return UserDefaults.standard.bool(forKey: "me.craigpeters.clarity.companionEnabled")
    }

    private var companionName: String {
        UserDefaults.standard.string(forKey: "me.craigpeters.clarity.companionName") ?? "Otto"
    }

    func trigger(_ event: CompanionTrigger) {
        guard companionEnabled else {
            log.debug("trigger: companion disabled, skipping \(String(describing: event))")
            return
        }
        checkModelAvailability()
        log.info("trigger: \(String(describing: event)) — model availability: \(String(describing: modelAvailability))")

        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), modelAvailability.isAvailable {
            Task { await generate(prompt: buildPrompt(for: event), fallbackEvent: event) }
        } else {
            log.debug("trigger: model unavailable, using fallback")
            showFallback(for: event)
        }
        #else
        log.debug("trigger: FoundationModels not importable, using fallback")
        showFallback(for: event)
        #endif
    }

    /// Send a free-form message directly from the user to the otter.
    func chat(_ userMessage: String) {
        guard companionEnabled,
              !isGenerating,
              !userMessage.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        checkModelAvailability()
        log.info("chat: user message — \"\(userMessage)\" — model availability: \(String(describing: modelAvailability))")

        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), modelAvailability.isAvailable {
            Task { await generate(prompt: userMessage, fallbackEvent: nil) }
        } else {
            log.debug("chat: model unavailable, using fallback")
            showChatFallback()
        }
        #else
        log.debug("chat: FoundationModels not importable, using fallback")
        showChatFallback()
        #endif
    }

    // MARK: - Generation

    #if canImport(FoundationModels)
    /// Single generation path for both trigger events and free-form chat.
    /// Pass `fallbackEvent` for trigger-sourced calls so the right fallback message is shown on error.
    @available(iOS 26.0, *)
    private func generate(prompt: String, fallbackEvent: CompanionTrigger?) async {
        isGenerating = true
        defer { isGenerating = false }

        log.info("generate: prompt — \"\(prompt)\"")

        do {
            let response = try await currentSession().respond(to: prompt, generating: CompanionOutput.self)
            show(response.content)
        } catch let genError as LanguageModelSession.GenerationError {
            switch genError {
            case .assetsUnavailable:
                log.warning("generate: assets unavailable — marking modelNotReady")
                modelAvailability = .modelNotReady
                session = nil
                showErrorFallback()

            case .exceededContextWindowSize:
                // Reset to a fresh session and retry once — conversation history is small enough
                // that losing it is acceptable compared to silently failing.
                log.warning("generate: context window exceeded — resetting session and retrying")
                session = nil
                do {
                    let response = try await currentSession().respond(to: prompt, generating: CompanionOutput.self)
                    show(response.content)
                } catch {
                    log.error("generate: retry after context reset failed — \(error)")
                    showErrorFallback()
                }

            case .guardrailViolation:
                // Guardrail still possible even with guided generation — save feedback for Apple.
                log.warning("generate: guardrail triggered unexpectedly — saving feedback")
                let feedbackData = session?.logFeedbackAttachment(
                    sentiment: .negative,
                    issues: [
                        LanguageModelFeedback.Issue(
                            category: .triggeredGuardrailUnexpectedly,
                            explanation: "Guardrail triggered on a benign productivity companion prompt"
                        )
                    ]
                )
                saveFeedback(feedbackData)
                showErrorFallback()

            case .refusal(let refusal, _):
                let explanation = (try? await refusal.explanation)?.content
                log.warning("generate: model refused — \(explanation ?? "no explanation provided")")
                showErrorFallback()

            default:
                log.error("generate: generation error — \(genError)")
                showErrorFallback()
            }
        } catch {
            // Handles the simulator / early-download case where the error arrives as a generic NSError
            if isModelCatalogError(error) {
                log.warning("generate: model catalog unavailable — marking modelNotReady")
                modelAvailability = .modelNotReady
                session = nil
            } else {
                log.error("generate: failed — \(error)")
            }
            showErrorFallback()
        }
    }

    @available(iOS 26.0, *)
    private func saveFeedback(_ data: Data?) {
        guard let data else { return }
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let file = dir.appendingPathComponent("companion-feedback-\(Date().timeIntervalSince1970).jsonl")
        try? data.write(to: file)
        log.info("saveFeedback: written to \(file.path)")
    }

    @available(iOS 26.0, *)
    private func show(_ output: CompanionOutput) {
        let text = output.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let emotion = CompanionEmotion(rawValue: output.emotion) ?? .happy
        let suggested = taskContext.dueTasks.first {
            $0.name.localizedCaseInsensitiveCompare(output.suggestedTaskName) == .orderedSame
        }
        log.debug("generate: text=\"\(text)\" emotion=\(emotion.rawValue) suggestedTask=\(suggested?.name ?? "none")")
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            currentMessage = CompanionMessage(text: text.isEmpty ? output.text : text, emotion: emotion, suggestedTask: suggested)
            isVisible = true
        }
    }
    #endif

    // MARK: - Instructions builder

    private func buildInstructions() -> String {
        let contextBlock = taskContext.instructionsBlock
        return """
            You are \(companionName), a friendly and encouraging otter companion in a productivity app called Clarity. \
            You help users build habits, celebrate their wins, and support them emotionally. \
            Keep responses SHORT — one or two sentences maximum. Be warm, playful, and positive. \
            Never use markdown or special formatting. Use plain conversational language.

            Here is the user's current task data. Use this to give specific, personal responses:
            \(contextBlock)

            When suggesting a task, only pick from the UPCOMING TASKS list above — never from RECENTLY COMPLETED. Prefer tasks that are overdue or due soonest AND have a short focus time. Provide its exact name in suggestedTaskName.
            """
    }

    // MARK: - Prompt construction

    private func buildPrompt(for event: CompanionTrigger) -> String {
        switch event {
        case .appLaunch:
            return "The user just opened Clarity. Give them a brief, encouraging greeting to start their day."
        case .taskCompleted(let taskName):
            return "The user just completed the task: \"\(taskName)\". Celebrate with them briefly."
        case .moodSelected(let valence, let taskName):
            if valence >= 0.5 {
                return "After completing \"\(taskName)\", the user said they felt great (valence \(String(format: "%.1f", valence))). Respond positively."
            } else if valence >= 0 {
                return "After completing \"\(taskName)\", the user said they felt okay (valence \(String(format: "%.1f", valence))). Acknowledge neutrally and encourage."
            } else {
                return "After completing \"\(taskName)\", the user said they didn't feel good (valence \(String(format: "%.1f", valence))). Respond with empathy and gentle support."
            }
        case .pomodoroCompleted(let taskName):
            return "The user just finished a focus session on \"\(taskName)\". Congratulate them warmly."
        case .streakMilestone(let days):
            return "The user hit a \(days)-day streak! Give them an enthusiastic celebration."
        case .lowMoodDetected(let avg):
            return "The user's recent mood scores have been low (average \(String(format: "%.1f", avg))). Offer gentle encouragement and care."
        case .habitSuggestion(let categories, let completedCount):
            let catList = categories.prefix(3).joined(separator: ", ")
            return "The user has completed \(completedCount) tasks recently in categories: \(catList). Suggest they keep up the momentum and perhaps start a related habit today."
        }
    }

    // MARK: - Error classification

    /// Returns true for the "model catalog not downloaded" error Apple surfaces as a
    /// generic GenerationError Code=-1 wrapping ModelManagerError Code=1026, as well
    /// as the typed .assetsUnavailable case.
    private func isModelCatalogError(_ error: Error) -> Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            if let genError = error as? LanguageModelSession.GenerationError,
               case .assetsUnavailable = genError {
                return true
            }
        }
        #endif
        // Simulator / early-download case: wrapped as generic Code=-1
        let ns = error as NSError
        if ns.domain == "FoundationModels.LanguageModelSession.GenerationError", ns.code == -1 {
            return true
        }
        return false
    }

    // MARK: - Fallback (no LLM)

    /// Used when generation fails mid-request. Apologises and nudges the user toward their most overdue task.
    private func showErrorFallback() {
        let message: CompanionMessage
        if let overdue = taskContext.dueTasks.first {
            message = CompanionMessage(
                text: "Sorry, I lost my train of thought there! How about tackling \"\(overdue.name)\"? It's been waiting the longest.",
                emotion: .caring,
                suggestedTask: overdue
            )
        } else {
            message = CompanionMessage(
                text: "Sorry, I'm having a little trouble right now. But you've got this — keep going!",
                emotion: .caring
            )
        }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            currentMessage = message
            isVisible = true
        }
    }

    private func showFallbackOrChat(for event: CompanionTrigger?) {
        if let event {
            showFallback(for: event)
        } else {
            showChatFallback()
        }
    }

    private func showChatFallback() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            currentMessage = CompanionMessage(text: "I hear you! Keep going — you've got this.", emotion: .encouraging)
            isVisible = true
        }
    }

    private func showFallback(for event: CompanionTrigger) {
        let message: CompanionMessage
        switch event {
        case .appLaunch:
            message = CompanionMessage(text: "Ready to make today count?", emotion: .encouraging)
        case .taskCompleted:
            message = CompanionMessage(text: "Nice work! Keep the momentum going!", emotion: .happy)
        case .moodSelected(let valence, _):
            if valence >= 0 {
                message = CompanionMessage(text: "Great attitude — every session counts!", emotion: .loving)
            } else {
                message = CompanionMessage(text: "It's okay to have tough days. I'm proud of you for showing up.", emotion: .caring)
            }
        case .pomodoroCompleted:
            message = CompanionMessage(text: "Another focus session done! You're on a roll.", emotion: .happy)
        case .streakMilestone(let days):
            message = CompanionMessage(text: "\(days) days in a row — that's dedication!", emotion: .encouraging)
        case .lowMoodDetected:
            message = CompanionMessage(text: "Tough times don't last. You've got this.", emotion: .caring)
        case .habitSuggestion:
            message = CompanionMessage(text: "You're building great habits. Keep it up!", emotion: .determined)
        }

        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            currentMessage = message
            isVisible = true
        }
    }

    // MARK: - Reset

    func clearHistory() {
        _session = nil
        currentMessage = nil
        isVisible = false
        log.info("clearHistory: session and message cleared")
    }

    // MARK: - Dismiss

    func dismiss() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            isVisible = false
        }
    }

    func requestStartTask(_ uuid: UUID) {
        startTaskRequest = uuid
    }
}

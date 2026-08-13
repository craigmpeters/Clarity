// CompanionService.swift
// On-device AI companion using Foundation Models

import SwiftUI
#if canImport(FoundationModels)
import FoundationModels
#endif

private nonisolated(unsafe) let log = LogManager.shared.log

// MARK: - Companion Personality Protocol

protocol CompanionPersonality: Sendable {
    var id: String { get }
    var displayName: String { get }
    var defaultCompanionName: String { get }
    var requiresPremium: Bool { get }
    var assetPrefix: String { get }
    var fallbackEmoji: String { get }
    var supportedEmotions: [CompanionEmotion] { get }

    func systemInstructions(name: String, contextBlock: String) -> String
    func prompt(for trigger: CompanionTrigger) -> String
    func fallbackMessage(for trigger: CompanionTrigger) -> CompanionMessage
    var chatFallback: CompanionMessage { get }
    func errorFallback(overdueTask: CompanionTaskContext.TaskSummary?) -> CompanionMessage
}

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
            return "This device doesn't support Apple Intelligence. Your companion will use preset responses instead."
        case .appleIntelligenceNotEnabled:
            return "Apple Intelligence is turned off. Enable it in Settings → Apple Intelligence & Siri to unlock personalised responses."
        case .modelNotReady:
            return "The Apple Intelligence model is still downloading. Your companion will use preset responses until it's ready."
        case .unsupported:
            return "Apple Intelligence requires iOS 26 or later. Your companion will use preset responses instead."
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
    case silly
}

// MARK: - Trigger

enum CompanionTrigger: Sendable {
    case appLaunch
    case taskCompleted(taskName: String)
    case taskUncompleted(taskName: String)
    case pomodoroCompleted(taskName: String)
    case streakMilestone(days: Int)
    case lowMoodDetected(averageValence: Double)
    case habitSuggestion(categories: [String], completedCount: Int)
    case habitCompleted(habitName: String, state: HabitStreakState)
}

enum HabitStreakState: Sendable, Equatable {
    case continued(streak: Int)
    case milestone(streak: Int)
    case saved(streak: Int)
    case restarted(streak: Int)

    static func resolve(
        habit: HabitDTO,
        completedOccurrences: [HabitOccurrenceDTO],
        completedAt: Date
    ) -> HabitStreakState {
        let result = HabitStreakCalculator.streak(
            occurrences: completedOccurrences,
            frequency: habit.weeklyFrequency,
            freezes: habit.streakFreezes,
            referenceDate: completedAt
        )
        let streak = result.current
        let milestoneStreaks: Set<Int> = [7, 30, 100, 365]

        if milestoneStreaks.contains(streak) {
            return .milestone(streak: streak)
        }
        if result.atRisk {
            return .saved(streak: streak)
        }
        if streak == 0 && hasPriorActivity(occurrences: completedOccurrences, referenceDate: completedAt) {
            return .restarted(streak: streak)
        }
        return .continued(streak: streak)
    }

    private static func hasPriorActivity(occurrences: [HabitOccurrenceDTO], referenceDate: Date) -> Bool {
        let calendar = HabitStreakCalculator.streakCalendar()
        let currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: referenceDate)?.start ?? referenceDate
        return occurrences.contains { occurrence in
            occurrence.completed && occurrence.periodStart < currentWeekStart
        }
    }
}

extension CompanionTrigger {
    var allowsTaskSuggestion: Bool {
        switch self {
        case .taskCompleted, .pomodoroCompleted:
            return true
        default:
            return false
        }
    }
}

// MARK: - Message

struct CompanionMessage: Sendable {
    let text: String
    let emotion: CompanionEmotion
    var suggestedTask: CompanionTaskContext.TaskSummary? = nil
}

// MARK: - Output mapping

protocol CompanionOutputValues: Sendable {
    var text: String { get }
    var emotion: String { get }
    var suggestedTaskName: String { get }
}

#if canImport(FoundationModels)
@available(iOS 26.0, *)
extension CompanionOutput: CompanionOutputValues {}
#endif

enum CompanionOutputMapper {
    static func map(
        _ output: some CompanionOutputValues,
        trigger: CompanionTrigger?,
        supportedEmotions: [CompanionEmotion],
        dueTasks: [CompanionTaskContext.TaskSummary]
    ) -> CompanionMessage {
        let text = output.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let emotion = CompanionEmotion(rawValue: output.emotion)
            ?? supportedEmotions.first
            ?? .happy
        let suggested = trigger?.allowsTaskSuggestion == true
            ? dueTasks.first { $0.name.localizedCaseInsensitiveCompare(output.suggestedTaskName) == .orderedSame }
            : nil
        return CompanionMessage(text: text.isEmpty ? output.text : text, emotion: emotion, suggestedTask: suggested)
    }

    static func isDuplicate(
        _ message: CompanionMessage,
        lastChatHistoryMessage: ChatMessage?,
        trigger: CompanionTrigger?
    ) -> Bool {
        guard let last = lastChatHistoryMessage else { return false }
        guard last.sender == .companion else { return false }
        if trigger?.allowsTaskSuggestion == true { return false }
        return last.text == message.text
    }

    static func isModelCatalogError(_ error: Error) -> Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            if let genError = error as? LanguageModelSession.GenerationError,
               case .assetsUnavailable = genError {
                return true
            }
        }
        #endif
        let ns = error as NSError
        if ns.domain == "FoundationModels.LanguageModelSession.GenerationError", ns.code == -1 {
            return true
        }
        return false
    }
}

// MARK: - Guided generation output

#if canImport(FoundationModels)
@available(iOS 26.0, *)
@Generable(description: "A companion message")
struct CompanionOutput {
    @Guide(description: "One or two warm, conversational sentences. No markdown or special formatting.")
    var text: String

    @Guide(description: "The emotional tone as a single word. Use one of the valid emotion values listed in the system instructions.")
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

    struct HabitSummary: Sendable {
        let uuid: UUID
        let name: String
        let weeklyFrequency: Int
        let currentStreak: Int
        let doneToday: Bool
    }

    let dueTasks: [TaskSummary]        // incomplete tasks, capped at 10
    let recentlyCompleted: [TaskSummary] // last 5 completed tasks
    let habits: [HabitSummary]         // active habits with streak/today status
    let loadedAt: Date

    static let empty = CompanionTaskContext(dueTasks: [], recentlyCompleted: [], habits: [], loadedAt: .distantPast)

    /// Human-readable summary injected into the system instructions.
    var instructionsBlock: String {
        guard !dueTasks.isEmpty || !recentlyCompleted.isEmpty || !habits.isEmpty else {
            return "The user has no tasks or habits recorded yet."
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

        if !habits.isEmpty {
            lines.append("HABITS:")
            for h in habits {
                let frequency = h.weeklyFrequency == 7 ? "daily" : "\(h.weeklyFrequency) days/week"
                let done = h.doneToday ? "done today" : "not done today"
                lines.append("- \"\(h.name)\" (\(frequency)) — streak \(h.currentStreak) weeks, \(done)")
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

    /// All available companion personalities. Add new ones here.
    static let allPersonalities: [any CompanionPersonality] = [
        OttoPersonality(),
        GoosePersonality()
    ]

    var currentMessage: CompanionMessage? = nil
    var isVisible: Bool = false
    var isGenerating: Bool = false
    var modelAvailability: CompanionModelAvailability = .unsupported
    var startTaskRequest: UUID? = nil
    var chatHistory: [ChatMessage] = []
    private(set) var personality: any CompanionPersonality

    // Opaque storage for LanguageModelSession (iOS 26+ only)
    private var _session: Any? = nil

    // Live task context — updated by call sites before triggering
    private var taskContext: CompanionTaskContext = .empty

    // Retained store reference so chat sheet can refresh context without prop-drilling
    private var modelStore: ClarityModelActor? = nil

    // App-target-only chat history store
    private let chatStore = CompanionChatStore()

    /// The resolved display name — UserDefaults value, or the personality's default if unset.
    var displayName: String {
        let stored = UserDefaults.companionName
        return stored.isEmpty ? personality.defaultCompanionName : stored
    }

    private init() {
        let savedID = UserDefaults.companionPersonalityID
        personality = CompanionService.allPersonalities.first { $0.id == savedID } ?? OttoPersonality()
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

    // MARK: - Personality selection

    func selectPersonality(_ new: any CompanionPersonality) {
        personality = new
        UserDefaults.companionPersonalityID = new.id
        UserDefaults.companionName = new.defaultCompanionName
        _session = nil
        log.info("selectPersonality: switched to \(new.id)")
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

    /// Load persisted chat history and prune stale messages.
    func loadChatHistory() {
        let history = chatStore.fetchRecent()
        chatHistory = history
        log.info("loadChatHistory: loaded \(history.count) messages")
    }

    // MARK: - Context loading

    /// Call this from any actor that has a ClarityModelActor before triggering or chatting.
    func loadContext(from store: ClarityModelActor) async {
        log.debug("loadContext: fetching tasks and habits")
        do {
            let incomplete = try await store.fetchTasks(filter: .all)
            let completed = try await store.fetchCompletedTasks()
            let habits = try await store.fetchHabits()
            log.debug("loadContext: \(incomplete.count) incomplete, \(completed.count) completed tasks, \(habits.count) habits")

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

            let calendar = Calendar.current
            var habitSummaries: [CompanionTaskContext.HabitSummary] = []
            for habit in habits {
                let allHistory = try await store.fetchHabitHistory(habit.uuid, from: Date.distantPast, to: now)
                let streak = HabitStreakCalculator.streak(occurrences: allHistory, frequency: habit.weeklyFrequency, freezes: habit.streakFreezes)
                let today = calendar.startOfDay(for: now)
                let doneToday = allHistory.contains { occurrence in
                    occurrence.completed && calendar.isDate(occurrence.periodStart, inSameDayAs: today)
                }
                habitSummaries.append(CompanionTaskContext.HabitSummary(
                    uuid: habit.uuid,
                    name: habit.name,
                    weeklyFrequency: habit.weeklyFrequency,
                    currentStreak: streak.current,
                    doneToday: doneToday
                ))
            }

            taskContext = CompanionTaskContext(
                dueTasks: Array(dueSummaries),
                recentlyCompleted: Array(recentSummaries),
                habits: habitSummaries,
                loadedAt: now
            )
            log.debug("loadContext: context built — \(self.taskContext.dueTasks.count) due, \(self.taskContext.recentlyCompleted.count) recent, \(self.taskContext.habits.count) habits")

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
        let base = personality.systemInstructions(name: displayName, contextBlock: taskContext.instructionsBlock)
        let emotionList = personality.supportedEmotions.map(\.rawValue).joined(separator: ", ")
        let historyBlock = recentConversationBlock()
        let instructions = base + "\n\nValid emotion values: \(emotionList)" + (historyBlock.isEmpty ? "" : "\n\nRECENT CONVERSATION:\n\(historyBlock)")
        log.debug("currentSession: creating new session")
        log.debug("currentSession: instructions —\n\(instructions)")
        let newSession = LanguageModelSession(instructions: instructions)
        session = newSession
        return newSession
    }

    private func recentConversationBlock(limit: Int = 8) -> String {
        let recent = Array(chatHistory.suffix(limit))
        guard !recent.isEmpty else { return "" }
        return recent.map { message in
            let sender = message.sender == .user ? "User" : displayName
            return "\(sender): \(message.text)"
        }.joined(separator: "\n")
    }
    #endif

    // MARK: - Public trigger entry point

    private var companionEnabled: Bool {
        if UserDefaults.standard.object(forKey: "me.craigpeters.clarity.companionEnabled") == nil { return true }
        return UserDefaults.standard.bool(forKey: "me.craigpeters.clarity.companionEnabled")
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
            Task { await generate(prompt: personality.prompt(for: event), fallbackEvent: event) }
        } else {
            log.debug("trigger: model unavailable, using fallback")
            showFallback(for: event)
        }
        #else
        log.debug("trigger: FoundationModels not importable, using fallback")
        showFallback(for: event)
        #endif
    }

    /// Send a free-form message directly from the user to the companion.
    func chat(_ userMessage: String) {
        guard companionEnabled,
              !isGenerating,
              !userMessage.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        checkModelAvailability()
        log.info("chat: user message — \"\(userMessage)\" — model availability: \(String(describing: modelAvailability))")

        appendUserMessage(userMessage)

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

    private func appendUserMessage(_ text: String) {
        let message = ChatMessage(sender: .user, text: text)
        chatStore.append(message)
        chatHistory.append(message)
    }

    // MARK: - Generation

    #if canImport(FoundationModels)
    /// Single generation path for both trigger events and free-form chat.
    @available(iOS 26.0, *)
    private func generate(prompt: String, fallbackEvent: CompanionTrigger?) async {
        isGenerating = true
        defer { isGenerating = false }

        log.info("generate: prompt — \"\(prompt)\"")

        do {
            let response = try await currentSession().respond(to: prompt, generating: CompanionOutput.self)
            show(response.content, trigger: fallbackEvent)
        } catch let genError as LanguageModelSession.GenerationError {
            switch genError {
            case .assetsUnavailable:
                log.warning("generate: assets unavailable — marking modelNotReady")
                modelAvailability = .modelNotReady
                session = nil
                showErrorFallback()

            case .exceededContextWindowSize:
                // Reset to a fresh session and retry once
                log.warning("generate: context window exceeded — resetting session and retrying")
                session = nil
                do {
                    let response = try await currentSession().respond(to: prompt, generating: CompanionOutput.self)
                    show(response.content, trigger: fallbackEvent)
                } catch {
                    log.error("generate: retry after context reset failed — \(error)")
                    showErrorFallback()
                }

            case .guardrailViolation:
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
    private func show(_ output: CompanionOutput, trigger: CompanionTrigger?) {
        let message = CompanionOutputMapper.map(
            output,
            trigger: trigger,
            supportedEmotions: personality.supportedEmotions,
            dueTasks: taskContext.dueTasks
        )
        log.debug("generate: text='\(message.text)' emotion=\(message.emotion.rawValue) suggestedTask=\(String(describing: message.suggestedTask?.name))")
        guard appendCompanionMessage(message, trigger: trigger) else { return }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            currentMessage = message
            isVisible = true
        }
    }

    @discardableResult
    private func appendCompanionMessage(_ message: CompanionMessage, trigger: CompanionTrigger?) -> Bool {
        if CompanionOutputMapper.isDuplicate(message, lastChatHistoryMessage: chatHistory.last, trigger: trigger) {
            log.debug("appendCompanionMessage: skipping duplicate companion message")
            return false
        }
        let historyMessage = ChatMessage(
            sender: .companion,
            text: message.text,
            emotion: message.emotion.rawValue,
            suggestedTaskUUID: message.suggestedTask?.uuid,
            suggestedTaskName: message.suggestedTask?.name
        )
        chatStore.append(historyMessage)
        chatHistory.append(historyMessage)
        return true
    }
    #endif

    // MARK: - Error classification

    /// Returns true for the "model catalog not downloaded" error Apple surfaces as a
    /// generic GenerationError Code=-1 wrapping ModelManagerError Code=1026, as well
    /// as the typed .assetsUnavailable case.
    private func isModelCatalogError(_ error: Error) -> Bool {
        CompanionOutputMapper.isModelCatalogError(error)
    }

    // MARK: - Fallback (no LLM)

    private func showErrorFallback() {
        let message = personality.errorFallback(overdueTask: taskContext.dueTasks.first)
        guard appendCompanionMessage(message, trigger: nil) else { return }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            currentMessage = message
            isVisible = true
        }
    }

    private func showChatFallback() {
        let message = personality.chatFallback
        guard appendCompanionMessage(message, trigger: nil) else { return }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            currentMessage = message
            isVisible = true
        }
    }

    private func showFallback(for event: CompanionTrigger) {
        let message = personality.fallbackMessage(for: event)
        guard appendCompanionMessage(message, trigger: event) else { return }
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
        chatStore.deleteAll()
        chatHistory.removeAll()
        log.info("clearHistory: session, message, and persisted chat history cleared")
    }

    // MARK: - Habit completion trigger

    func triggerHabitCompleted(habit: HabitDTO, completedOccurrence: HabitOccurrenceDTO) {
        guard let store = modelStore else {
            log.warning("triggerHabitCompleted: no store registered")
            return
        }
        Task {
            do {
                let allHistory = try await store.fetchHabitHistory(habit.uuid, from: Date.distantPast, to: Date.distantFuture)
                let state = HabitStreakState.resolve(
                    habit: habit,
                    completedOccurrences: allHistory,
                    completedAt: completedOccurrence.completedAt ?? Date()
                )
                trigger(.habitCompleted(habitName: habit.name, state: state))
            } catch {
                log.error("triggerHabitCompleted: failed to resolve streak — \(error)")
            }
        }
    }

    func dismiss() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            isVisible = false
        }
    }

    func requestStartTask(_ uuid: UUID) {
        startTaskRequest = uuid
    }
}

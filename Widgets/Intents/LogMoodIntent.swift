import AppIntents
import Foundation

// MARK: - Mood enum

enum PomodoroMood: String, AppEnum, CaseIterable {
    case excited
    case happy
    case calm
    case stressed
    case discouraged

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Mood")
    static let caseDisplayRepresentations: [PomodoroMood: DisplayRepresentation] = [
        .excited:    DisplayRepresentation(title: "Excited",     image: .init(systemName: "face.smiling")),
        .happy:      DisplayRepresentation(title: "Happy",       image: .init(systemName: "face.smiling")),
        .calm:       DisplayRepresentation(title: "Calm",        image: .init(systemName: "face.smiling")),
        .stressed:   DisplayRepresentation(title: "Stressed",    image: .init(systemName: "face.smiling")),
        .discouraged:DisplayRepresentation(title: "Discouraged", image: .init(systemName: "face.smiling")),
    ]

    var emoji: String {
        switch self {
        case .excited:     return "🤩"
        case .happy:       return "😄"
        case .calm:        return "😶"
        case .stressed:    return "😓"
        case .discouraged: return "😞"
        }
    }

    var valence: Double {
        switch self {
        case .excited:     return  0.9
        case .happy:       return  0.7
        case .calm:        return  0.3
        case .stressed:    return -0.4
        case .discouraged: return -0.7
        }
    }
}

// MARK: - Intent

/// Logs a mood for the most recently completed Pomodoro session.
/// Runs in the app process (LiveActivityIntent) so it can write to SwiftData.
struct LogMoodIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Log Mood"
    static let description = IntentDescription("Record how you feel after a Pomodoro session")
    static let openAppWhenRun: Bool = false

    @Parameter(title: "Mood")
    var mood: PomodoroMood

    init() {}

    init(mood: PomodoroMood) {
        self.mood = mood
    }

    func perform() async throws -> some IntentResult {
        let appGroup = "group.me.craigpeters.clarity"
        let sessionHistoryKey = "completedPomodoroSessions"
        let defaults = UserDefaults(suiteName: appGroup)

        // Load sessions, mark the most recent unlogged one, save back
        guard let data = defaults?.data(forKey: sessionHistoryKey),
              var sessions = try? JSONDecoder().decode([PersistedSession].self, from: data),
              let index = sessions.firstIndex(where: { !$0.moodLogged })
        else { return .result() }

        sessions[index].moodLogged = true
        sessions[index].moodEmoji = mood.emoji

        if let encoded = try? JSONEncoder().encode(sessions) {
            defaults?.set(encoded, forKey: sessionHistoryKey)
        }

        // Write valence to the task in SwiftData
        if let taskUUID = sessions[index].taskUUID {
            do {
                let store = try await ClarityServices.store()
                try await store.recordMood(valence: mood.valence, taskUUID: taskUUID)
            } catch {
                // Non-fatal — UserDefaults flag is already set
            }
        }

        return .result()
    }
}

/// Minimal mirror of PomodoroService.CompletedSession for UserDefaults decoding.
private struct PersistedSession: Codable {
    let id: UUID
    let taskName: String
    let taskUUID: UUID?
    let startTime: Date
    let endTime: Date
    var moodLogged: Bool
    var moodEmoji: String?
}

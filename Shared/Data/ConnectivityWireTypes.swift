//
//  ConnectivityWireTypes.swift
//  Clarity
//
//  Wire format for watch ↔ iPhone connectivity.
//

import Foundation

// MARK: - Commands (watch → phone, reliable/ordered)

enum WatchCommand: Sendable {
    case completeTask(UUID)
    case uncompleteTask(UUID)
    case startPomodoro(UUID)
    case stopPomodoro
    case requestSnapshot
    case sendLogs(Data)
    case logHabitProgress(UUID, amount: Double?)
}

nonisolated extension WatchCommand: Codable {}

// MARK: - Events (phone → watch, reliable/ordered)

enum PhoneEvent: Sendable {
    case pomodoroStarted(PomodoroDTO)
    case pomodoroStopped(taskID: UUID?)
}

nonisolated extension PhoneEvent: Codable {}

// MARK: - Snapshot (phone → watch, latest-wins or complication wake)

struct Snapshot: Sendable {
    var revision: Int
    var tasks: [ToDoTaskDTO]
    var habits: [HabitDTO]
    var habitOccurrences: [UUID: HabitOccurrenceDTO]
    var progress: WeeklyProgress
    var activePomodoro: PomodoroDTO?
}

extension Snapshot: Codable {
    private enum CodingKeys: String, CodingKey {
        case revision, tasks, habits, habitOccurrences, progress, activePomodoro
    }

    nonisolated init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.revision = try c.decode(Int.self, forKey: .revision)
        self.tasks = try c.decode([ToDoTaskDTO].self, forKey: .tasks)
        self.habits = try c.decodeIfPresent([HabitDTO].self, forKey: .habits) ?? []
        let occurrencesArray = try c.decodeIfPresent([HabitOccurrenceDTO].self, forKey: .habitOccurrences) ?? []
        self.habitOccurrences = Dictionary(uniqueKeysWithValues: occurrencesArray.map { ($0.habitUUID, $0) })
        self.progress = try c.decode(WeeklyProgress.self, forKey: .progress)
        self.activePomodoro = try c.decodeIfPresent(PomodoroDTO.self, forKey: .activePomodoro)
    }

    nonisolated func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(revision, forKey: .revision)
        try c.encode(tasks, forKey: .tasks)
        try c.encode(habits, forKey: .habits)
        try c.encode(Array(habitOccurrences.values), forKey: .habitOccurrences)
        try c.encode(progress, forKey: .progress)
        try c.encodeIfPresent(activePomodoro, forKey: .activePomodoro)
    }
}

// MARK: - Complication projection

/// A minimal, stable view of the state used by watch complications. Derived from `Snapshot`.
struct ComplicationProjection: Sendable, Hashable {
    var topTaskName: String?
    var topTaskDue: Date?
    var isPomodoroActive: Bool

    init(snapshot: Snapshot) {
        let incomplete = snapshot.tasks
            .filter { !$0.completed }
            .sorted { $0.due < $1.due }
        let top = incomplete.first
        self.topTaskName = top?.name
        self.topTaskDue = top?.due
        self.isPomodoroActive = snapshot.activePomodoro != nil
    }
}

nonisolated extension ComplicationProjection: Codable {}

// MARK: - Unified wire message

/// All watch/phone traffic travels as a single enum. The transport encodes and decodes
/// `WireMessage` directly, so there is no ambiguous "try A, then B" decoding.
enum WireMessage: Sendable {
    case command(WatchCommand)
    case event(PhoneEvent)
    case snapshot(Snapshot)
    case complicationSnapshot(Snapshot)
}

nonisolated extension WireMessage: Codable {}

// MARK: - DTO refinement

/// Lightweight pomodoro state carried to the watch. The DTO relies on synthesized `Codable`.
struct PomodoroDTO: Sendable {
    var startTime: Date?
    var endTime: Date?
    var toDoTask: ToDoTaskDTO
}

nonisolated extension PomodoroDTO: Codable {}

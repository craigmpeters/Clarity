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
    var progress: WeeklyProgress
    var activePomodoro: PomodoroDTO?
}

nonisolated extension Snapshot: Codable {}

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

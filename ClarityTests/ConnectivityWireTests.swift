//
//  ConnectivityWireTests.swift
//  ClarityTests
//
//  Created by OpenCode on 09/08/2026.
//

@testable import Clarity
import Foundation
import Testing

struct ConnectivityWireTests {
    private func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    private func task(name: String, due: Date, completed: Bool = false) -> ToDoTaskDTO {
        ToDoTaskDTO(name: name, due: due, categories: [], uuid: UUID(), completed: completed)
    }

    private func habit(name: String) -> HabitDTO {
        HabitDTO(name: name, dailyTarget: 1.0)
    }

    private func occurrence(habitUUID: UUID, periodStart: Date) -> HabitOccurrenceDTO {
        HabitOccurrenceDTO(habitUUID: habitUUID, periodStart: periodStart)
    }

    private func snapshot(revision: Int = 1) -> Snapshot {
        let due = Date(timeIntervalSince1970: 1_000_000)
        let habit = habit(name: "Walk")
        let occ = occurrence(habitUUID: habit.uuid, periodStart: due)
        return Snapshot(
            revision: revision,
            tasks: [task(name: "Task A", due: due)],
            habits: [habit],
            habitOccurrences: [habit.uuid: occ],
            progress: WeeklyProgress(completed: 1, target: 2, error: nil, categories: []),
            activePomodoro: nil
        )
    }

    @Test func watchCommandRoundTrip() throws {
        let commands: [WatchCommand] = [
            .completeTask(UUID()),
            .uncompleteTask(UUID()),
            .startPomodoro(UUID()),
            .stopPomodoro,
            .requestSnapshot,
            .sendLogs(Data([0xAB, 0xCD])),
            .logHabitProgress(UUID(), amount: 12.5),
            .logHabitProgress(UUID(), amount: nil),
        ]

        for command in commands {
            let message = WireMessage.command(command)
            let data = try makeEncoder().encode(message)
            let decoded = try makeDecoder().decode(WireMessage.self, from: data)
            if case let .command(roundTripped) = decoded {
                #expect(commandMatches(roundTripped, command))
            } else {
                Issue.record("Decoded message was not a command")
            }
        }
    }

    @Test func phoneEventRoundTrip() throws {
        let fixedNow = Date(timeIntervalSince1970: 1_000_000)
        let events: [PhoneEvent] = [
            .pomodoroStarted(
                PomodoroDTO(
                    startTime: fixedNow, endTime: fixedNow.addingTimeInterval(600),
                    toDoTask: task(name: "Focus", due: fixedNow)
                )
            ),
            .pomodoroStopped(taskID: UUID()),
            .pomodoroStopped(taskID: nil),
            .habitCommandFailed(uuid: UUID()),
        ]

        for event in events {
            let message = WireMessage.event(event)
            let data = try makeEncoder().encode(message)
            let decoded = try makeDecoder().decode(WireMessage.self, from: data)
            if case let .event(roundTripped) = decoded {
                #expect(eventMatches(roundTripped, event))
            } else {
                Issue.record("Decoded message was not an event")
            }
        }
    }

    @Test func wireMessageSnapshotRoundTrip() throws {
        let original = snapshot()
        let message = WireMessage.snapshot(original)
        let data = try makeEncoder().encode(message)
        let decoded = try makeDecoder().decode(WireMessage.self, from: data)
        if case let .snapshot(roundTripped) = decoded {
            #expect(roundTripped.revision == original.revision)
            #expect(roundTripped.tasks.count == original.tasks.count)
            #expect(roundTripped.habitOccurrences.count == original.habitOccurrences.count)
        } else {
            Issue.record("Decoded message was not a snapshot")
        }
    }

    @Test func wireMessageComplicationSnapshotRoundTrip() throws {
        let original = snapshot()
        let message = WireMessage.complicationSnapshot(original)
        let data = try makeEncoder().encode(message)
        let decoded = try makeDecoder().decode(WireMessage.self, from: data)
        if case let .complicationSnapshot(roundTripped) = decoded {
            #expect(roundTripped.revision == original.revision)
        } else {
            Issue.record("Decoded message was not a complication snapshot")
        }
    }

    @Test func snapshotCustomCodableDictionaryToArray() throws {
        let original = snapshot()
        let data = try makeEncoder().encode(original)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let occurrencesArray = json?["habitOccurrences"] as? [[String: Any]]
        #expect(occurrencesArray?.count == 1)

        let decoded = try makeDecoder().decode(Snapshot.self, from: data)
        #expect(decoded.habitOccurrences.count == original.habitOccurrences.count)
    }

    @Test func snapshotDecodeWithMissingFieldsUsesDefaults() throws {
        let json = try #require("""
        {
            "revision": 5,
            "tasks": [],
            "progress": {
                "completed": 0,
                "target": 0,
                "categories": []
            }
        }
        """.data(using: .utf8))
        let decoded = try makeDecoder().decode(Snapshot.self, from: json)
        #expect(decoded.revision == 5)
        #expect(decoded.habits.isEmpty)
        #expect(decoded.habitOccurrences.isEmpty)
        #expect(decoded.activePomodoro == nil)
    }

    @Test func complicationProjectionPicksFirstIncompleteTask() {
        let snap = Snapshot(
            revision: 1,
            tasks: [
                task(name: "Done", due: Date().addingTimeInterval(-100), completed: true),
                task(name: "Soon", due: Date().addingTimeInterval(100)),
                task(name: "Later", due: Date().addingTimeInterval(200)),
            ],
            habits: [],
            habitOccurrences: [:],
            progress: WeeklyProgress(completed: 0, target: 0, error: nil, categories: []),
            activePomodoro: nil
        )
        let projection = ComplicationProjection(snapshot: snap)
        #expect(projection.topTaskName == "Soon")
        #expect(projection.isPomodoroActive == false)
    }

    @Test func complicationProjectionNilWhenAllCompleted() {
        let snap = Snapshot(
            revision: 1,
            tasks: [task(name: "Done", due: Date(), completed: true)],
            habits: [],
            habitOccurrences: [:],
            progress: WeeklyProgress(completed: 0, target: 0, error: nil, categories: []),
            activePomodoro: nil
        )
        let projection = ComplicationProjection(snapshot: snap)
        #expect(projection.topTaskName == nil)
        #expect(projection.topTaskDue == nil)
    }

    @Test func complicationProjectionPomodoroActiveFlag() {
        let snap = Snapshot(
            revision: 1,
            tasks: [],
            habits: [],
            habitOccurrences: [:],
            progress: WeeklyProgress(completed: 0, target: 0, error: nil, categories: []),
            activePomodoro: PomodoroDTO(
                startTime: Date(), endTime: Date(), toDoTask: task(name: "Focus", due: Date())
            )
        )
        let projection = ComplicationProjection(snapshot: snap)
        #expect(projection.isPomodoroActive == true)
    }

    @Test func complicationProjectionRoundTrip() throws {
        let snap = snapshot()
        let original = ComplicationProjection(snapshot: snap)
        let data = try makeEncoder().encode(original)
        let decoded = try makeDecoder().decode(ComplicationProjection.self, from: data)
        #expect(decoded == original)
    }
}

private func commandMatches(_ lhs: WatchCommand, _ rhs: WatchCommand) -> Bool {
    switch (lhs, rhs) {
    case let (.completeTask(a), .completeTask(b)),
         let (.uncompleteTask(a), .uncompleteTask(b)),
         let (.startPomodoro(a), .startPomodoro(b)):
        return a == b
    case (.stopPomodoro, .stopPomodoro),
         (.requestSnapshot, .requestSnapshot):
        return true
    case let (.sendLogs(a), .sendLogs(b)):
        return a == b
    case let (.logHabitProgress(a, amount: b), .logHabitProgress(c, amount: d)):
        return a == c && b == d
    case let (
        .logHabitProgressAt(a, amount: b, timestamp: t1),
        .logHabitProgressAt(c, amount: d, timestamp: t2)
    ):
        return a == c && b == d && t1 == t2
    default:
        return false
    }
}

private func eventMatches(_ lhs: PhoneEvent, _ rhs: PhoneEvent) -> Bool {
    switch (lhs, rhs) {
    case let (.pomodoroStarted(a), .pomodoroStarted(b)):
        return pomodoroMatches(a, b)
    case let (.pomodoroStopped(taskID: a), .pomodoroStopped(taskID: b)):
        return a == b
    case let (.habitCommandFailed(uuid: a), .habitCommandFailed(uuid: b)):
        return a == b
    default:
        return false
    }
}

private func pomodoroMatches(_ lhs: PomodoroDTO, _ rhs: PomodoroDTO) -> Bool {
    lhs.startTime == rhs.startTime && lhs.endTime == rhs.endTime
        && lhs.toDoTask.uuid == rhs.toDoTask.uuid && lhs.toDoTask.name == rhs.toDoTask.name
}

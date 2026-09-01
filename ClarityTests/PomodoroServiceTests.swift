//
//  PomodoroServiceTests.swift
//  ClarityTests
//

import Foundation
import Testing
@testable import Clarity

struct PomodoroServiceTests {

    @Test @MainActor func recordCompletedSessionKeepsActualEndTimeForShortSessions() {
        let service = PomodoroService()
        let start = Date()
        let end = start.addingTimeInterval(10 * 60) // 10 Minutes taken on task
        let pomodoroTime = 25 * 60.0 // 25 Minute Pomodoro Time

        service.recordCompletedSession(
            taskName: "Short session",
            taskUUID: nil,
            startTime: start,
            endTime: end,
            pomodoroTime: pomodoroTime
        )

        let session = service.recentSessions.first
        #expect(session?.endTime == end)
    }

    @Test @MainActor func recordCompletedSessionCapsEndTimeForLongSessions() {
        let service = PomodoroService()
        let start = Date()
        let end = start.addingTimeInterval(30 * 60) // 30 Minutes Completion Time
        let pomodoroTime = 25 * 60.0 // 25 Minute Pomodoro Time
        let expectedEnd = start.addingTimeInterval(pomodoroTime)

        service.recordCompletedSession(
            taskName: "Long session",
            taskUUID: nil,
            startTime: start,
            endTime: end,
            pomodoroTime: pomodoroTime
        )

        let session = service.recentSessions.first
        #expect(session?.endTime == expectedEnd)
    }

    @Test @MainActor func notificationIdentifierIsDerivedFromTaskUUID() {
        let service = PomodoroService()
        let taskUUID = UUID(uuidString: "A1B2C3D4-E5F6-7890-ABCD-EF1234567890")!
        service.toDoTask = ToDoTaskDTO(
            name: "Test task",
            pomodoroTime: 1500,
            due: Date(),
            uuid: taskUUID,
            completed: false
        )

        #expect(service.notificationIdentifier == "pomodoro-A1B2C3D4-E5F6-7890-ABCD-EF1234567890")
    }

    @Test @MainActor func notificationIdentifierFallsBackToGenericWhenNoTask() {
        let service = PomodoroService()
        service.toDoTask = nil

        #expect(service.notificationIdentifier == "pomodoro-generic")
    }

    @Test @MainActor func endPomodoroWithoutActiveSessionStillCleansUp() async {
        let service = PomodoroService()
        service.isActive = false

        // The method must return without posting a completion notification.
        await service.endPomodoro()

        #expect(service.isActive == false)
        #expect(service.recentSessions.isEmpty)
    }
}

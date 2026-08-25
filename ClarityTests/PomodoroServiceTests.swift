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
}

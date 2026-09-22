//
//  DTOCodableTests.swift
//  ClarityTests
//
//  Created by OpenCode on 09/08/2026.
//

import Foundation
import Testing
import SwiftData
@testable import Clarity

struct DTOCodableTests {

    private func categoryDTO(name: String = "Work", color: Clarity.Category.CategoryColor = .Red, weeklyTarget: Int = 5) -> CategoryDTO {
        CategoryDTO(id: nil, name: name, color: color, weeklyTarget: weeklyTarget, uuid: UUID())
    }

    private func taskDTO(name: String = "Task", completedAt: Date? = nil) -> ToDoTaskDTO {
        ToDoTaskDTO(
            name: name,
            categories: [],
            uuid: UUID(),
            completedAt: completedAt
        )
    }

    // MARK: - ToDoTaskDTO

    @Test func toDoTaskDTORoundTrip() throws {
        let original = taskDTO(name: "Read docs", completedAt: Date())
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ToDoTaskDTO.self, from: data)
        #expect(decoded.name == original.name)
        #expect(decoded.uuid == original.uuid)
        #expect(decoded.completedAt == original.completedAt)
    }

    @Test func toDoTaskDTODecodeWithMissingKeysUsesDefaults() throws {
        let json = """
        {
            "name": "Minimal",
            "due": 0
        }
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(ToDoTaskDTO.self, from: json)
        #expect(decoded.name == "Minimal")
        #expect(decoded.pomodoro == true)
        #expect(decoded.pomodoroTime == 25 * 60)
        #expect(decoded.repeating == false)
        #expect(decoded.completed == false)
        #expect(decoded.customRecurrenceDays == 1)
        #expect(decoded.everySpecificDayDay == 0)
        #expect(decoded.categories.isEmpty)
    }

    // MARK: - CategoryDTO

    @Test func categoryDTORoundTrip() throws {
        let original = categoryDTO(name: "Home", color: .Blue, weeklyTarget: 3)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CategoryDTO.self, from: data)
        #expect(decoded.name == original.name)
        #expect(decoded.color == original.color)
        #expect(decoded.weeklyTarget == original.weeklyTarget)
    }

    @Test func categoryDTODecodeWithMissingKeysUsesDefaults() throws {
        let json = """
        {
            "name": "Minimal",
            "color": "Red"
        }
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(CategoryDTO.self, from: json)
        #expect(decoded.name == "Minimal")
        #expect(decoded.weeklyTarget == 0)
        #expect(decoded.iconName == nil)
        #expect(decoded.uuid == nil)
    }

    @Test func categoryDTOEncodedIdIsNilWithoutPersistentIdentifier() {
        let original = categoryDTO(name: "NoPersistentID")
        #expect(original.encodedId == nil)
    }

    @Test func categoryDTODecodeIdRejectsGarbageBase64() throws {
        let original = categoryDTO()
        #expect(throws: (any Error).self) {
            try original.decodeId("not-valid-base64!!!")
        }
    }

    // MARK: - WeeklyProgress

    @Test func weeklyProgressRoundTrip() throws {
        let progress = WeeklyProgress(
            completed: 5,
            target: 10,
            error: nil,
            categories: [CategoryProgress(name: "Work", completed: 3, target: 5, color: "Red")]
        )
        let data = try JSONEncoder().encode(progress)
        let decoded = try JSONDecoder().decode(WeeklyProgress.self, from: data)
        #expect(decoded.completed == 5)
        #expect(decoded.target == 10)
        #expect(decoded.error == nil)
        #expect(decoded.categories.count == 1)
        #expect(decoded.categories[0].name == "Work")
    }

    // MARK: - WatchUserInfo

    @Test func watchUserInfoRoundTrip() throws {
        let info = WatchUserInfo(
            tasks: [taskDTO(name: "A")],
            progress: WeeklyProgress(completed: 1, target: 2, error: nil, categories: [])
        )
        let data = try JSONEncoder().encode(info)
        let decoded = try JSONDecoder().decode(WatchUserInfo.self, from: data)
        #expect(decoded.tasks.count == 1)
        #expect(decoded.tasks[0].name == "A")
        #expect(decoded.progress.completed == 1)
    }

    // MARK: - WatchWidgetData

    @Test func watchWidgetDataRoundTrip() throws {
        let original = WatchWidgetData(due: 3, completed: 5, progress: 2, target: 10)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(WatchWidgetData.self, from: data)
        #expect(decoded.due == 3)
        #expect(decoded.completed == 5)
        #expect(decoded.progress == 2)
        #expect(decoded.target == 10)
    }

    // MARK: - Pomodoro CompletedSession

    @Test func completedSessionRoundTrip() throws {
        let original = PomodoroService.CompletedSession(
            id: UUID(),
            taskName: "Focus",
            taskUUID: UUID(),
            startTime: Date(),
            endTime: Date().addingTimeInterval(600),
            moodLogged: true,
            moodEmoji: "🙂"
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(PomodoroService.CompletedSession.self, from: data)
        #expect(decoded.id == original.id)
        #expect(decoded.taskName == original.taskName)
        #expect(decoded.moodLogged == true)
        #expect(decoded.moodEmoji == "🙂")
    }
}

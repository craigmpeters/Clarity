//
//  CompanionOutputMapperTests.swift
//  ClarityTests
//
//  Created by OpenCode on 13/08/2026.
//

import Foundation
import Testing
@testable import Clarity

struct CompanionOutputMapperTests {

    private struct FakeOutput: CompanionOutputValues {
        let text: String
        let emotion: String
        let suggestedTaskName: String
    }

    private func makeOutput(text: String, emotion: String, suggestedTaskName: String) -> some CompanionOutputValues {
        FakeOutput(text: text, emotion: emotion, suggestedTaskName: suggestedTaskName)
    }

    private func makeTask(name: String, uuid: UUID = UUID()) -> CompanionTaskContext.TaskSummary {
        CompanionTaskContext.TaskSummary(
            uuid: uuid,
            name: name,
            dueDate: Date(),
            pomodoroMinutes: 25,
            lastCompletedAt: nil,
            lastMoodValence: nil,
            categories: []
        )
    }

    @Test func trimsWhitespaceAndNewlinesFromText() {
        let output = makeOutput(text: "  Hello there!\n\n", emotion: "happy", suggestedTaskName: "")
        let message = CompanionOutputMapper.map(output, trigger: nil, supportedEmotions: [.happy], dueTasks: [])
        #expect(message.text == "Hello there!")
    }

    @Test func emptyTextFallsBackToRawOutput() {
        let output = makeOutput(text: "   ", emotion: "happy", suggestedTaskName: "")
        let message = CompanionOutputMapper.map(output, trigger: nil, supportedEmotions: [.happy], dueTasks: [])
        #expect(message.text == "   ")
    }

    @Test func mapsValidEmotion() {
        let output = makeOutput(text: "Great job!", emotion: "encouraging", suggestedTaskName: "")
        let message = CompanionOutputMapper.map(output, trigger: nil, supportedEmotions: [.encouraging, .happy], dueTasks: [])
        #expect(message.emotion == .encouraging)
    }

    @Test func fallsBackToFirstSupportedEmotion() {
        let output = makeOutput(text: "Great job!", emotion: "unknown", suggestedTaskName: "")
        let message = CompanionOutputMapper.map(output, trigger: nil, supportedEmotions: [.loving, .happy], dueTasks: [])
        #expect(message.emotion == .loving)
    }

    @Test func fallsBackToHappyWhenNoSupportedEmotions() {
        let output = makeOutput(text: "Great job!", emotion: "unknown", suggestedTaskName: "")
        let message = CompanionOutputMapper.map(output, trigger: nil, supportedEmotions: [], dueTasks: [])
        #expect(message.emotion == .happy)
    }

    @Test func matchesSuggestedTaskIgnoringCase() {
        let task = makeTask(name: "File taxes")
        let output = makeOutput(text: "You should file taxes today.", emotion: "happy", suggestedTaskName: "file taxes")
        let message = CompanionOutputMapper.map(
            output,
            trigger: .taskCompleted(taskName: "Some task"),
            supportedEmotions: [.happy],
            dueTasks: [task]
        )
        #expect(message.suggestedTask?.name == "File taxes")
    }

    @Test func doesNotSuggestTaskWhenTriggerDisallows() {
        let task = makeTask(name: "File taxes")
        let output = makeOutput(text: "You should file taxes today.", emotion: "happy", suggestedTaskName: "file taxes")
        let message = CompanionOutputMapper.map(
            output,
            trigger: .appLaunch,
            supportedEmotions: [.happy],
            dueTasks: [task]
        )
        #expect(message.suggestedTask == nil)
    }

    @Test func duplicateDetectionRequiresCompanionSender() {
        let message = CompanionMessage(text: "Hello", emotion: .happy)
        let lastUser = ChatMessage(sender: .user, text: "Hello")
        #expect(CompanionOutputMapper.isDuplicate(message, lastChatHistoryMessage: lastUser, trigger: nil) == false)
    }

    @Test func duplicateDetectionRequiresMatchingText() {
        let message = CompanionMessage(text: "Hello", emotion: .happy)
        let last = ChatMessage(sender: .companion, text: "Goodbye")
        #expect(CompanionOutputMapper.isDuplicate(message, lastChatHistoryMessage: last, trigger: nil) == false)
    }

    @Test func duplicateDetectionSkippedWhenSuggestionAllowed() {
        let message = CompanionMessage(text: "Hello", emotion: .happy)
        let last = ChatMessage(sender: .companion, text: "Hello")
        #expect(CompanionOutputMapper.isDuplicate(message, lastChatHistoryMessage: last, trigger: .taskCompleted(taskName: "x")) == false)
    }

    @Test func duplicateDetectionFlagsMatchingCompanionMessage() {
        let message = CompanionMessage(text: "Hello", emotion: .happy)
        let last = ChatMessage(sender: .companion, text: "Hello")
        #expect(CompanionOutputMapper.isDuplicate(message, lastChatHistoryMessage: last, trigger: nil) == true)
    }

    @Test func isModelCatalogErrorRecognizesNSErrorMatch() {
        let error = NSError(domain: "FoundationModels.LanguageModelSession.GenerationError", code: -1)
        #expect(CompanionOutputMapper.isModelCatalogError(error) == true)
    }

    @Test func isModelCatalogErrorRejectsOtherErrors() {
        let error = NSError(domain: "com.example", code: 1)
        #expect(CompanionOutputMapper.isModelCatalogError(error) == false)
    }
}

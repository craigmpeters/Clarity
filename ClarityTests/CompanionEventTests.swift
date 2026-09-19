//
//  CompanionEventTests.swift
//  ClarityTests
//
//  Coverage for the new "event" chat message kind: events appear in the
//  transcript but are excluded from the LLM conversation context and do
//  not trigger a companion response.
//

import Foundation
import Testing
@testable import Clarity

@MainActor
struct CompanionEventTests {

    // MARK: - Model basics

    @Test func eventFactoryProducesEventSenderWithEmptySuggestionFields() {
        let event = ChatMessage.event("Task completed: Write report")
        #expect(event.sender == .event)
        #expect(event.text == "Task completed: Write report")
        #expect(event.suggestedTaskUUID == nil)
        #expect(event.suggestedTaskName == nil)
        #expect(event.emotion == nil)
    }

    @Test func eventSenderRawValueRoundTrips() {
        let event = ChatMessage.event("Habit completed: Walk")
        #expect(event.senderRaw == "event")
        #expect(event.sender == .event)
    }

    // MARK: - recordEvent

    @Test func recordEventAppendsToChatHistoryWithoutSideEffects() {
        let service = CompanionService.shared
        service.clearHistory()
        defer { service.clearHistory() }

        service.recordEvent("Habit completed: Walk")

        #expect(service.chatHistory.count == 1)
        #expect(service.chatHistory.last?.sender == .event)
        #expect(service.chatHistory.last?.text == "Habit completed: Walk")

        // No companion reply should be visible/generating
        #expect(service.currentMessage == nil)
        #expect(service.isVisible == false)
        #expect(service.isGenerating == false)
    }
}

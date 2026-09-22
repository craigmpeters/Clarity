//
//  CompanionEnumTests.swift
//  ClarityTests
//
//  Created by OpenCode on 09/08/2026.
//

import Foundation
import Testing
@testable import Clarity

struct CompanionEnumTests {

    @Test func triggerAllowsTaskSuggestionOnlyForCompletionTriggers() {
        #expect(CompanionTrigger.taskCompleted(taskName: "T").allowsTaskSuggestion == true)
        #expect(CompanionTrigger.pomodoroCompleted(taskName: "T").allowsTaskSuggestion == true)
        #expect(CompanionTrigger.appLaunch.allowsTaskSuggestion == false)
        #expect(CompanionTrigger.taskUncompleted(taskName: "T").allowsTaskSuggestion == false)
        #expect(CompanionTrigger.streakMilestone(days: 7).allowsTaskSuggestion == false)
        #expect(CompanionTrigger.lowMoodDetected(averageValence: 0.0).allowsTaskSuggestion == false)
        #expect(CompanionTrigger.habitSuggestion(categories: [], completedCount: 0).allowsTaskSuggestion == false)
        #expect(CompanionTrigger.habitCompleted(habitName: "H", state: .continued(streak: 1)).allowsTaskSuggestion == false)
    }

    @Test func modelAvailabilityOnlyAvailableCaseIsAvailable() {
        #expect(CompanionModelAvailability.available.isAvailable == true)
        #expect(CompanionModelAvailability.deviceNotEligible.isAvailable == false)
        #expect(CompanionModelAvailability.appleIntelligenceNotEnabled.isAvailable == false)
        #expect(CompanionModelAvailability.modelNotReady.isAvailable == false)
        #expect(CompanionModelAvailability.unsupported.isAvailable == false)
    }

    @Test func modelAvailabilityUserFacingReasons() {
        #expect(CompanionModelAvailability.available.userFacingReason == "")
        #expect(CompanionModelAvailability.deviceNotEligible.userFacingReason.isEmpty == false)
        #expect(CompanionModelAvailability.appleIntelligenceNotEnabled.userFacingReason.isEmpty == false)
        #expect(CompanionModelAvailability.modelNotReady.userFacingReason.isEmpty == false)
        #expect(CompanionModelAvailability.unsupported.userFacingReason.isEmpty == false)
    }

    @Test func companionEmotionRawValueRoundTrip() {
        for emotion in [
            CompanionEmotion.idle, .thinking, .happy, .encouraging, .loving, .caring, .determined, .silly
        ] {
            #expect(CompanionEmotion(rawValue: emotion.rawValue) == emotion)
        }
    }

    @Test func chatMessageSenderMapping() {
        let user = ChatMessage(sender: .user, text: "hi")
        #expect(user.sender == .user)

        let companion = ChatMessage(sender: .companion, text: "hi")
        #expect(companion.sender == .companion)
    }

    @Test func chatMessageSenderFallsBackToCompanionForInvalidRawValue() {
        let message = ChatMessage(sender: .companion, text: "hi")
        message.senderRaw = "invalid"
        #expect(message.sender == .companion)
    }

    @Test func chatMessageEmotionNilWhenNoRawValue() {
        let message = ChatMessage(sender: .companion, text: "hi")
        #expect(message.emotion == nil)
    }

    @Test func chatMessageEmotionValidRawValue() {
        let message = ChatMessage(sender: .companion, text: "hi", emotion: CompanionEmotion.happy.rawValue)
        #expect(message.emotion == .happy)
    }

    @Test func chatMessageEmotionInvalidRawValue() {
        let message = ChatMessage(sender: .companion, text: "hi", emotion: "invalid")
        #expect(message.emotion == nil)
    }
}

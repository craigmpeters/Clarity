//
//  UserDefaultsExtensionsTests.swift
//  ClarityTests
//
//  Created by OpenCode on 09/08/2026.
//

import Foundation
import Testing
@testable import Clarity

@MainActor
@Suite(.serialized)
struct UserDefaultsExtensionsTests {

    private let keys: [String] = [
        "hasCompletedOnboarding",
        "hasSeenSwipeGesturesTooltip",
        "pomodoroAlarmSoundID",
        "me.craigpeters.clarity.healthKitEnabled",
        "me.craigpeters.clarity.hasBoughtPremium",
        "me.craigpeters.clarity.companionEnabled",
        "me.craigpeters.clarity.companionName",
        "me.craigpeters.clarity.companionPersonalityID"
    ]

    init() {
        for key in keys {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    @Test func hasCompletedOnboardingDefaultsToFalse() {
        #expect(UserDefaults.hasCompletedOnboarding == false)
    }

    @Test func hasSeenSwipeGesturesTooltipDefaultsToFalse() {
        #expect(UserDefaults.hasSeenSwipeGesturesTooltip == false)
    }

    @Test func pomodoroAlarmSoundIDDefaultsToDefault() {
        #expect(UserDefaults.pomodoroAlarmSoundID == "default")
    }

    @Test func healthKitEnabledDefaultsToFalse() {
        #expect(UserDefaults.healthKitEnabled == false)
    }

    @Test func hasBoughtPremiumDefaultsToFalse() {
        #expect(UserDefaults.hasBoughtPremium == false)
    }

    @Test func companionEnabledDefaultsToTrueWhenAbsent() {
        // This is the tri-state default: absent key means true.
        #expect(UserDefaults.companionEnabled == true)
    }

    @Test func companionNameDefaultsToEmptyString() {
        #expect(UserDefaults.companionName == "")
    }

    @Test func companionPersonalityIDDefaultsToOtto() {
        #expect(UserDefaults.companionPersonalityID == "otto")
    }

    @Test func roundTripBooleanProperties() {
        UserDefaults.hasCompletedOnboarding = true
        #expect(UserDefaults.hasCompletedOnboarding == true)
        UserDefaults.hasCompletedOnboarding = false
        #expect(UserDefaults.hasCompletedOnboarding == false)
    }

    @Test func roundTripStringProperties() {
        UserDefaults.pomodoroAlarmSoundID = "custom:foo"
        #expect(UserDefaults.pomodoroAlarmSoundID == "custom:foo")

        UserDefaults.companionName = "Ottie"
        #expect(UserDefaults.companionName == "Ottie")

        UserDefaults.companionPersonalityID = "goose"
        #expect(UserDefaults.companionPersonalityID == "goose")
    }

    @Test func resetOnboardingStateRemovesOnboardingKeysOnly() {
        UserDefaults.hasCompletedOnboarding = true
        UserDefaults.hasSeenSwipeGesturesTooltip = true
        UserDefaults.pomodoroAlarmSoundID = "custom:foo"

        UserDefaults.resetOnboardingState()

        #expect(UserDefaults.hasCompletedOnboarding == false)
        #expect(UserDefaults.hasSeenSwipeGesturesTooltip == false)
        #expect(UserDefaults.pomodoroAlarmSoundID == "custom:foo")
    }

    @Test func companionEnabledExplicitlyFalse() {
        UserDefaults.companionEnabled = false
        #expect(UserDefaults.companionEnabled == false)
    }
}

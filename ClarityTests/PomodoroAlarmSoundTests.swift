//
//  PomodoroAlarmSoundTests.swift
//  ClarityTests
//
//  Created by OpenCode on 09/08/2026.
//

import Foundation
import Testing
@testable import Clarity

struct PomodoroAlarmSoundTests {

    @Test func defaultSoundRoundTrip() {
        let original = PomodoroAlarmSound.default
        #expect(PomodoroAlarmSound.from(persistenceID: original.persistenceID) == original)
    }

    @Test func presetSoundRoundTrip() {
        for preset in PomodoroAlarmSound.allPresets {
            #expect(PomodoroAlarmSound.from(persistenceID: preset.persistenceID) == preset)
        }
    }

    @Test func customSoundRoundTrip() {
        let original = PomodoroAlarmSound.custom(filename: "my_sound.caf")
        #expect(PomodoroAlarmSound.from(persistenceID: original.persistenceID) == original)
    }

    @Test func unknownPersistenceIDFallsBackToDefault() {
        #expect(PomodoroAlarmSound.from(persistenceID: "totally-unknown") == .default)
        #expect(PomodoroAlarmSound.from(persistenceID: "") == .default)
    }

    @Test func emptyPresetNameIsPreserved() {
        // PINNED: a malformed "preset:" prefix yields a preset with an empty name.
        let id = "preset:"
        let decoded = PomodoroAlarmSound.from(persistenceID: id)
        #expect(decoded == .preset(name: ""))
        #expect(decoded != .default)
    }

    @Test func customWithoutPrefixIsNotDecoded() {
        // A bare filename without the "custom:" prefix is treated as unknown.
        #expect(PomodoroAlarmSound.from(persistenceID: "my_sound.caf") == .default)
    }

    @Test func displayNameForDefault() {
        #expect(PomodoroAlarmSound.default.displayName == "Default")
    }

    @Test func displayNameCapitalizesPreset() {
        #expect(PomodoroAlarmSound.preset(name: "chime").displayName == "Chime")
        #expect(PomodoroAlarmSound.preset(name: "bell").displayName == "Bell")
        #expect(PomodoroAlarmSound.preset(name: "ding").displayName == "Ding")
    }

    @Test func displayNameStripsCafExtension() {
        #expect(PomodoroAlarmSound.custom(filename: "pomodoro_bell.caf").displayName == "pomodoro_bell")
    }

    @Test func displayNameLeavesNonCafFilenameUnchanged() {
        #expect(PomodoroAlarmSound.custom(filename: "pomodoro_bell").displayName == "pomodoro_bell")
    }

    @Test func allPresetsContainsExpectedCases() {
        #expect(PomodoroAlarmSound.allPresets.count == 3)
        #expect(PomodoroAlarmSound.allPresets.contains(.preset(name: "chime")))
        #expect(PomodoroAlarmSound.allPresets.contains(.preset(name: "bell")))
        #expect(PomodoroAlarmSound.allPresets.contains(.preset(name: "ding")))
    }
}

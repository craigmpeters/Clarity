//
//  UserDefaults+Extensions.swift
//  Clarity
//
//  Created by AI Assistant on 07/09/2025.
//

import Foundation

extension UserDefaults {
    /// Tracks whether the user has completed the onboarding flow
    static var hasCompletedOnboarding: Bool {
        get {
            UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "hasCompletedOnboarding")
        }
    }
    
    /// Tracks whether the user has seen the swipe gestures tutorial
    static var hasSeenSwipeGesturesTooltip: Bool {
        get {
            UserDefaults.standard.bool(forKey: "hasSeenSwipeGesturesTooltip")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "hasSeenSwipeGesturesTooltip")
        }
    }
    
    /// The persistence ID of the selected Pomodoro alarm sound (see PomodoroAlarmSound)
    static var pomodoroAlarmSoundID: String {
        get {
            UserDefaults.standard.string(forKey: "pomodoroAlarmSoundID") ?? "default"
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "pomodoroAlarmSoundID")
        }
    }

    /// Reset onboarding state (useful for testing or user-requested reset)
    static func resetOnboardingState() {
        UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")
        UserDefaults.standard.removeObject(forKey: "hasSeenSwipeGesturesTooltip")
    }
}

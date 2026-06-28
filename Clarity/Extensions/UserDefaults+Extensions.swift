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

    /// Whether the user has opted in to HealthKit state-of-mind logging.
    static var healthKitEnabled: Bool {
        get {
            UserDefaults.standard.bool(forKey: "me.craigpeters.clarity.healthKitEnabled")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "me.craigpeters.clarity.healthKitEnabled")
        }
    }

    /// Cached premium purchase state. Used as the initial value on launch before
    /// StoreKit entitlements are verified. Always confirmed/overridden by StoreKit.
    static var hasBoughtPremium: Bool {
        get {
            UserDefaults.standard.bool(forKey: "me.craigpeters.clarity.hasBoughtPremium")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "me.craigpeters.clarity.hasBoughtPremium")
        }
    }

    /// Whether the otter companion is enabled.
    static var companionEnabled: Bool {
        get {
            // Default to true on first launch
            if UserDefaults.standard.object(forKey: "me.craigpeters.clarity.companionEnabled") == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: "me.craigpeters.clarity.companionEnabled")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "me.craigpeters.clarity.companionEnabled")
        }
    }

    /// The display name for the otter companion.
    static var companionName: String {
        get {
            UserDefaults.standard.string(forKey: "me.craigpeters.clarity.companionName") ?? "Otto"
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "me.craigpeters.clarity.companionName")
        }
    }

    /// Reset onboarding state (useful for testing or user-requested reset)
    static func resetOnboardingState() {
        UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")
        UserDefaults.standard.removeObject(forKey: "hasSeenSwipeGesturesTooltip")
    }
}

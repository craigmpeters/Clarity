//
//  UserDefaults+Extensions.swift
//  Clarity
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

    /// Whether the companion is enabled.
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

    /// The display name for the companion. Empty string means use the personality's default.
    static var companionName: String {
        get {
            UserDefaults.standard.string(forKey: "me.craigpeters.clarity.companionName") ?? ""
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "me.craigpeters.clarity.companionName")
        }
    }

    /// The ID of the selected companion personality (see CompanionPersonality.id).
    static var companionPersonalityID: String {
        get {
            UserDefaults.standard.string(forKey: "me.craigpeters.clarity.companionPersonalityID") ?? "otto"
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "me.craigpeters.clarity.companionPersonalityID")
        }
    }

    /// Reset onboarding state (useful for testing or user-requested reset)
    static func resetOnboardingState() {
        UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")
        UserDefaults.standard.removeObject(forKey: "hasSeenSwipeGesturesTooltip")
    }
}

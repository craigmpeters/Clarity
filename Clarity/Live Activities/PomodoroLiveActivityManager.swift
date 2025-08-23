// PomodoroLiveActivityManager.swift
// Fixed version for iOS 18+

import Foundation
import ActivityKit
import Combine

class PomodoroLiveActivityManager: ObservableObject {
    private var activity: Activity<PomodoroAttributes>?
    private var updateTimer: Timer?
    
    // MARK: - Start Live Activity
    func startLiveActivity(for pomodoro: Pomodoro) {
        print("DEBUG: Attempting to start Live Activity")
        
        // Check if Live Activities are enabled
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("ERROR: Live Activities are not enabled")
            return
        }
        
        // End any existing activity first
        if activity != nil {
            endLiveActivity()
        }
        
        // Create attributes and initial state
        let attributes = PomodoroAttributes(sessionId: UUID().uuidString)
        let contentState = createContentState(from: pomodoro)
        let activityContent = ActivityContent(state: contentState, staleDate: nil)
        
        print("DEBUG: Created activity content with state: \(contentState)")
        
        do {
            // Request the activity
            activity = try Activity<PomodoroAttributes>.request(
                attributes: attributes,
                content: activityContent
            )
            print("SUCCESS: Live Activity started with ID: \(activity?.id ?? "unknown")")
            
            // Start the update timer
            startUpdateTimer(for: pomodoro)
        } catch {
            print("ERROR: Failed to start live activity: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Update Live Activity (Synchronous for iOS 18)
    func updateLiveActivity(for pomodoro: Pomodoro) {
        guard let activity = activity else {
            print("WARNING: No active Live Activity to update")
            return
        }
        
        let contentState = createContentState(from: pomodoro)
        let updatedContent = ActivityContent(state: contentState, staleDate: nil)
        
        Task {
            do {
                // Try the async version with proper error handling
                await activity.update(updatedContent)
                print("SUCCESS: Live Activity updated")
            } catch {
                print("ERROR: Failed to update: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - End Live Activity
    func endLiveActivity() {
        print("DEBUG: Attempting to end Live Activity")
        
        // Stop the timer first
        updateTimer?.invalidate()
        updateTimer = nil
        
        guard let activity = activity else {
            print("WARNING: No active Live Activity to end")
            return
        }
        
        let finalState = activity.content.state
        let finalContent = ActivityContent(state: finalState, staleDate: Date())
        
        Task {
            do {
                await activity.end(finalContent, dismissalPolicy: .immediate)
                print("SUCCESS: Live Activity ended")
            } catch {
                print("ERROR: Failed to end: \(error.localizedDescription)")
            }
        }
        
        // Clear the reference
        self.activity = nil
    }
    
    // MARK: - Timer-based updates
    private func startUpdateTimer(for pomodoro: Pomodoro) {
        // Cancel any existing timer
        updateTimer?.invalidate()
        
        // Create a new timer that updates every second
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            // Only update if running
            if pomodoro.isRunning {
                self.updateLiveActivity(for: pomodoro)
            } else if pomodoro.remainingTime <= 0 {
                // End the activity if time is up
                self.endLiveActivity()
            }
        }
    }
    
    // MARK: - Helper to create content state
    private func createContentState(from pomodoro: Pomodoro) -> PomodoroAttributes.ContentState {
        return PomodoroAttributes.ContentState(
            remainingTime: pomodoro.remainingTime,
            totalTime: pomodoro.interval,
            isRunning: pomodoro.isRunning,
            taskTitle: pomodoro.taskTitle,
            startTime: pomodoro.endTime?.addingTimeInterval(-pomodoro.interval) ?? Date()
        )
    }
    
    // MARK: - Debug helper
    func debugActivityStatus() {
        if let activity = activity {
            print("=== LIVE ACTIVITY STATUS ===")
            print("ID: \(activity.id)")
            print("State: \(activity.activityState)")
            print("===========================")
        } else {
            print("No active Live Activity")
        }
    }
}

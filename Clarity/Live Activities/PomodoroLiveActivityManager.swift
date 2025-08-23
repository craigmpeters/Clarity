//
//  PomodoroLiveActivityManager.swift
//  Clarity
//
//  Created by Craig Peters on 23/08/2025.
//

import Foundation
import ActivityKit
import Combine

class PomodoroLiveActivityManager: ObservableObject {
    private var activity: Activity<PomodoroAttributes>?
    private var cancellables = Set<AnyCancellable>()
    
    func startLiveActivity(for pomodoro: Pomodoro) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("Live Activities are not enabled")
            return
        }
        
        let attributes = PomodoroAttributes(sessionId: UUID().uuidString)
        let contentState = createContentState(from: pomodoro)
        let activityContent = ActivityContent(state: contentState, staleDate: nil)
        
        do {
            activity = try Activity<PomodoroAttributes>.request(
                attributes: attributes,
                content: activityContent
            )
            print("Live Activity started successfully")
        } catch {
            print("Error starting live activity: \(error)")
        }
    }
    
    func updateLiveActivity(for pomodoro: Pomodoro) {
        guard let activity = activity else {
            print("Live activity not yet started")
            return
        }
        
        let contentState = createContentState(from: pomodoro)
        let activityContent = ActivityContent(state: contentState, staleDate: nil)
        
        Task {
            await activity.update(activityContent)
        }
    }
    
    func endLiveActivity() {
        guard let activity = activity else { return }
        
        Task {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        
        self.activity = nil
    }
    
    func observePomodoro(_ pomodoro: Pomodoro) {
        pomodoro.objectWillChange
            .sink { [weak self] _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self?.updateLiveActivity(for: pomodoro)
                }
            }
            .store(in: &cancellables)
    }
    
    private func createContentState(from pomodoro: Pomodoro) -> PomodoroAttributes.ContentState {
        return PomodoroAttributes.ContentState(
            remainingTime: pomodoro.remainingTime,
            totalTime: pomodoro.interval,
            isRunning: pomodoro.isRunning,
            taskTitle: pomodoro.taskTitle,
            startTime: pomodoro.endTime?.addingTimeInterval(-pomodoro.interval) ?? Date()
        )
    }
}

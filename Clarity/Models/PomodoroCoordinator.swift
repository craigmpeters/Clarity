//
//  PomodoroCoordinator.swift
//  Clarity
//
//  Created by Craig Peters on 25/08/2025.
//

import ActivityKit
import Combine
import Foundation
import UserNotifications
import BackgroundTasks

class PomodoroCoordinator: ObservableObject {
    @Published var pomodoro: Pomodoro
    let task: ToDoTask
    let toDoStore: ToDoStore
    
    private var activity: Activity<PomodoroAttributes>?
    private var hasEnded = false
    private var cancellables = Set<AnyCancellable>()
    
    init(pomodoro: Pomodoro, task: ToDoTask, toDoStore: ToDoStore) {
        print("Pomodoro Co-ordinator created for Task: \(task.name) for \(task.pomodoroTime) seconds")
        self.pomodoro = pomodoro
        self.task = task
        self.toDoStore = toDoStore
        
        pomodoro.objectWillChange
            .sink { [weak self] in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
            
        pomodoro.startPomodoro(task: task, description: "Timer is up!", interval: task.pomodoroTime)
        startLiveActivity(pomodoro: pomodoro)
    }
    
    func endPomodoro() {
        print("Pomodoro Ending for task: \(task.name)")
        guard !hasEnded else { return }
        hasEnded = true
        pomodoro.stopPomodoro()
        endLiveActivity()
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        toDoStore.completeToDoTask(toDoTask: task)
    }
    
    private func startLiveActivity(pomodoro: Pomodoro) {
        // Creates and starts the Live Activity
        guard pomodoro.endTime != nil else { return }
        let attributes = PomodoroAttributes(sessionId: UUID().uuidString)
        let contentState = PomodoroAttributes.ContentState(
            taskName: pomodoro.taskTitle,
            startTime: pomodoro.endTime!.addingTimeInterval(-pomodoro.interval),
            endTime: pomodoro.endTime!
        )
        let activityContent = ActivityContent(state: contentState, staleDate: pomodoro.endTime)
        
        do {
            activity = try Activity.request(
                attributes: attributes,
                content: activityContent,
                pushType: nil
            )
            print("SUCCESS: Live Activity started for task: \(pomodoro.taskTitle)")
        } catch {
            print("ERROR: Failed to start Live Activity: \(error.localizedDescription)")
        }
    }
    
    func endLiveActivity() {
        print("DEBUG: Attempting to end Live Activity")
        
        guard let activity = activity else {
            print("WARNING: No active Live Activity to end")
            return
        }
        
        Task {
            await activity.end(ActivityContent(state: activity.content.state, staleDate: nil), dismissalPolicy: .immediate)
        }
        
        // Clear the reference
        self.activity = nil
    }
}

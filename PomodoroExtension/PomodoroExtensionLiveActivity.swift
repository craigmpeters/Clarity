//
//  PomodoroExtensionLiveActivity.swift
//  PomodoroExtension
//
//  Created by Craig Peters on 21/08/2025.
//

import Foundation
import ActivityKit
import WidgetKit
import SwiftUI
import Combine

struct PomodoroAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var remainingTime: TimeInterval
        var totalTime: TimeInterval
        var isRunning: Bool
        var taskTitle: String
        var StartTime: Date
    }
    var sessionId: String
}

class PomodoroLiveActivityManager: ObservableObject {
    private var activity: Activity<PomodoroAttributes>?
    private var cancellables = Set<AnyCancellable>()
    
    func startLiveActivity(for pomodoro: Pomodoro) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print ("Activities are not enabled")
            return
        }
        
        let attributes = PomodoroAttributes(
            sessionId: UUID().uuidString
        )
        let contentState = createContentState(from: pomodoro)
        
        do {
            activity = try Activity<PomodoroAttributes>.request(
                attributes: attributes,
                contentState: contentState,
                pushType: nil
            )
            print("Live Activity started successfully")
        } catch {
            print("Error starting live activity: \(error)")
        }
    }
    
    func updateLiveActivity(for pomodoro: Pomodoro) {
        guard let activity else {
            print("Live activity not yet started")
            return
        }
        
        let contentState = createContentState(from: pomodoro)
        
        Task {
            await activity.update(using: contentState)
        }
    }
    
    func endLiveActivity() {
        guard let activity = activity else {
            return
        }
        
        Task {
            await activity.end(dismissalPolicy: .immediate)
        }
    }
    
    func observePomodoros(_ pomodoro: Pomodoro) {
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
            StartTime: pomodoro.endTime?.addingTimeInterval(-pomodoro.interval) ?? Date()
        )
    }
}

//
//struct PomodoroExtensionLiveActivity: Widget {
//    var body: some WidgetConfiguration {
//        ActivityConfiguration(for: PomodoroExtensionAttributes.self) { context in
//            // Lock screen/banner UI goes here
//            VStack {
//                Text("Hello \(context.state.emoji)")
//            }
//            .activityBackgroundTint(Color.cyan)
//            .activitySystemActionForegroundColor(Color.black)
//
//        } dynamicIsland: { context in
//            DynamicIsland {
//                // Expanded UI goes here.  Compose the expanded UI through
//                // various regions, like leading/trailing/center/bottom
//                DynamicIslandExpandedRegion(.leading) {
//                    Text("Leading")
//                }
//                DynamicIslandExpandedRegion(.trailing) {
//                    Text("Trailing")
//                }
//                DynamicIslandExpandedRegion(.bottom) {
//                    Text("Bottom \(context.state.emoji)")
//                    // more content
//                }
//            } compactLeading: {
//                Text("L")
//            } compactTrailing: {
//                Text("T \(context.state.emoji)")
//            } minimal: {
//                Text(context.state.emoji)
//            }
//            .widgetURL(URL(string: "http://www.apple.com"))
//            .keylineTint(Color.red)
//        }
//    }
//}
//
//extension PomodoroExtensionAttributes {
//    fileprivate static var preview: PomodoroExtensionAttributes {
//        PomodoroExtensionAttributes(name: "World")
//    }
//}
//
//extension PomodoroExtensionAttributes.ContentState {
//    fileprivate static var smiley: PomodoroExtensionAttributes.ContentState {
//        PomodoroExtensionAttributes.ContentState(emoji: "😀")
//     }
//     
//     fileprivate static var starEyes: PomodoroExtensionAttributes.ContentState {
//         PomodoroExtensionAttributes.ContentState(emoji: "🤩")
//     }
//}
//
//#Preview("Notification", as: .content, using: PomodoroExtensionAttributes.preview) {
//   PomodoroExtensionLiveActivity()
//} contentStates: {
//    PomodoroExtensionAttributes.ContentState.smiley
//    PomodoroExtensionAttributes.ContentState.starEyes
//}

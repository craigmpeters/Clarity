//
//  PomodoroView.swift
//  ClarityWatch
//
//  Created by Craig Peters on 28/09/2025.
//

import SwiftUI
import Foundation
import WatchConnectivity

#if os(watchOS)
import WatchKit
#endif

struct PomodoroView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    
    var pomodoro: PomodoroDTO
    var onDismiss: (() -> Void)?
    private let interval: TimeInterval

    
    private var remainingTime: TimeInterval {
        let remaining = pomodoro.endTime!.timeIntervalSinceNow
        return max(0, remaining)
    }
    
    private var formattedTime: String {
        let time = remainingTime
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private var progress: Double {
        guard interval > 0 else { return 0 }
        let value = 1.0 - (remainingTime / interval)
        return min(max(value, 0), 1)
    }
    
    // Use the watch's physical screen size to scale the ring
    private var deviceDiameter: CGFloat {
        #if os(watchOS)
        let bounds = WKInterfaceDevice.current().screenBounds
        let dimension = min(bounds.width, bounds.height)
        return dimension * 0.75
        #else
        return 200
        #endif
    }
    
    init(_ pomodoro: PomodoroDTO) {
        self.interval = pomodoro.toDoTask.pomodoroTime
        self.pomodoro = pomodoro
        // Timer stubbed out for now; no scheduled updates
    }
    
    var body: some View {
        VStack(spacing: 8) {
            TimelineView(.periodic(from: .now, by: 1)) { _ in
                ZStack {
                    if scenePhase == .active {
                        // Background circle
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 12)
                        .frame(width: deviceDiameter, height: deviceDiameter)
                    
                    // Progress circle
                    
                        Circle()
                            .trim(from: 0, to: progress)
                            .stroke(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                style: StrokeStyle(lineWidth: 12, lineCap: .round)
                            )
                            .frame(width: deviceDiameter, height: deviceDiameter)
                            .rotationEffect(.degrees(-90))
                            .animation(.linear(duration: 1), value: progress)
                    }

                    
                    // Timer text
                    VStack {
                        Text(pomodoro.endTime ?? .now, style: .timer)
                            .font(.system(size: 38, weight: .bold, design: .monospaced))
                            .foregroundColor(.primary)
                        Button(action: {
                            // Send stopPomodoro to the phone
                            print("Attempting to Stop Pomodoro for \(pomodoro.toDoTask.name)")
                            let env = Envelope(kind: WCKeys.Requests.stopPomodoro, pomodoro: pomodoro)
                            let encoder = JSONEncoder()
                            
                            guard let data = try? encoder.encode(env) else { return }
                            let message: [String: Any] = [WCKeys.request: WCKeys.Requests.stopPomodoro, WCKeys.payload: data]
                            
                            let session = WCSession.default
                            if session.activationState == .activated, session.isReachable {
                                session.sendMessage(message, replyHandler: { _ in
                                    print("Sent stopPomodoro...")
                                    // ack received
                                }, errorHandler: { error in
                                    // Fall back to reliable transfer
                                    session.transferUserInfo([WCKeys.payload: data])
                                    print("⚠️ stopPomodoro immediate send failed; queued reliable. Error: \(error)")
                                })
                            } else {
                                // Not reachable; queue reliable
                                session.transferUserInfo([WCKeys.payload: data])
                            }
                            dismiss()
                        }) {
                            Image(systemName: "stop.fill")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 44, height: 44)
                                .contentShape(Circle())
                                .background(
                                    Circle().fill(Color.red)
                                )
                        }
                        .accessibilityLabel("Stop")
                        .buttonStyle(.plain)

                    }
                }
            }
            Text(pomodoro.toDoTask.name)
                .font(.caption2.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.9)
                .allowsTightening(true)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(10)
        }
        .onReceive(NotificationCenter.default.publisher(for: .pomodoroCompleted)) { _ in
            print("⌚️ Pomodoro View Dismissing... ")
            dismiss()
        }
    }
}

#Preview {
    // Provide a lightweight DTO preview if available in your project
    // let sample = ToDoTaskDTO(id: "preview-id", name: "Sample Task", pomodoroTime: 1500, due: .now, categories: [])
    // PomodoroView(task: sample)
    Text("")
}

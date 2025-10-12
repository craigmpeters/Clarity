//
//  PomodoroView.swift
//  ClarityWatch
//
//  Created by Craig Peters on 28/09/2025.
//

import SwiftUI
import Foundation

#if os(watchOS)
import WatchKit
#endif

struct PomodoroView: View {
    var task: ToDoTaskDTO
    
    // Stubbed timer: keep static values for now
    private let interval: TimeInterval
    private let endTime: Date
    
    private var remainingTime: TimeInterval {
        let remaining = endTime.timeIntervalSinceNow
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
        return dimension * 0.85
        #else
        return 200
        #endif
    }
    
    init(task: ToDoTaskDTO) {
        self.task = task
        self.interval = task.pomodoroTime
        self.endTime = Date.now.addingTimeInterval(self.interval)
        // Timer stubbed out for now; no scheduled updates
    }
    
    var body: some View {
        VStack(spacing: 8) {
            Text(task.name)
                .font(.caption2.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.9)
                .allowsTightening(true)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(10)
            TimelineView(.periodic(from: .now, by: 1)) { _ in
                ZStack {
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
                    
                    // Timer text
                    VStack {
                        Text(formattedTime)
                            .font(.system(size: 42, weight: .bold, design: .monospaced))
                            .foregroundColor(.primary)
                        Button(action: {
                            //
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
        }
    }
}

#Preview {
    // Provide a lightweight DTO preview
   // let sample = ToDoTaskDTO(id: "preview-id", name: "Sample Task", pomodoroTime: 1500, due: .now, categories: [])
   // PomodoroView(task: sample)
}

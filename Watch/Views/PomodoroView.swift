//
//  PomodoroView.swift
//  ClarityWatch
//
//  Created by Craig Peters on 28/09/2025.
//

import SwiftUI
import Foundation
import WatchKit
import XCGLogger

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

    private var deviceDiameter: CGFloat {
        let bounds = WKInterfaceDevice.current().screenBounds
        let dimension = min(bounds.width, bounds.height)
        return dimension * 0.75
    }

    init(_ pomodoro: PomodoroDTO) {
        self.interval = pomodoro.toDoTask.pomodoroTime
        self.pomodoro = pomodoro
    }

    var body: some View {
        VStack(spacing: 8) {
            TimelineView(.periodic(from: .now, by: 1)) { _ in
                ZStack {
                    if scenePhase == .active {
                        Circle()
                            .stroke(Color.gray.opacity(0.3), lineWidth: 12)
                            .frame(width: deviceDiameter, height: deviceDiameter)

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

                    VStack {
                        Text(pomodoro.endTime ?? .now, style: .timer)
                            .font(.system(size: 38, weight: .bold, design: .monospaced))
                            .foregroundColor(.primary)
                        Button(action: {
                            LogManager.shared.log.debug("Attempting to Stop Pomodoro for \(pomodoro.toDoTask.name)")
                            WatchSnapshotStore.shared.stopPomodoro()
                            dismiss()
                        }) {
                            Image(systemName: "stop.fill")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 44, height: 44)
                                .contentShape(Circle())
                                .background(Circle().fill(Color.red))
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
            LogManager.shared.log.debug("⌚️ Pomodoro View Dismissing... ")
            dismiss()
        }
        .onAppear {
            if let end = pomodoro.endTime, end <= Date() {
                dismiss()
            }
        }
    }
}

#Preview {
    Text("")
}

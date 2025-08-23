
import SwiftUI
import SwiftData
import ActivityKit

struct PomodoroView: View {
    @ObservedObject var pomodoro: Pomodoro
    @Query private var tasks: [ToDoTask]
    @Environment(\.modelContext) private var context
    @State var task: ToDoTask
    @StateObject private var liveActivityManager = PomodoroLiveActivityManager()
    @State private var taskDescription = ""
    
    var body: some View {
        VStack(spacing: 30) {
            VStack(spacing: 8) {
                Text(task.name)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                if !taskDescription.isEmpty {
                    Text(taskDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal)
            
            VStack(spacing: 20) {
                ZStack {
                    // Background circle
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 12)
                        .frame(width: 250, height: 250)
                    
                    // Progress circle
                    Circle()
                        .trim(from: 0, to: pomodoro.progress)
                        .stroke(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 12, lineCap: .round)
                        )
                        .frame(width: 250, height: 250)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 1), value: pomodoro.progress)
                    
                    // Timer text
                    VStack {
                        Text(pomodoro.formattedTime)
                            .font(.system(size: 42, weight: .bold, design: .monospaced))
                            .foregroundColor(.primary)
                        
                        Text(statusText)
                            .font(.caption)
                            .foregroundColor(statusColor)
                    }
                }
                
                // Control buttons
                HStack(spacing: 20) {
                    if !pomodoro.isRunning && pomodoro.remainingTime == pomodoro.interval {
                        // Start button
                        Button(action: {
                            pomodoro.startPomodoro(taskTitle: task.name, description: taskDescription.isEmpty ? "Time to focus!" : taskDescription)
                            liveActivityManager.startLiveActivity(for: pomodoro)
                        }) {
                            Label("Start", systemImage: "play.fill")
                                .font(.title3)
                                .frame(width: 100, height: 44)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                    } else if pomodoro.isRunning {
                        // Pause button
                        Button(action: {
                            pomodoro.pausePomodoro()
                        }) {
                            Label("Pause", systemImage: "pause.fill")
                                .font(.title3)
                                .frame(width: 100, height: 44)
                                .background(Color.orange)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                    } else if !pomodoro.isRunning && pomodoro.remainingTime > 0 {
                        // Resume button
                        Button(action: {
                            pomodoro.resumePomodoro()
                        }) {
                            Label("Resume", systemImage: "play.fill")
                                .font(.title3)
                                .frame(width: 100, height: 44)
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                    }
                    
                    // Stop button (always visible when timer is active)
                    if pomodoro.remainingTime < pomodoro.interval && pomodoro.remainingTime > 0 {
                        Button(action: {
                            pomodoro.stopPomodoro()
                            liveActivityManager.endLiveActivity()
                        }) {
                            Label("Stop", systemImage: "stop.fill")
                                .font(.title3)
                                .frame(width: 100, height: 44)
                                .background(Color.red)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                    }
                }
            }
        }
        .padding()
        .onAppear {
        }
        .onDisappear {
            context.delete(task)
            pomodoro.stopPomodoro()
            liveActivityManager.endLiveActivity()
        }
    }
    
    private var statusText: String {
        if pomodoro.isRunning {
            return "running"
        } else if pomodoro.remainingTime > 0 && pomodoro.remainingTime < pomodoro.interval {
            return "paused"
        } else if pomodoro.remainingTime <= 0 {
            return "completed"
        } else {
            return "ready"
        }
    }
    
    private var statusColor: Color {
        switch statusText {
        case "running": return .green
        case "paused": return .orange
        case "completed": return .blue
        default: return .secondary
        }
    }
}

import SwiftUI
import SwiftData

// Pomodoro class definition

struct PomodoroView: View {
    @ObservedObject var pomodoro: Pomodoro
    @Query private var tasks: [Task]
    @Environment(\.modelContext) private var context
    @State var task : Task
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
                        .rotationEffect(.degrees(-90)) // Start from top
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
            }
        }
        .padding()
        .onAppear {
            pomodoro.taskTitle = task.name
            liveActivityManager.observePomodoros(pomodoro)
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
    
    // MARK: - Computed Properties
    
    
    
    // MARK: - Timer Functions
    
}


#Preview {
    var task = Task(name: "Test Task")
    var pomodoro = Pomodoro()
    PomodoroView(pomodoro: pomodoro, task: task)
        .modelContainer(for: Task.self, inMemory: true)
}

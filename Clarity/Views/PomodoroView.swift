
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
                Text(pomodoro.taskTitle)
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
                    }
                }
            }
        }
        .padding()
        .onAppear {
        }
        .onDisappear {
            liveActivityManager.endLiveActivity()
            pomodoro.stopPomodoro()
            context.delete(task)
        }
    }
}

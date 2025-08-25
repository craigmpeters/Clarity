import ActivityKit
import SwiftData
import SwiftUI

struct PomodoroView: View {
    @StateObject private var coordinator: PomodoroCoordinator
    @Environment(\.dismiss) private var dismiss
    
    private var pomodoro: Pomodoro {
        coordinator.pomodoro
    }
    
    init(task: ToDoTask, toDoStore: ToDoStore) {
        let pomodoro = Pomodoro()
        self._coordinator = StateObject(wrappedValue: PomodoroCoordinator(pomodoro: pomodoro, task: task, toDoStore: toDoStore))
    }
    
    var body: some View {
        VStack(spacing: 30) {
            VStack(spacing: 8) {
                Text(pomodoro.taskTitle)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
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
            if coordinator.pomodoro.remainingTime <= 0 && coordinator.pomodoro.endTime != nil {
                coordinator.endPomodoro()
                dismiss()
            }
        }
        .onDisappear {
            coordinator.endPomodoro()
        }
    }
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: ToDoTask.self, configurations: config)
    
    let sampleTask = ToDoTask(name: "Sample Pomodoro Task", pomodoro: true, pomodoroTime: 20) // 20 Seconds
    container.mainContext.insert(sampleTask)
    
    let toDoStore = ToDoStore(modelContext: container.mainContext)
    
    return PomodoroView(task: sampleTask, toDoStore: toDoStore)
        .modelContainer(container)
}

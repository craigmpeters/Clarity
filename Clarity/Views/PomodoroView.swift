import SwiftUI
import SwiftData

// Pomodoro class definition

struct PomodoroView: View {
    @ObservedObject var pomodoro: Pomodoro
    @Query private var tasks: [Task]
    @Environment(\.modelContext) private var context
    @State private var timeRemaining: TimeInterval = 0
    @State private var timer: Timer?
    @State var task : Task
    
    var body: some View {
        VStack(spacing: 20) {
            Text(task.name)
            ZStack {
                // Background circle
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 8)
                    .frame(width: 200, height: 200)
                
                // Progress circle
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 200, height: 200)
                    .rotationEffect(.degrees(-90)) // Start from top
                    .animation(.linear(duration: 0.1), value: progress)
                
                // Timer text
                VStack {
                    Text(formattedTime)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text("remaining")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .onAppear {
            setupTimer()
        }
        .onDisappear {
            context.delete(task)
        }
    }
    
    // MARK: - Computed Properties
    
    private var progress: Double {
        guard pomodoro.interval > 0 else { return 0 }
        let remainingRatio = timeRemaining / pomodoro.interval
        return max(0, min(1, remainingRatio))
    }
    
    private var formattedTime: String {
        let minutes = Int(timeRemaining) / 60
        let seconds = Int(timeRemaining) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    // MARK: - Timer Functions
    
    private func setupTimer() {
        timer?.invalidate()
        
        if let endTime = pomodoro.endTime {
            timeRemaining = max(0, endTime.timeIntervalSinceNow)
            
            timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                updateTimer()
            }
        } else {
            timeRemaining = pomodoro.interval
        }
    }
    
    private func updateTimer() {
        guard let endTime = pomodoro.endTime else {
            timer?.invalidate()
            return
        }
        
        timeRemaining = max(0, endTime.timeIntervalSinceNow)
        
        if timeRemaining <= 0 {
            timer?.invalidate()
            pomodoro.endTime = nil
            // Timer completed - you can add completion logic here
        }
    }
}


#Preview {
    var task = Task(name: "Test Task")
    var pomodoro = Pomodoro()
    PomodoroView(pomodoro: pomodoro, task: task)
        .modelContainer(for: Task.self, inMemory: true)
}

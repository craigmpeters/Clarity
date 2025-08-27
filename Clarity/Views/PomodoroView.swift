import ActivityKit
import SwiftData
import SwiftUI

struct PomodoroView: View {
    @StateObject private var coordinator: PomodoroCoordinator
    @Binding var showingPomodoro: Bool
    
    private var pomodoro: Pomodoro {
        coordinator.pomodoro
    }
    
    init(task: ToDoTask, toDoStore: ToDoStore, showingPomodoro: Binding<Bool>) {
        let pomodoro = Pomodoro()
        self._coordinator = StateObject(wrappedValue: PomodoroCoordinator(pomodoro: pomodoro, task: task, toDoStore: toDoStore))
        self._showingPomodoro = showingPomodoro
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Custom navigation bar
            HStack {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showingPomodoro = false
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Back")
                            .font(.system(size: 17, weight: .regular))
                    }
                    .foregroundColor(.blue)
                }
                
                Spacer()
                
                Text("Focus Timer")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Placeholder for balance
                Button(action: {}) {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.blue)
                }
                .opacity(0) // Hidden but maintains layout
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.regularMaterial)
            .overlay(
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 1),
                alignment: .bottom
            )
            
            // Main content
            VStack(spacing: 30) {
                VStack(spacing: 8) {
                    Text(pomodoro.taskTitle)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal)
                .padding(.top, 40)
                
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
                
                // Control buttons
                VStack(spacing: 16) {
                    let isCompleted = coordinator.pomodoro.currentRemainingTime <= 0 && !coordinator.pomodoro.isRunning
                    
                    // Dynamic button based on timer state
                    Button(action: {
                        coordinator.endPomodoro()
                        if isCompleted {
                            // Timer completed - mark task as finished
                            // Add your task completion logic here if needed
                        }
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showingPomodoro = false
                        }
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: isCompleted ? "checkmark.circle.fill" : "stop.circle")
                                .font(.system(size: 20, weight: .medium))
                            Text(isCompleted ? "Finish Task" : "Stop Timer")
                                .font(.system(size: 17, weight: isCompleted ? .semibold : .medium))
                        }
                        .foregroundColor(isCompleted ? .white : .red)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            Group {
                                if isCompleted {
                                    LinearGradient(
                                        colors: [.green, .mint],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                } else {
                                    Rectangle()
                                        .fill(.regularMaterial)
                                }
                            }
                        )
                        .cornerRadius(25)
                        .overlay(
                            isCompleted ? nil :
                            RoundedRectangle(cornerRadius: 25)
                                .stroke(.red.opacity(0.3), lineWidth: 1)
                        )
                        .shadow(
                            color: isCompleted ? .green.opacity(0.3) : .clear,
                            radius: 8,
                            x: 0,
                            y: 4
                        )
                    }
                    .animation(.easeInOut(duration: 0.3), value: isCompleted)
                }
                .padding(.horizontal, 40)
                
                Spacer(minLength: 40)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemBackground))
        }
        .background(Color(.systemBackground))
        .ignoresSafeArea(.container, edges: .top)
        .onAppear {
            if coordinator.pomodoro.remainingTime <= 0 && coordinator.pomodoro.endTime != nil {
                coordinator.endPomodoro()
                withAnimation(.easeInOut(duration: 0.3)) {
                    showingPomodoro = false
                }
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
    
    return PomodoroView(
        task: sampleTask,
        toDoStore: toDoStore,
        showingPomodoro: .constant(true)
    )
    .modelContainer(container)
}

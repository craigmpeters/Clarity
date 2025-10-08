import ActivityKit
import SwiftData
import SwiftUI

struct PomodoroView: View {
    @Environment(\.modelContext) private var context
    @StateObject private var coordinator: PomodoroCoordinator
    @Binding var showingPomodoro: Bool
    
    private var pomodoro: Pomodoro {
        coordinator.pomodoro
    }
    
    init(task: ToDoTaskDTO, showingPomodoro: Binding<Bool>, container: ModelContainer) {
        let pomodoro = Pomodoro()
        _coordinator = StateObject(wrappedValue: PomodoroCoordinator(pomodoro: pomodoro, task: task, container: container))
        _showingPomodoro = showingPomodoro
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
                        Task {
                            try await coordinator.endPomodoro()
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
                Task {
                    try await coordinator.endPomodoro()
                }
                withAnimation(.easeInOut(duration: 0.3)) {
                    showingPomodoro = false
                }
            }
        }
        .onDisappear {
            Task {
                try await coordinator.endPomodoro()
            }
            
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    PomodoroView(
        task: PreviewData.shared.getToDoTaskDTO(),
        showingPomodoro: .constant(true),
        container: PreviewData.shared.previewContainer
    )
    .modelContainer(PreviewData.shared.previewContainer)
}
#endif

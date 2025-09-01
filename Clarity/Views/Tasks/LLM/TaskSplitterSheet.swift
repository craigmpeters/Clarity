import SwiftUI
import SwiftData

@available(iOS 26.0, *)
struct TaskSplitterSheet: View {
    let taskName: String
    @Bindable var toDoStore: ToDoStore
    @Binding var isPresented: Bool
    
    @StateObject private var splitter = TaskSplitterService()
    @State private var suggestions: [SplitTaskSuggestion] = []
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Label("Split into subtasks", systemImage: "scissors")
                        .font(.headline)
                    Text("AI will suggest smaller, manageable tasks")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.systemBackground))
                
                Divider()
                
                // Content
                if splitter.isProcessing {
                    Spacer()
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Analyzing task...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                } else if !suggestions.isEmpty {
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach($suggestions) { $suggestion in
                                SuggestionRow(suggestion: $suggestion)
                            }
                        }
                        .padding()
                    }
                } else if let error = splitter.error {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundStyle(.orange)
                        Text("Unable to generate suggestions")
                            .font(.headline)
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    Spacer()
                }
                
                Divider()
                
                Text(splitter.appleIntelligenceResponse?.debugDescription ?? "No additional information available")
                
                Divider()
                
                // Actions
                HStack(spacing: 12) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    
                    Spacer()
                    
                    if !suggestions.isEmpty {
                        Text("\(suggestions.filter(\.isSelected).count) selected")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Button("Create Tasks") {
                        createSelectedTasks()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(suggestions.filter(\.isSelected).isEmpty)
                }
                .padding()
                .background(Color(.secondarySystemBackground))
            }
            .navigationTitle("Task: \(taskName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Regenerate") {
                        Task {
                            await splitter.splitTask(taskName)
                            suggestions = splitter.suggestions
                        }
                    }
                    .disabled(splitter.isProcessing)
                }
            }
        }
        .task {
            await splitter.splitTask(taskName)
            suggestions = splitter.suggestions
        }
    }
    
    private func createSelectedTasks() {
        let selected = suggestions.filter(\.isSelected)
        
        for (index, suggestion) in selected.enumerated() {
            let dueDate = Calendar.current.date(
                byAdding: .day,
                value: index,
                to: Date()
            ) ?? Date()
            
            let task = ToDoTask(
                name: suggestion.name,
                pomodoroTime: TimeInterval(suggestion.estimatedMinutes * 60),
                due: dueDate
            )
            
            toDoStore.addTodoTask(toDoTask: task)
        }
        
        dismiss()
    }
}

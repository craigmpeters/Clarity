import SwiftData
import SwiftUI

@available(iOS 26.0, *)
struct TaskSplitterSheet: View {
    
    // Swiftdata Queries
    @Query private var allCategories: [Category]
    @Query private var allTasks: [ToDoTask]
    
    let taskName: String
    @Binding var isPresented: Bool
    
    @StateObject private var splitter = TaskSplitterService()
    @State private var suggestions: [SplitTaskSuggestion] = []
    @Environment(\.dismiss) private var dismiss
    
    @State private var applyCategoriesToAll = false
    @State private var globalCategories: [CategoryDTO] = []
    @State private var store: ClarityModelActor?
    
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
                // Category application toggle
                if !allCategories.isEmpty && !suggestions.isEmpty {
                    VStack(spacing: 12) {
                        Toggle("Apply categories to all tasks", isOn: $applyCategoriesToAll)
                            .font(.subheadline)
                        
                        if applyCategoriesToAll {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(allCategories) {  category in
                                        CategoryChip(
                                            category: category,
                                            isSelected: globalCategories.contains { $0.id == category.id }
                                        ) {
                                            toggleGlobalCategory(CategoryDTO(from: category))
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    
                    Divider()
                }
                
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
                                SuggestionRow(suggestion: $suggestion,
                                              allCategories: allCategories,
                                              applyGlobalCategories: applyCategoriesToAll,
                                              globalCategories: globalCategories)
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
                        Task {
                            await createSelectedTasks()
                        }
                        
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
            if store == nil {
                store = await AppServices.store()
            }
            await splitter.splitTask(taskName)
            suggestions = splitter.suggestions
        }
    }
    
    private func createSelectedTasks() async {
        let selected = suggestions.filter(\.isSelected)
            
        for (index, suggestion) in selected.enumerated() {
            let dueDate = Calendar.current.date(
                byAdding: .day,
                value: index,
                to: Date()
            ) ?? Date()
                
            let task = ToDoTaskDTO(
                name: suggestion.name,
                pomodoroTime: TimeInterval(suggestion.estimatedMinutes * 60),
                due: dueDate,
                categories: applyCategoriesToAll ? globalCategories : suggestion.selectedCategories
            )
            _ = try? await store?.addTask(task)
        }
        
        await MainActor.run { dismiss() }
    }

    private func toggleGlobalCategory(_ category: CategoryDTO) {
        if let index = globalCategories.firstIndex(where: { $0.id == category.id }) {
            globalCategories.remove(at: index)
        } else {
            globalCategories.append(category)
        }
        
        // Update all selected suggestions with global categories
        for index in suggestions.indices where suggestions[index].isSelected {
            suggestions[index].selectedCategories = globalCategories
        }
    }
}


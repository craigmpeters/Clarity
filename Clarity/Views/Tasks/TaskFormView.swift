//
//  TaskFormView.swift
//  Clarity
//
//  Created by Craig Peters on 29/08/2025.
//

import SwiftData
import SwiftUI
#if canImport(FoundationModels)
import FoundationModels
#endif

struct TaskFormView: View {
    @Bindable var toDoStore: ToDoStore
    @Environment(\.dismiss) private var dismiss
    
    let editingTask: ToDoTask?
    @State private var toDoTask: ToDoTask
    @State private var selectedCategories: [Category] = []
    @State private var selectedRecurrence: ToDoTask.RecurrenceInterval = .daily
    @State private var customDays: Int = 1
    
    private var isEditing: Bool {
        editingTask != nil
    }
    
    init(toDoStore: ToDoStore, task: ToDoTask? = nil) {
        self.toDoStore = toDoStore
        self.editingTask = task
        
        if let task = task {
            self._toDoTask = State(initialValue: task)
            self._selectedCategories = State(initialValue: task.categories)
            self._selectedRecurrence = State(initialValue: task.recurrenceInterval ?? .daily)
            self._customDays = State(initialValue: task.customRecurrenceDays)
        } else {
            self._toDoTask = State(initialValue: ToDoTask(name: ""))
            self._selectedCategories = State(initialValue: [])
            self._selectedRecurrence = State(initialValue: .daily)
            self._customDays = State(initialValue: 1)
        }
    }
    
    private func saveTask() {
        withAnimation(.easeInOut(duration: 0.2)) {
            toDoTask.categories = selectedCategories
            
            // Set recurrence properties
            if toDoTask.repeating {
                toDoTask.recurrenceInterval = selectedRecurrence
                toDoTask.customRecurrenceDays = customDays
            } else {
                toDoTask.recurrenceInterval = nil
            }
            
            if isEditing {
                toDoStore.saveContext()
            } else {
                toDoStore.addTodoTask(toDoTask: toDoTask)
            }
        }
        dismiss()
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Task Details") {
                    TextField("Task name", text: $toDoTask.name)
                        .textFieldStyle(.roundedBorder)
                }
                if #available(iOS 26.0, *) {
                    aiSplitterSection
                }
                
                Section("Task Settings") {
                    HStack {
                        Image(systemName: "timer")
                            .foregroundStyle(.orange)
                        Text("Duration")
                        Spacer()
                        MinutePickerView(selectedTimeInterval: $toDoTask.pomodoroTime)
                    }
                    
                    Toggle(isOn: $toDoTask.repeating) {
                        HStack {
                            Image(systemName: "repeat")
                                .foregroundStyle(.blue)
                            Text("Repeating Task")
                        }
                    }
                    
                    // Show recurrence options when repeating is enabled
                    if toDoTask.repeating {
                        // Recurrence interval picker
                        Picker(selection: $selectedRecurrence) {
                            ForEach(ToDoTask.RecurrenceInterval.allCases, id: \.self) { interval in
                                Text(interval.displayName)
                                    .tag(interval)
                            }
                        } label: {
                            HStack {
                                Image(systemName: "calendar.badge.clock")
                                    .foregroundStyle(.purple)
                                Text("Repeat Interval")
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(maxHeight: 120)
                        
                        // Show custom days input if custom is selected
                        if selectedRecurrence == .custom {
                            HStack {
                                Image(systemName: "calendar.badge.plus")
                                    .foregroundStyle(.indigo)
                                Text("Every")
                                
                                TextField("Days", value: $customDays, format: .number)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 60)
                                    .keyboardType(.numberPad)
                                    .onChange(of: customDays) { _, newValue in
                                        // Ensure at least 1 day
                                        if newValue < 1 {
                                            customDays = 1
                                        }
                                    }
                                
                                Text(customDays == 1 ? "day" : "days")
                                Spacer()
                            }
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                        
                        // Preview of next occurrence
                        if let nextDate = getNextOccurrenceDate() {
                            HStack {
                                Image(systemName: "arrow.right.circle.fill")
                                    .foregroundStyle(.green)
                                Text("Next occurrence")
                                Spacer()
                                Text(nextDate, style: .date)
                                    .foregroundStyle(.secondary)
                            }
                            .font(.subheadline)
                            .padding(.vertical, 4)
                        }
                    }
                    
                    CategorySelectionView(selectedCategories: $selectedCategories)
                }
            }
            .navigationTitle(isEditing ? "Edit Task" : "Add Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isEditing ? "Save" : "Add") {
                        saveTask()
                    }
                    .disabled(toDoTask.name.isEmpty)
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    private func getNextOccurrenceDate() -> Date? {
        guard toDoTask.repeating else { return nil }
        
        if selectedRecurrence == .custom {
            return Calendar.current.date(byAdding: .day, value: customDays, to: toDoTask.due)
        } else {
            return selectedRecurrence.nextDate(from: toDoTask.due)
        }
    }
}

@available(iOS 26.0, *)
extension TaskFormView {

    @ViewBuilder
    var aiSplitterSection: some View {
        if #available(iOS 26.0, *) {
            if (SystemLanguageModel.default.isAvailable) {
                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Need help breaking this down?")
                                .font(.subheadline)
                            Text("AI can suggest subtasks")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        TaskSplitterView(
                            taskName: $toDoTask.name,
                            toDoStore: toDoStore
                        )
                        .disabled(toDoTask.name.isEmpty)
                    }
                } footer: {
                    Text("Requires iOS 26 or later • Powered by Apple Intelligence")
                        .font(.caption2)
                }
            } else if (SystemLanguageModel.default.availability == .unavailable(.modelNotReady)) {
                Section {
                    HStack {
                        Label("Apple Intelligence has not finished downloading. Come back soon for the ability to split tasks", systemImage: "apple.intelligence")
                        .font(.caption2)
                        
                    }
                }
            }
            
        }
    }
}

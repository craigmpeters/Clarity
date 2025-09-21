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
    @Environment(\.dismiss) private var dismiss
    
    let editingTask: ToDoTask?
    @State private var toDoTask: ToDoTask
    @State private var selectedCategories: [Category] = []
    @State private var selectedRecurrence: ToDoTask.RecurrenceInterval = .daily
    @State private var customDays: Int = 1
    @State private var dueDate: Date = Date()
    @State private var showingDatePicker = false
    
    private var isEditing: Bool {
        editingTask != nil
    }
    
    init(task: ToDoTask? = nil) {
        self.editingTask = task
        
        if let task = task {
            self._toDoTask = State(initialValue: task)
            self._selectedCategories = State(initialValue: task.categories ?? [])
            self._selectedRecurrence = State(initialValue: task.recurrenceInterval ?? .daily)
            self._customDays = State(initialValue: task.customRecurrenceDays)
            self._dueDate = State(initialValue: task.due)
        } else {
            self._toDoTask = State(initialValue: ToDoTask(name: ""))
            self._selectedCategories = State(initialValue: [])
            self._selectedRecurrence = State(initialValue: .daily)
            self._customDays = State(initialValue: 1)
            self._dueDate = State(initialValue: Date())
        }
    }
    
    private func saveTask() {
        withAnimation(.easeInOut(duration: 0.2)) {
            toDoTask.categories = selectedCategories
            toDoTask.due = dueDate
            // Set recurrence properties
            if toDoTask.repeating ?? false {
                toDoTask.recurrenceInterval = selectedRecurrence
                toDoTask.customRecurrenceDays = customDays
            } else {
                toDoTask.recurrenceInterval = nil
            }
            
            if !isEditing {
                Task {
                    await SharedDataActor.shared.addTodoTask(toDoTask: toDoTask)
                }
            }
        }
        dismiss()
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Task Details") {
                    TextField("Task name", text: Binding<String>(
                        get: { toDoTask.name ?? ""},
                        set: { toDoTask.name = $0.isEmpty ? nil : $0}
                    ))
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
                    
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundStyle(.red)
                        Text("Start Date")
                        Spacer()
                                            
                        Button(action: { showingDatePicker.toggle() }) {
                            HStack(spacing: 4) {
                                Text(formatDate(dueDate))
                                    .foregroundStyle(isOverdue ? .red : .primary)
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                                        
                    // Expanded date picker
                    if showingDatePicker {
                        DatePicker(
                            "Select Date",
                            selection: $dueDate,
                            in: Date()...,
                            displayedComponents: [.date]
                        )
                        .datePickerStyle(.graphical)
                        .labelsHidden()
                                            
                        // Quick date options
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                QuickDateButton(title: "Today", date: Date(), selectedDate: $dueDate)
                                QuickDateButton(title: "Tomorrow", date: Date().addingTimeInterval(86400), selectedDate: $dueDate)
                                QuickDateButton(title: "In 3 Days", date: Date().addingTimeInterval(86400 * 3), selectedDate: $dueDate)
                                QuickDateButton(title: "Next Week", date: Date().addingTimeInterval(86400 * 7), selectedDate: $dueDate)
                                QuickDateButton(title: "In 2 Weeks", date: Date().addingTimeInterval(86400 * 14), selectedDate: $dueDate)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    
                    Toggle(isOn: Binding<Bool>(
                        get: { self.toDoTask.repeating ?? false },
                        set: { self.toDoTask.repeating = $0 }
                    )) {
                        HStack {
                            Image(systemName: "repeat")
                                .foregroundStyle(.blue)
                            Text("Repeating Task")
                        }
                    }
                    
                    // Show recurrence options when repeating is enabled
                    if toDoTask.repeating ?? false {
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
                    .disabled(toDoTask.name?.isEmpty ?? true)
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    private func getNextOccurrenceDate() -> Date? {
        guard toDoTask.repeating ?? false else { return nil }
        
        if selectedRecurrence == .custom {
            return Calendar.current.date(byAdding: .day, value: customDays, to: dueDate)
        } else {
            return selectedRecurrence.nextDate(from: dueDate)
        }
    }
    
    private var isOverdue: Bool {
            dueDate < Calendar.current.startOfDay(for: Date())
        }
        
        private func formatDate(_ date: Date) -> String {
            let calendar = Calendar.current
            
            if calendar.isDateInToday(date) {
                return "Today"
            } else if calendar.isDateInTomorrow(date) {
                return "Tomorrow"
            } else if calendar.isDate(date, equalTo: Date(), toGranularity: .weekOfYear) {
                let formatter = DateFormatter()
                formatter.dateFormat = "EEEE" // Day of week
                return formatter.string(from: date)
            } else {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                return formatter.string(from: date)
            }
        }
}

// Quick date selection button component
struct QuickDateButton: View {
    let title: String
    let date: Date
    @Binding var selectedDate: Date
    
    private var isSelected: Bool {
        Calendar.current.isDate(date, inSameDayAs: selectedDate)
    }
    
    var body: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedDate = date
            }
        }) {
            Text(title)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.2))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}


@available(iOS 26.0, *)
extension TaskFormView {
    @ViewBuilder
    var aiSplitterSection: some View {
        if #available(iOS 26.0, *) {
            if SystemLanguageModel.default.isAvailable {
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
                            taskName: Binding<String> (
                                get: { toDoTask.name ?? ""},
                                set: { toDoTask.name = $0.isEmpty ? nil : $0}
                            )
                        )
                        .disabled(toDoTask.name?.isEmpty ?? true)
                    }
                } footer: {
                    Text("Requires iOS 26 or later • Powered by Apple Intelligence")
                        .font(.caption2)
                }
            } else if SystemLanguageModel.default.availability == .unavailable(.modelNotReady) {
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

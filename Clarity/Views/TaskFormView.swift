//
//  AddTaskView.swift
//  Clarity
//
//  Created by Craig Peters on 29/08/2025.
//

import SwiftData
import SwiftUI

struct TaskFormView: View {
    @Bindable var toDoStore: ToDoStore
    @Environment(\.dismiss) private var dismiss
    
    let editingTask: ToDoTask?
    @State private var toDoTask : ToDoTask
    @State private var selectedCategories: [Category] = []
    
    private var isEditing : Bool{
        editingTask != nil
    }
    
    // TODO: Bug on this where it creates an empty task when you click on a task for the first time
    init(toDoStore: ToDoStore, task: ToDoTask? = nil) {
        self.toDoStore = toDoStore
        self.editingTask = task
        
        if let task = task {
            self._toDoTask = State(initialValue: task)
            self._selectedCategories = State(initialValue: task.categories)
        } else {
            self._toDoTask = State(initialValue: ToDoTask(name: ""))
            self._selectedCategories = State(initialValue: [])
        }
        
    }
    
    private func saveTask(){
        withAnimation(.easeInOut(duration: 0.2)) {
            toDoTask.categories = selectedCategories
            
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
}

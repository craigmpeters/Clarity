//
//  SwiftUIView.swift
//  Clarity
//
//  Created by Craig Peters on 17/08/2025.
//

import SwiftUI
import SwiftData

struct TaskIndexView: View {
    @Query private var tasks: [Task]
    @Environment(\.modelContext) private var context
    @State private var taskToAdd = ""
    
    var body: some View {
        VStack {
            List(tasks, id: \.id) { task in Text(task.name)
                    .swipeActions(edge: .leading) {
                        Button{context.delete(task)} label: {
                            Label("Complete", systemImage: "checkmark")
                        }
                        .tint(.green)
                    }
            }
        }
        TextField("Add Task", text: $taskToAdd)
            .onSubmit {
                let newTask = Task(name: taskToAdd)
                context.insert(newTask)
                taskToAdd = ""
            }
        .padding()
    }
}

#Preview {
    TaskIndexView()
        .modelContainer(for: Task.self, inMemory: true)
}

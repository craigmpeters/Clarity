//
//  SwiftUIView.swift
//  Clarity
//
//  Created by Craig Peters on 17/08/2025.
//

import SwiftUI

struct TaskIndexView: View {
    @State private var tasks : [String] = ["Cuddle Socks", "Take Socks for Walk"]
    @State private var taskToAdd = ""
    
    var body: some View {
        VStack {
            List {
                ForEach(tasks, id: \.description) { task in
                    Text(task)
                        .swipeActions(edge: .leading) {
                            Button{ tasks.remove(at: self.tasks.firstIndex(of: task)!)} label: {
                                Label("Complete", systemImage: "checkmark")
                            }
                            .tint(.green)
                        }
                }
            }
        }
        TextField("Add Task", text: $taskToAdd)
            .onSubmit {
                tasks.append(taskToAdd)
                taskToAdd = ""
            }
        .padding()
    }
}

#Preview {
    TaskIndexView()
}

//
//  ContentView.swift
//  WatchClarity Watch App
//
//  Created by Craig Peters on 23/09/2025.
//

import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<ToDoTask> { !$0.completed }, sort: \ToDoTask.due, order: .forward) private var allTasks: [ToDoTask]

    var body: some View {
        VStack {
            List(allTasks, id: \.id) { task in
                Text(task.name ?? "")
                    .foregroundStyle(accentTextColor(task.due))
                    .listItemTint(accentBackgroundColor(task.due))
                    .swipeActions(edge: .leading) {
                        Button(action: {
                            startTimer(for: task)
                        }, label: {
                            Label("Start Timer", systemImage: "timer")
                        })
                        .tint(.blue)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(action: {
                            completeTask(task)
                        }, label: {
                            Label("Complete", systemImage: "checkmark")
                        })
                        .tint(.green)
                    }
            }
            .listStyle(.carousel)
        }
        .padding()
    }

    private func accentTextColor(_ due: Date) -> Color {
        let isToday = Calendar.current.isDateInToday(due)
        let isPast = Date.now.midnight > due.midnight

        if isPast { return .red }
        if isToday { return .primary }

        return .primary
    }

    private func accentBackgroundColor(_ due: Date) -> Color {
        let isToday = Calendar.current.isDateInToday(due)
        let isPast = Date.now.midnight > due.midnight

        if isPast { return .red.opacity(0.15) }
        if isToday { return .green.opacity(0.15) }
        return Color.accentColor.opacity(0.12)
    }

    private func completeTask(_ task: ToDoTask) -> Void {
        print("Attempting to complete task \(task.name ?? "")")
//        Task {
//            SharedDataActor.shared.completeToDoTask(toDoTask: task)
//        }
        
    }

    private func startTimer(for task: ToDoTask) -> Void {
        print("Attempting to start timer \(task.name ?? "")")
//    selectedTask = task
//    withAnimation(.easeInOut(duration: 0.3)) {
//        showingPomodoro = true
//    }
    }
}

#if DEBUG
#Preview {
    ContentView()
        .modelContainer(PreviewData.shared.previewContainer)
}
#endif

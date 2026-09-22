//
//  WatchTaskRow.swift
//  Clarity
//
//  Created by Craig Peters on 22/09/2026.
//


import SwiftUI
import WatchConnectivity
import XCGLogger
import WidgetKit

struct WatchTaskRow: View {
    let task: ToDoTaskDTO
    let onComplete: () -> Void
    let onStartTimer: () -> Void

    var body: some View {
        Text(task.name)
            .foregroundStyle(accentTextColor(task.due))
            .listItemTint(accentBackgroundColor(task.due))
            .swipeActions(edge: .leading) {
                Button(action: onStartTimer, label: {
                    Label("Start Timer", systemImage: "timer")
                })
                .tint(.blue)
            }
            .swipeActions(edge: .trailing) {
                Button(action: onComplete, label: {
                    Label("Complete", systemImage: "checkmark")
                })
                .tint(.green)
            }
            .task {
                LogManager.shared.log.debug("\(task.name) is \(task.completed ? "completed" : "not completed")")
            }
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
}
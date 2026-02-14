//
//  LargeWidgetView.swift
//  PomodoroExtensionExtension
//
//  Created by Craig Peters on 02/09/2025.
//

import SwiftUI

struct LargeTaskWidgetView: View {
    let entry: TaskWidgetEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TaskWidgetTitle(entry: entry)
            
            Divider()
            
            // Task list (show up to 4 with buttons)
            if !entry.todos.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(entry.todos.prefix(8), id: \.id) { task in
                        TaskRowInteractive(task: task)
                    }
                }
            } else {
                Text("No tasks")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical)
            }
            
            Spacer()
            WeeklyProgressWidget(progress: entry.progress)
            
                .padding()
        }
    }
    
}

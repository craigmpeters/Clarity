//
//  MediumWidgetView.swift
//  PomodoroExtensionExtension
//
//  Created by Craig Peters on 02/09/2025.
//

import SwiftUI

struct MediumTaskWidgetView: View {
    let entry: TaskWidgetEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            TaskWidgetTitle(entry: entry)
            
            Divider()
            
            if entry.todos.isEmpty {
                Spacer()
                Text("No tasks")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                Spacer()
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(entry.todos.prefix(3), id: \.id ) { todo in
                        TaskRowInteractive(task: todo)
                    }
                }
                Spacer()
            }
        }
        .padding()
    }
}

//
//  TimerIndicatorBadge.swift
//  Clarity
//
//  Created by Craig Peters on 22/09/2025.
//

import SwiftUI

struct TimerIndicatorBadge: View {
    let task: ToDoTask
    
    
    private var pomodoroDescription: String {
        return String(Int(task.pomodoroTime / 60 ))
    }
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "timer")
                .font(.caption2)
            Text(pomodoroDescription)
                .font(.caption2)
                .lineLimit(1)
        }
        .foregroundStyle(.blue)
        .background(Color.clear)
        .cornerRadius(6)
    }
}

#Preview {
    
}

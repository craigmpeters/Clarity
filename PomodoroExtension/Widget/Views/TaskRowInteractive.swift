import SwiftUI

struct TaskRowInteractive: View {
    let task: TaskWidgetEntry.TaskInfo
    
    var body: some View {
        HStack(spacing: 8) {
            // Complete button
            Button(intent: CompleteTaskIntent(taskId: task.id)) {
                Image(systemName: "circle")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            
            Text(task.name)
                .font(.caption)
                .lineLimit(1)
            
            Spacer()
            
            HStack(spacing: 4) {
                if !task.categoryColors.isEmpty {
                    Circle()
                        .fill(WidgetColorUtility.colorFromString(task.categoryColors.first!))
                        .frame(width: 6, height: 6)
                }
                
                Text("\(task.pomodoroMinutes)m")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
            
            // Timer button - Now uses StartPomodoroIntent
            // ToDo: Fix Pomodoro Widget
//            Button(intent: StartPomodoroIntent(taskId: task.id)) {
//                Image(systemName: "play.circle.fill")
//                    .font(.system(size: 18))
//                    .foregroundStyle(.blue)
//            }
            .buttonStyle(.plain)
        }
    }
}
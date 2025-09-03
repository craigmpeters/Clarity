
import SwiftUI

struct MediumWidgetView: View {
    let entry: TaskWidgetEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Label {
                    HStack(spacing: 4) {
                        Text(entry.category?.name ?? entry.filter.rawValue)
                        if let category = entry.category {
                            Circle()
                                .fill(Category.CategoryColor(rawValue: category.colorRawValue)?.SwiftUIColor ?? .gray)
                                .frame(width: 10, height: 10)
                        }
                    }
                } icon: {
                    Image(systemName: entry.filter.systemImage)
                }
                .font(.headline)
                .foregroundStyle(entry.filter.accentColor)
                
                Spacer()
                
                Text("\(entry.taskCount)")
                    .font(.title2.bold())
                    .foregroundStyle(.primary)
            }
            
            Divider()
            
            // Task list
            if entry.tasks.isEmpty {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 4) {
                        Image(systemName: "checkmark.circle")
                            .font(.title2)
                            .foregroundStyle(.green)
                        Text("No tasks")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                Spacer()
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(entry.tasks.prefix(3)) { task in
                        MediumTaskRow(task: task)
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .padding()
    }
}

struct MediumTaskRow: View {
    let task: TaskWidgetEntry.TaskInfo
    
    var body: some View {
        Link(destination: taskURL) {
            HStack(spacing: 8) {
                Circle()
                    .strokeBorder(Color.secondary.opacity(0.3), lineWidth: 1.5)
                    .frame(width: 16, height: 16)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(task.name)
                        .font(.caption)
                        .lineLimit(1)
                        .foregroundStyle(.primary)
                    
                    HStack(spacing: 4) {
                        ForEach(task.categoryColors, id: \.self) { color in
                            Circle()
                                .fill(color.SwiftUIColor)
                                .frame(width: 6, height: 6)
                        }
                        
                        Text(formatTime(task.dueDate))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
            }
        }
    }
    
    private var taskURL: URL {
        URL(string: "clarity://task/\(task.id)?action=view")!
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

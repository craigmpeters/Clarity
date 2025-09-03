
import SwiftUI

struct MediumTaskWidgetView: View {
    let entry: TaskWidgetEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Label(entry.filter.rawValue, systemImage: entry.filter.systemImage)
                    .font(.headline)
                    .foregroundStyle(entry.filter.color)
                
                Spacer()
                
                Text("\(entry.taskCount)")
                    .font(.title2.bold())
            }
            
            Divider()
            
            // Task list (show up to 3)
            if entry.tasks.isEmpty {
                Spacer()
                Text("No tasks")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                Spacer()
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(entry.tasks.prefix(3), id: \.name) { task in
                        WidgetTaskRow(task: task)
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .padding()
    }
}

import SwiftUI
import SwiftData

@available(iOS 26.0, *)
struct TaskSplitterView: View {
    @Binding var taskName: String
    @State private var showingSplitter = false
    @State private var selectedSuggestions: [SplitTaskSuggestion] = []
    
    var body: some View {
        if #available(iOS 26.0, *) {
            Button(action: { showingSplitter = true }) {
                Label("Split with AI", systemImage: "apple.intelligence")
                    .font(.subheadline)
            }
            .buttonStyle(.bordered)
            .sheet(isPresented: $showingSplitter) {
                TaskSplitterSheet(
                    taskName: taskName,
                    isPresented: $showingSplitter
                )
            }
        }
    }
}

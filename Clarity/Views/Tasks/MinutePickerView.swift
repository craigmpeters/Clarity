import SwiftUI

struct MinutePickerView: View {
    @Binding var selectedTimeInterval: TimeInterval
    @Binding var TaskName: String
    
    // Generate array of 5-minute increments (0, 5, 10, 15, ..., up to desired max)
    private let minuteOptions: [Int] = Array(stride(from: 5, through: 25, by: 5)) // 0 to 3 hours
    
    var body: some View {
        HStack {
            Picker("", selection: Binding(
                get: { Int(selectedTimeInterval / 60) },
                set: { selectedTimeInterval = TimeInterval($0 * 60) }
            )) {
                ForEach(minuteOptions, id: \.self) { minutes in
                    Text(formatTime(minutes: minutes))
                        .tag(minutes)
                }
            }
            .accentColor(.primary)
            if #available(iOS 26.0, *) {
                PomodoroSuggestion(taskSuggestion: $TaskName, suggestedTime: $selectedTimeInterval)
            }
        }
    }
    
    private func formatTime(minutes: Int) -> String {
        if minutes == 0 {
            return "0 min"
        } else if minutes < 60 {
            return "\(minutes) min"
        } else {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            if remainingMinutes == 0 {
                return hours == 1 ? "1 hour" : "\(hours) hours"
            } else {
                return "\(hours)h \(remainingMinutes)m"
            }
        }
    }
}

#if DEBUG
#Preview {
    @Previewable @State var selectedTime: TimeInterval = 900
    @Previewable @State var taskName: String = "Cuddle Dog"
    
    MinutePickerView(selectedTimeInterval: $selectedTime, TaskName: $taskName)
}
#endif

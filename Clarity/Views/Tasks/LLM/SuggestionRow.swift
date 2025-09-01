import SwiftUI
import SwiftData

@available(iOS 26.0, *)
struct SuggestionRow: View {
    @Binding var suggestion: SplitTaskSuggestion
    
    var body: some View {
        HStack(spacing: 12) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    suggestion.isSelected.toggle()
                }
            } label: {
                Image(systemName: suggestion.isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(suggestion.isSelected ? .blue : .secondary)
            }
            .buttonStyle(.plain)
            
            VStack(alignment: .leading, spacing: 4) {
                TextField("Task name", text: $suggestion.name)
                    .font(.subheadline)
                    .textFieldStyle(.plain)
                    .disabled(!suggestion.isSelected)
                
                HStack {
                    Image(systemName: "timer")
                        .font(.caption)
                    
                    Stepper(value: $suggestion.estimatedMinutes, in: 5...60, step: 5) {
                        Text("\(suggestion.estimatedMinutes) min")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .labelsHidden()
                }
            }
            
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(suggestion.isSelected ? Color.blue.opacity(0.05) : Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(suggestion.isSelected ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .opacity(suggestion.isSelected ? 1.0 : 0.6)
    }
}

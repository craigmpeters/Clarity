//
//  DevPomodoroSuggestion.swift
//  Clarity
//
//  Created by Craig Peters on 04/01/2026.
//

import SwiftUI

struct DevPomodoroSuggestionText: View {
    @State private var taskSuggestion = ""
    @State private var suggestedTime: TimeInterval = 0.0
    
    var body: some View {
        HStack {
            TextField("Task for Suggestion", text: $taskSuggestion)
            if #available(iOS 26.0, *) {
                DevPomodoroSuggestion(taskSuggestion: $taskSuggestion, suggestedTime: $suggestedTime)
            }
        }
        HStack {
            Image(systemName: "timer")
            Text("Suggested: \(suggestedTime / 60, format: .number.precision(.fractionLength(1))) min")
        }
    }
}

@available(iOS 26.0, *)
struct DevPomodoroSuggestion: View {
    
    @StateObject private var suggestion = PomodoroSuggestionService()
    @Binding var taskSuggestion: String
    @Binding var suggestedTime: TimeInterval
    
    var body: some View {

        Button(action: {
            Task { await createSuggestion() }
        }) {
            Image(systemName: "apple.intelligence")
                .rotationEffect(.degrees(suggestion.isProcessing ? 360 : 0))
                .animation(suggestion.isProcessing ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: suggestion.isProcessing)
                .accessibilityLabel("Suggest")
        }
        .buttonStyle(.bordered)
 
    }
    
    private func createSuggestion() async {
        await suggestion.suggestTime(for: taskSuggestion)
        suggestedTime = suggestion.suggestedInterval
         
    }
}

#Preview {
    if #available(iOS 26.0, *) {
        DevPomodoroSuggestionText()
    }
}

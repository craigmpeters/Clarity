//
//  PomodoroSuggestion.swift
//  Clarity
//
//  Created by Craig Peters on 04/01/2026.
//

import SwiftUI
import OSLog

@available(iOS 26.0, *)
struct PomodoroSuggestion: View {
    
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
        suggestedTime = min(suggestion.suggestedInterval, 25 * 60) // Clamp to 25 minutes
        Logger.UserInterface.debug("Returned time interval: \(suggestedTime / 60, privacy: .public) minutes")
         
    }
}

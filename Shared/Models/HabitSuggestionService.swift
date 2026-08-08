//
//  HabitSuggestionService.swift
//  Clarity
//
//  Created by OpenCode on 08/08/2026.
//

import Foundation
import Combine
#if os(iOS) && canImport(FoundationModels)
import FoundationModels
#endif
import XCGLogger

#if os(iOS) && canImport(FoundationModels)
@available(iOS 26.0, *)
@Generable(description: "A suggested starting configuration for a habit")
struct HabitSuggestion {
    @Guide(description: "The unit of measurement for this habit, e.g. 'glasses', 'pages', 'minutes'. Keep it short and lowercase.")
    var unitLabel: String

    @Guide(description: "A reasonable daily target amount for this habit. Must be between 1 and 1000.")
    var dailyTarget: Double

    @Guide(description: "A sensible increment step for logging this habit. Must be between 0.1 and 100.")
    var incrementStep: Double
}
#endif

#if os(iOS)
@MainActor
final class HabitSuggestionService: ObservableObject {
    enum Availability {
        case available
        case unavailable
    }

    struct Suggestion: Sendable {
        let unitLabel: String
        let dailyTarget: Double
        let incrementStep: Double
    }

    @Published var isProcessing = false
    @Published var currentSuggestion: Suggestion?

    var availability: Availability {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            return SystemLanguageModel.default.availability == .available ? .available : .unavailable
        }
        #endif
        return .unavailable
    }

    func suggest(for name: String) async {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        guard #available(iOS 26.0, *) else { return }
        guard availability == .available else { return }

        isProcessing = true
        defer { isProcessing = false }

        #if canImport(FoundationModels)
        do {
            let prompt = """
            The user wants to build a habit called "\(name)".
            Suggest a unit label, daily target, and increment step they might log each day.
            Be concise and practical. Use common units (glasses, pages, minutes, km, steps, etc.).
            """
            let options = GenerationOptions(temperature: 0.4)
            let session = LanguageModelSession()
            let response = try await session.respond(to: prompt, generating: HabitSuggestion.self, options: options)
            let suggestion = response.content
            let unit = suggestion.unitLabel.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let target = min(max(suggestion.dailyTarget, HabitConfig.dailyTargetRange.lowerBound), HabitConfig.dailyTargetRange.upperBound)
            let step = min(max(suggestion.incrementStep, HabitConfig.incrementStepRange.lowerBound), HabitConfig.incrementStepRange.upperBound)
            guard !unit.isEmpty else { return }
            currentSuggestion = Suggestion(unitLabel: unit, dailyTarget: target, incrementStep: step)
        } catch {
            LogManager.shared.log.error("HabitSuggestionService failed: \(error)")
        }
        #endif
    }

    func clear() {
        currentSuggestion = nil
    }
}
#endif

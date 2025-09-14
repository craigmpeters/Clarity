// TaskSplitterView.swift
// AI-powered task splitting using Foundation Models (iOS 18+)

import SwiftUI
import SwiftData
#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - Task Splitting Result Model
struct SplitTaskSuggestion: Identifiable {
    let id = UUID()
    var name: String
    var estimatedMinutes: Int
    var isSelected: Bool = true
    var selectedCategories: [Category] = []
}

// MARK: - AI Task Splitter Service
@available(iOS 26.0, *)
class TaskSplitterService: ObservableObject {
    @Published var isProcessing = false
    @Published var suggestions: [SplitTaskSuggestion] = []
    @Published var error: String?
    
    
    func splitTask(_ taskName: String) async {
        await MainActor.run {
            self.isProcessing = true
            self.error = nil
        }
        
        do {
            // Create the prompt for task splitting
            let prompt = """
            Split this task into smaller, actionable subtasks: "\(taskName)"
            
            Requirements:
            - Break it into 2-6 concrete, specific subtasks
            - Each subtask should be independently completable
            - Each task should take around 5 minutes or at most 10 minutes
            - Order them logically
            - Do not include any special formatting or Markdown
            
            Format your response as:
            1. [Task name] | [minutes]
            2. [Task name] | [minutes]
            """
            
            let options = GenerationOptions(temperature: 0.5)
            let session = LanguageModelSession()
            let response = try await session.respond(
                to: prompt,
                options: options
            )
            
            // Parse the response into suggestions
            let parsedSuggestions = parseResponse(response.content, taskName: taskName)
            
            await MainActor.run {
                self.suggestions = parsedSuggestions
                self.isProcessing = false
            }
        } catch {
            await MainActor.run {
                self.error = "Failed to generate suggestions: \(error.localizedDescription)"
                self.isProcessing = false
            }
        }
    }
    
    private func parseResponse(_ text: String, taskName: String) -> [SplitTaskSuggestion] {
        print("Apple Intelligence Response: \(text) ")
        let lines = text.components(separatedBy: .newlines)
        var suggestions: [SplitTaskSuggestion] = []
        
        for line in lines {
            // Parse lines like "1. Task name | 25"
            let cleaned = line
                .replacingOccurrences(of: #"^\d+\.\s*"#, with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespaces)
            
            let parts = cleaned.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
            
            if parts.count == 2,
               !parts[0].isEmpty,
               let minutes = Int(parts[1].replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)) {
                suggestions.append(SplitTaskSuggestion(
                    name: parts[0],
                    estimatedMinutes: min(max(minutes, 5), 25)
                ))
            }
        }
        
        // If parsing fails, create a simple split
        if suggestions.isEmpty && !text.isEmpty {
            suggestions.append(SplitTaskSuggestion(
                name: taskName,
                estimatedMinutes: 15
            ))
        }
        
        return suggestions
    }
}

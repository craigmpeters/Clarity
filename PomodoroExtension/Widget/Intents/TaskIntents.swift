//
//  CreateTaskIntent.swift
//  Clarity
//
//  Created by Craig Peters on 30/08/2025.
//

import Foundation
import AppIntents

struct CreateTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "Create Task"
    static var description = IntentDescription("Create a new task in Clarity")
    static var openAppWhenRun: Bool = false

    static var parameterSummary: some ParameterSummary {
        Summary("Create Task") {
            \.$taskName
            \.$duration
            \.$isRepeating
            \.$categories
        }
    }
    
    @Parameter(title: "Task Name")
    var taskName: String
    
    @Parameter(title: "Duration (Minutes)", default: 5)
    var duration: Int
    
    @Parameter(title: "Repeating Task?", default: false)
    var isRepeating: Bool
    
    @Parameter(title: "Categories")
    var categories: [CategoryEntity]?
    
    func perform() async throws -> some IntentResult & ProvidesDialog {
        print("[CreateTaskIntent] Invoked")
        print("[CreateTaskIntent] Input — name: \(taskName), duration(min): \(duration), repeating: \(isRepeating)")
        let categoryIds = categories?.map { $0.id } ?? []
        print("[CreateTaskIntent] Input — categories: \(String(describing: categories))")
        print("[CreateTaskIntent] Derived — categoryIds: \(categoryIds)")

        // Validate inputs
        if taskName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            print("[CreateTaskIntent] Validation failed — empty task name")
            return .result(dialog: IntentDialog("Task name is required."))
        }
        if duration <= 0 {
            print("[CreateTaskIntent] Validation failed — non-positive duration: \(duration)")
            return .result(dialog: IntentDialog("Duration must be greater than 0 minutes."))
        }

        do {
            print("[CreateTaskIntent] Calling addTask …")
            await SharedDataActor.shared.addTask(
                name: taskName,
                duration: TimeInterval(duration * 60),
                repeating: isRepeating,
                categoryIds: categoryIds
            )
            print("[CreateTaskIntent] addTask completed successfully")
            return .result(dialog: IntentDialog("Created task \"\(taskName)\" for \(duration) minutes."))
        } catch {
            print("[CreateTaskIntent] addTask threw error: \(error)")
            return .result(dialog: IntentDialog("Failed to create task: \(error.localizedDescription)"))
        }
    }
}

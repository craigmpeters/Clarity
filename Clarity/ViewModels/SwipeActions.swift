//
//  SwipeActions.swift
//  Clarity
//
//  Created by Craig Peters on 03/12/2025.
//

import Foundation
import SwiftUI

/// Represents the possible swipe actions a user can perform on a row
enum SwipeAction: Equatable, Sendable {
    case delete
    case edit
    case complete
    case startTimer
}

extension SwipeAction {
    /// A human-readable title for the action, useful for UI labels.
    var title: String {
        switch self {
        case .delete: return "Delete Task"
        case .edit: return "Edit Task"
        case .complete: return "Complete Task"
        case .startTimer: return "Start Timer"
        }
    }
    
    /// Icon for the action
    var systemImage: Image {
        switch self {
        case .delete: return Image(systemName: "trash")
        case .edit: return Image(systemName: "pencil")
        case .complete: return Image(systemName: "checkmark")
        case .startTimer: return Image(systemName: "timer")
        }
    }
}

/// A protocol that defines how to perform each swipe action.
/// Conform your view model or handler type to this to execute actions.
protocol SwipeActionPerforming {
    func deleteTask(_ task: ToDoTaskDTO)
    func editTask(_ task: ToDoTask)
    func completeTask(_ task: ToDoTaskDTO)
    func startTimer(_ task: ToDoTaskDTO)
}

extension SwipeAction {
    /// Perform this action using a handler that knows how to execute each operation for a given task.
    /// This makes the switch exhaustive and keeps UI code simple.
    func perform(on handler: SwipeActionPerforming, taskDTO: ToDoTaskDTO, task: ToDoTask) {
        switch self {
        case .delete:
            handler.deleteTask(taskDTO)
        case .edit:
            handler.editTask(task)
        case .complete:
            handler.completeTask(taskDTO)
        case .startTimer:
            handler.startTimer(taskDTO)
        }
    }
}

/// Convenience overload that allows providing closures inline instead of a conforming type.
extension SwipeAction {
    struct Handlers {
        var delete: () -> Void
        var edit: () -> Void
        var complete: () -> Void
        var startTimer: () -> Void
    }

    /// Perform this action using a set of closures. All handlers are required so the mapping is exhaustive.
    func perform(using handlers: Handlers) {
        switch self {
        case .delete:
            handlers.delete()
        case .edit:
            handlers.edit()
        case .complete:
            handlers.complete()
        case .startTimer:
            handlers.startTimer()
        }
    }
}

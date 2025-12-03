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
    case none
    case delete
    case edit
    case complete
    case startTimer
}

extension SwipeAction {
    /// A human-readable title for the action, useful for UI labels.
    var title: String {
        switch self {
        case .none: return "No Action"
        case .delete: return "Delete Task"
        case .edit: return "Edit Task"
        case .complete: return "Complete Task"
        case .startTimer: return "Start Timer"
        }
    }
    
    /// Icon for the action
    var systemImage: Image {
        switch self {
        case .none: return Image(systemName: "minus")
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
    func editTask(_ task: ToDoTaskDTO)
    func completeTask(_ task: ToDoTaskDTO)
    func startTimer(_ task: ToDoTaskDTO)
}

extension SwipeAction {
    /// Perform this action using a handler that knows how to execute each operation for a given task.
    /// This makes the switch exhaustive and keeps UI code simple.
    func perform(on handler: SwipeActionPerforming, task: ToDoTaskDTO) {
        switch self {
        case .none:
            break
        case .delete:
            handler.deleteTask(task)
        case .edit:
            handler.editTask(task)
        case .complete:
            handler.completeTask(task)
        case .startTimer:
            handler.startTimer(task)
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
        case .none:
            break
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

enum UserSwipeActions {
    case Tap
    case LeadingPrimary
    case LeadingSecondary
    case TrailingPrimary
    case TrailingSecondary
}

/// A configurable mapping from user swipe positions to actions.
/// Persist an instance of this (e.g., in UserDefaults) to let users customize their swipe actions.
struct UserSwipeActionsConfiguration: Equatable, Sendable {
    var tap: SwipeAction
    var leadingPrimary: SwipeAction
    var leadingSecondary: SwipeAction
    var trailingPrimary: SwipeAction
    var trailingSecondary: SwipeAction

    /// Default configuration mirrors the current built-in mapping.
    static let `default` = UserSwipeActionsConfiguration(
        tap: .edit,
        leadingPrimary: .complete,
        leadingSecondary: .startTimer,
        trailingPrimary: .delete,
        trailingSecondary: .none
    )

    /// Subscript to get/set by position.
    subscript(position: UserSwipeActions) -> SwipeAction {
        get {
            switch position {
            case .Tap: return tap
            case .LeadingPrimary: return leadingPrimary
            case .LeadingSecondary: return leadingSecondary
            case .TrailingPrimary: return trailingPrimary
            case .TrailingSecondary: return trailingSecondary
            }
        }
        set {
            switch position {
            case .Tap: tap = newValue
            case .LeadingPrimary: leadingPrimary = newValue
            case .LeadingSecondary: leadingSecondary = newValue
            case .TrailingPrimary: trailingPrimary = newValue
            case .TrailingSecondary: trailingSecondary = newValue
            }
        }
    }

    /// Return all assigned actions in order of positions.
    var assignedActions: [SwipeAction] {
        [tap, leadingPrimary, leadingSecondary, trailingPrimary, trailingSecondary]
    }

    /// Returns the set of actions not currently assigned in this configuration.
    func unassignedActions(all actions: [SwipeAction] = [.delete, .edit, .complete, .startTimer]) -> [SwipeAction] {
        let assigned = Set(assignedActions)
        return actions.filter { !assigned.contains($0) }
    }

    /// Ensure all positions are uniquely assigned; returns false if any duplicates are present.
    var hasUniqueAssignments: Bool {
        Set(assignedActions).count == assignedActions.count
    }
}

extension SwipeAction {
    /// Apply this action according to a configuration and position, using the provided handler and tasks.
    func perform(using config: UserSwipeActionsConfiguration,
                 at position: UserSwipeActions,
                 on handler: SwipeActionPerforming,
                 task: ToDoTaskDTO) {
        let action = config[position]
        action.perform(on: handler, task: task)
    }
}

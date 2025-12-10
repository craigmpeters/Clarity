//
//  SwipeActions.swift
//  Clarity
//
//  Created by Craig Peters on 03/12/2025.
//

import Foundation
import SwiftUI
import SwiftData

/// Represents the possible swipe actions a user can perform on a row
enum SwipeAction: String, Codable, Equatable, Sendable {
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
    var systemImage: String {
        switch self {
        case .none: return "minus"
        case .delete: return "trash"
        case .edit: return "pencil"
        case .complete: return "checkmark"
        case .startTimer: return "timer"
        }
    }
    
    var color: Color {
        switch self {
        case .none: return .black
        case .delete: return .red
        case .edit: return .blue
        case .complete: return .green
        case .startTimer: return .blue
        }
    }
    
    /// The SF Symbol name for the action's icon.
    var systemImageName: String {
        switch self {
        case .none: return "minus"
        case .delete: return "trash"
        case .edit: return "pencil"
        case .complete: return "checkmark"
        case .startTimer: return "timer"
        }
    }
    
    /// Suggested button role for this action.
    var role: ButtonRole? {
        switch self {
        case .delete: return .destructive
        default: return nil
        }
    }
}


// #MARK: Model

@Model
public final class  TaskSwipeAndTapOptions {
    
    var tap: SwipeAction = SwipeAction.edit
    var primarySwipeLeading: SwipeAction = SwipeAction.startTimer 
    var primarySwipeTrailing: SwipeAction = SwipeAction.delete
    var secondarySwipeLeading: SwipeAction = SwipeAction.complete
    var secondarySwipeTrailing: SwipeAction = SwipeAction.none
    
    public init() {
        
    }
    
    init(primarySwipeLeading: SwipeAction, secondarySwipeLeading: SwipeAction, primarySwipeTrailing: SwipeAction, secondarySwipeTrailing: SwipeAction) {
        self.primarySwipeLeading = primarySwipeLeading
        self.primarySwipeTrailing = primarySwipeTrailing
        self.secondarySwipeLeading = secondarySwipeLeading
        self.secondarySwipeTrailing = secondarySwipeTrailing
        
    }
}


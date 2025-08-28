//
//  Category.swift
//  Clarity
//
//  Created by Craig Peters on 28/08/2025.
//

import Foundation
import SwiftData
import SwiftUI

@Model

class Category {
    var name: String
    var color: CategoryColor
    @Relationship(inverse: \ToDoTask.categories) var tasks: [ToDoTask] = []
    
    init(name: String, color: CategoryColor = .Red) {
        self.name = name
        self.color = color
        
    }
    
    enum CategoryColor: String, CaseIterable, Codable {
        case Red = "Red"
        case Blue = "Blue"
        case Green = "Green"
        case Yellow = "Yellow"
        case Brown = "Brown"
        case Cyan = "Cyan"
        case Pink = "Pink"
        case Orange = "Orange"
        
        var SwiftUIColor : Color {
            switch self {
            case .Red: return .red
            case .Blue: return .blue
            case .Green: return .green
            case .Yellow: return .yellow
            case .Brown: return .brown
            case .Cyan: return .cyan
            case .Pink: return .pink
            case .Orange: return .orange
            }
        }
    }
}


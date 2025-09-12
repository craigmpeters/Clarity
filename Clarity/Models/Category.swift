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
    // FIXME: I need to fix this properly before I check this in
    //@Attribute(.unique) var name: String = "Category"
    var name: String = "Category"
    var color: CategoryColor = CategoryColor.Red
    var weeklyTarget: Int = 0
    @Relationship(inverse: \ToDoTask.categories) var tasks: [ToDoTask]? = []
    
    init(name: String, color: CategoryColor = .Red, weeklyTarget: Int = 0) {
        self.name = name
        self.color = color
        self.weeklyTarget = weeklyTarget
    }
    
    enum CategoryColor: String, CaseIterable, Codable {
        case Red = "Red"
        case Blue = "Blue"
        case Green = "Green"
        case Yellow = "Yellow"
        case Brown = "Brown"
        case Cyan = "Cyan"
        case Pink = "Pink"
        case Purple = "Purple"
        case Orange = "Orange"
        
        var SwiftUIColor : Color {
            switch self {
            case .Red: return .red
            case .Blue: return .blue
            case .Green: return .green
            case .Yellow: return .yellow
            case .Brown: return .brown
            case .Cyan: return .cyan
            case .Pink: return
                // Barbie pink - vibrant!
                Color(red: 1.0, green: 0.08, blue: 0.58)
            case .Purple: return
                Color(red: 0.58, green: 0.0, blue: 0.83)
            case .Orange: return .orange
            }
        }
        
        var contrastingTextColor: Color {
            switch self {
            case .Yellow, .Cyan, .Pink:
                return .black
            case .Red, .Blue, .Green, .Brown, .Orange, .Purple:
                return .white
            }
        }
    }
}


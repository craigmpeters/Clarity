//
//  WidgetColorUtility.swift
//  Clarity
//
//  Created by Craig Peters on 03/09/2025.
//


import SwiftUI

struct WidgetColorUtility {
    static func colorFromString(_ colorName: String) -> Color {
        switch colorName {
        case "Red": return .red
        case "Blue": return .blue
        case "Green": return .green
        case "Yellow": return .yellow
        case "Brown": return .brown
        case "Cyan": return .cyan
        case "Pink": return Color(red: 1.0, green: 0.08, blue: 0.58)
        case "Purple": return Color(red: 0.58, green: 0.0, blue: 0.83)
        case "Orange": return .orange
        case "Gray": return .gray
        default: return .gray
        }
    }
}

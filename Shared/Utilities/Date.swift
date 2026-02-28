//
//  Date.swift
//  Clarity
//
//  Created by Craig Peters on 21/09/2025.
//

import Foundation
import SwiftUI

extension Date {
    var midnight: Date {
        let cal = Calendar(identifier: .gregorian)
        return cal.startOfDay(for: self)
    }
}

extension Notification.Name {
    static let pomodoroCompleted = Notification.Name("pomodoroCompleted")
    static let pomodoroStarted = Notification.Name("pomodoroStarted")
    static let focusSettingsChanged = Notification.Name("focusSettingsChanged")
}

extension Calendar {
    
    // What is stored matches the locale
    // ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
    
     
    func weekdaySymbolFromComponent(at date: Date) -> String {
        let formatter = DateFormatter()
        // Use the calendar's locale if available for correct symbols
        formatter.locale = self.locale ?? Locale.current
        // Calendar weekday component is 1-based (1 = Sunday in Gregorian by default)
        let weekdayIndex = self.component(.weekday, from: date) - 1
        // Safely guard against out-of-bounds, though it should be 0...6
        guard weekdayIndex >= 0 && weekdayIndex < formatter.weekdaySymbols.count else {
            return ""
        }
        return formatter.weekdaySymbols[weekdayIndex]
    }
}

extension Color {
    static let clarityBlue =  Color(red: 0, green: 0.384, blue: 0.788) // #0062c9
    static let clarityYellow = Color(red: 0.988, green: 0.835, blue: 0.122) // #fcd51f
}

extension ShapeStyle where Self == Color {
    /// Clarity brand blue as a ShapeStyle-compatible color.
    public static var clarityBlue: Color { Color.clarityBlue }
    /// Clarity brand yellow as a ShapeStyle-compatible color.
    public static var clarityYellow: Color { Color.clarityYellow }
}


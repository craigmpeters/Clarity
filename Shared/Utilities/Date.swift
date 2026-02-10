//
//  Date.swift
//  Clarity
//
//  Created by Craig Peters on 21/09/2025.
//

import Foundation

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

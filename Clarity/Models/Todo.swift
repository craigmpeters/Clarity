//
//  Todo.swift
//  Clarity
//
//  Created by Craig Peters on 17/08/2025.
//

import Foundation
import SwiftData

@Model
class Task {
    var id: UUID
    var name: String
    var created: Date
    var due: Date
    var pomodoro: Bool = true //Todo: Set to False as default
    
    // Todo: Created, Due, Type, Tags
    
    var friendlyDue: String {
        // Today
        if Calendar.current.isDateInToday(due) {
            return "Today"
        } else {
            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale(identifier: Locale.current.identifier)
            dateFormatter.setLocalizedDateFormatFromTemplate("MMMMd")
            return dateFormatter.string(from: due)
        }
        
        
    }
    
    init(name: String) {
        self.name = name
        self.id = UUID()
        self.created = Date.now
        self.due = Date.now
        
    }
    
    
}

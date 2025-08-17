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
    
    
    init(name: String) {
        self.name = name
        self.id = UUID()
    }
}

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

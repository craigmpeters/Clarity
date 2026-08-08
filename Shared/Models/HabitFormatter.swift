//
//  HabitFormatter.swift
//  Clarity
//
//  Created by OpenCode on 08/08/2026.
//

import Foundation

enum HabitFormatter {
    private static let formatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 2
        f.minimumFractionDigits = 0
        f.locale = Locale.current
        return f
    }()

    static func formatted(_ value: Double) -> String {
        formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    static func progressDescription(amount: Double, target: Double, unit: String?) -> String {
        let unitSuffix = unit.map { " \($0)" } ?? ""
        return "\(formatted(amount)) / \(formatted(target))\(unitSuffix)"
    }
}

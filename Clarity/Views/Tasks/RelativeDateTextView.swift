//
//  RelativeDateTextView.swift
//  Clarity
//
//  Created by Craig Peters on 20/09/2025.
//

import SwiftUI

struct RelativeDateText: View {
    let date: Date
    @Environment(\.calendar) private var calendar
    
    var body: some View {
        TimelineView(.periodic(from:Date(), by: betweenNowAndMidnight())) { _ in
            Text(format(date))
                .foregroundStyle(.secondary)
        }
    }
    
    private func format(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        formatter.doesRelativeDateFormatting = true
        return formatter.string(from: date)
    }
    
    private func betweenNowAndMidnight() -> TimeInterval {
        let now = Date()
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: now)!
        return endOfDay.timeIntervalSince(now)
    }
}

#Preview {
    let calendar = Calendar.current
    let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date()
    RelativeDateText(date: tomorrow )
}

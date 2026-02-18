//
//  WidgetCategoryProgress.swift
//  Clarity
//
//  Created by Craig Peters on 18/02/2026.
//

import SwiftUI
import SwiftData

// MARK: - Weekly Targets Progress View
struct WidgetCategoryProgress: View {
    let entry : CompletedTaskEntry
    let entries: Int
    
    
    private var currentWeekStart: Date {
        let calendar = Calendar.current
        let now = Date()
        // Get start of week (Monday)
        var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
        components.weekday = 2 // Monday
        return calendar.date(from: components) ?? now
    }
    
    private var categoryProgress: [(category: CategoryDTO, completed: Int, target: Int, progress: Double)] {
        entry.categories.compactMap { category in
            let completed = entry.tasks.filter { task in
                task.categories.contains(category)
            }.count
            
            let target = category.weeklyTarget
            let progress = target > 0 ? Double(completed) / Double(target) : 0
            
            // Only show categories with targets set
            if target > 0 {
                return (category, completed, target, min(progress, 1.0))
            }
            return nil
        }
        .sorted { $0.completed > $1.completed }
        .prefix(entries)
        .map { $0 }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Category Progress
            if !categoryProgress.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(categoryProgress, id: \.category.id) { item in
                        WidgetCategoryProgressRow(
                            category: item.category,
                            completed: item.completed,
                            target: item.target,
                            progress: item.progress
                        )
                    }
                }
            }
        }
    }
    
    private var weekDateRange: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        let endOfWeek = Calendar.current.date(byAdding: .day, value: 6, to: currentWeekStart) ?? Date()
        return "\(formatter.string(from: currentWeekStart)) - \(formatter.string(from: endOfWeek))"
    }
    
    private var daysRemainingInWeek: Int {
        let calendar = Calendar.current
        let now = Date()
        let endOfWeek = calendar.date(byAdding: .day, value: 6, to: currentWeekStart) ?? now
        let days = calendar.dateComponents([.day], from: now, to: endOfWeek).day ?? 0
        return max(0, days + 1) // +1 to include today
    }
    
    private func progressColor(for progress: Double) -> Color {
        if progress >= 1.0 { return .green }
        if progress >= 0.7 { return .blue }
        if progress >= 0.4 { return .orange }
        return .red
    }
}

// MARK: - Category Progress Row
struct WidgetCategoryProgressRow: View {
    let category: CategoryDTO
    let completed: Int
    let target: Int
    let progress: Double
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill(category.color.SwiftUIColor)
                        .frame(width: 12, height: 12)
                    
                    Text(category.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                Spacer()
                
                HStack(spacing: 4) {
                    Text("\(completed)")
                        .font(.system(.caption, design: .monospaced))
                }
            }
        }
    }
}


#if DEBUG
#Preview {
    WidgetCategoryProgress(entry: PreviewData.shared.getPreviewCompletedTaskEntry(filter: .PastWeek), entries: 2)
    .padding(20)
}
#endif


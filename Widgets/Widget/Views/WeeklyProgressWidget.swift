//
//  WeeklyProgressWidget.swift
//  Clarity
//
//  Created by Craig Peters on 14/02/2026.
//

import SwiftUI
import WidgetKit

struct WeeklyProgressWidget : View {
    
    let progress: WeeklyProgress
    var family: WidgetFamily = .systemLarge
    
    var body: some View {
        
        if progress.target > 0 {
            VStack(alignment: .leading, spacing: spacing(family: family)) {
                if family == .systemLarge {
                    HStack {
                        Label("Weekly Target", systemImage: "target")
                            .font(.caption.bold())
                            .foregroundStyle(.orange)
                        
                        Spacer()
                        
                        Text("\(progress.completed) / \(progress.target)")
                            .font(.caption)
                    }

                }
                
                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.secondary.opacity(0.2))
                            .frame(height: 6)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(progressColor(for: progress))
                            .frame(
                                width: geometry.size.width * progressPercentage(for: progress),
                                height: 6
                            )
                    }
                }
                .frame(height: 6)
            }
        }
    }
    
    private func progressColor(for progress: WeeklyProgress) -> Color {
        let percentage = progressPercentage(for: progress)
        if percentage >= 1.0 { return .green }
        if percentage >= 0.7 { return .blue }
        if percentage >= 0.4 { return .orange }
        return .red
    }
    
    private func progressPercentage(for progress: WeeklyProgress) -> Double {
        guard progress.target > 0 else { return 0 }
        return min(Double(progress.completed) / Double(progress.target), 1.0)
    }
    
    private func spacing(family: WidgetFamily) -> CGFloat {
        if family == .systemSmall { return 0 }
        return 8
    }
}

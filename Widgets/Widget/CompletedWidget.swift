//
//  CompletedWidget.swift
//  Clarity
//
//  Created by Craig Peters on 14/02/2026.
//

import WidgetKit
import SwiftUI
import SwiftData
import AppIntents

struct CompletedWidget: Widget {
    let kind: String = "CompletedWidget"
    
    var body: some WidgetConfiguration {
            AppIntentConfiguration(
                kind: kind,
                intent: CompletedTaskWidgetIntent.self,
                provider: CompletedTaskProvider()
            ) { entry in
                CompletedWidgetView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            }
            .configurationDisplayName("Completed Tasks")
            .description("View Completed Task Summary")
            .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct CompletedWidgetView: View {
    @Environment(\.widgetFamily) var widgetFamily
    let entry: CompletedTaskEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Total Tasks: \(entry.tasks.count)")
                .font(.caption)
            Spacer(minLength: 0)
            WeeklyProgressWidget(progress: entry.progress, family: widgetFamily)
                .padding(.horizontal, 0)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#if DEBUG
#Preview("Today", as: .systemSmall) {
    CompletedWidget()
} timeline: {
    PreviewData.shared.getPreviewCompletedTaskEntry(filter: .Today)
}

#Preview("This Week", as: .systemSmall) {
    CompletedWidget()
} timeline: {
    PreviewData.shared.getPreviewCompletedTaskEntry(filter: .PastWeek)
}

#Preview("All Time", as: .systemSmall) {
    CompletedWidget()
} timeline: {
    PreviewData.shared.getPreviewCompletedTaskEntry(filter: .AllTime)
}
#endif


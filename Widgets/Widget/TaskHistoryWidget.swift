//
//  TaskHistoryWidget.swift
//  Clarity
//
//  Created by Craig Peters on 17/05/2026.
//

import WidgetKit
import SwiftUI
import SwiftData
import AppIntents

struct TaskHistoryWidget: Widget {

    let kind: String = "HistoryWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: TaskHistoryWidgetIntent.self,
            provider: TaskHistoryWidgetProvider()
        ) { entry in
            TaskHistoryWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Habit History")
        .description("View a heatmap of a completed task")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Widget view

struct TaskHistoryWidgetView: View {
    @Environment(\.widgetFamily) private var widgetFamily
    let entry: TaskHistoryEntry

    private var heatmapSize: HeatmapSize {
        switch widgetFamily {
        case .systemSmall:  return .small
        case .systemMedium: return .medium
        default:            return .large
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Task name header — omit on small where space is very tight
            if widgetFamily != .systemSmall {
                Text(entry.tasks.first?.name ?? "Habit History")
                    .font(widgetFamily == .systemMedium ? .caption.bold() : .subheadline.bold())
                    .lineLimit(1)
            }

            Heatmap(tasks: entry.tasks, size: heatmapSize)
        }
        .padding(widgetFamily == .systemSmall ? 8 : 12)
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Small — Dark", as: .systemSmall) {
    TaskHistoryWidget()
} timeline: {
    TaskHistoryEntry(date: .now, uuid: UUID(), tasks: PreviewData.shared.sampleHeatmapTasks)
}

#Preview("Small — Light", as: .systemSmall) {
    TaskHistoryWidget()
} timeline: {
    TaskHistoryEntry(date: .now, uuid: UUID(), tasks: PreviewData.shared.sampleHeatmapTasks)
}

#Preview("Medium — Dark", as: .systemMedium) {
    TaskHistoryWidget()
} timeline: {
    TaskHistoryEntry(date: .now, uuid: UUID(), tasks: PreviewData.shared.sampleHeatmapTasks)
}

#Preview("Medium — Light", as: .systemMedium) {
    TaskHistoryWidget()
} timeline: {
    TaskHistoryEntry(date: .now, uuid: UUID(), tasks: PreviewData.shared.sampleHeatmapTasks)
}

#Preview("Large — Dark", as: .systemLarge) {
    TaskHistoryWidget()
} timeline: {
    TaskHistoryEntry(date: .now, uuid: UUID(), tasks: PreviewData.shared.sampleHeatmapTasks)
}

#Preview("Large — Light", as: .systemLarge) {
    TaskHistoryWidget()
} timeline: {
    TaskHistoryEntry(date: .now, uuid: UUID(), tasks: PreviewData.shared.sampleHeatmapTasks)
}
#endif

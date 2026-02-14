//
//  ClarityWidget.swift
//  Clarity
//
//  Created by Craig Peters on 02/09/2025.
//

import WidgetKit
import SwiftUI
import SwiftData
import AppIntents

// MARK: - Main Widget
struct ClarityTaskWidget: Widget {
    let kind: String = "ClarityTaskWidget"
    
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: TaskWidgetIntent.self,
            provider: ClarityWidgetProvider()
        ) { entry in
            ClarityTaskWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Clarity Tasks")
        .description("View your tasks and weekly progress")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct ClarityTaskWidgetView: View {
    @Environment(\.widgetFamily) var widgetFamily
    let entry: TaskWidgetEntry
    
    var body: some View {
        switch widgetFamily {
        case .systemSmall:
            SmallTaskWidgetView(entry: entry)
        case .systemMedium:
            MediumTaskWidgetView(entry: entry)
        case .systemLarge:
            LargeTaskWidgetView(entry: entry)
        default:
            SmallTaskWidgetView(entry: entry)
        }
    }
}

#if DEBUG
#Preview("Small", as: .systemSmall) {
    ClarityTaskWidget()
} timeline: {
    PreviewData.shared.getPreviewTaskWidgetEntry()
}
#endif


// MARK: - Preview

// TODO: Fix Preview
//#Preview("Small Widget", as: .systemSmall) {
//    ClarityTaskWidget()
//} timeline: {
//    TaskWidgetEntry(
//        date: Date(),
//        filter: .today,
//        taskCount: 3,
//        tasks: [
//            TaskWidgetEntry.TaskInfo(
//                id: "1",
//                name: "Complete project",
//                dueTime: "2:00 PM",
//                categoryColors: ["Blue"],
//                pomodoroMinutes: 25
//            )
//        ],
//        weeklyProgress: nil
//    )
//}
//
//#Preview("Medium Widget", as: .systemMedium) {
//    ClarityTaskWidget()
//} timeline: {
//    TaskWidgetEntry(
//        date: Date(),
//        filter: .today,
//        taskCount: 3,
//        tasks: [
//            TaskWidgetEntry.TaskInfo(
//                id: "1",
//                name: "Complete project",
//                dueTime: "2:00 PM",
//                categoryColors: ["Blue"],
//                pomodoroMinutes: 25
//            ),
//            TaskWidgetEntry.TaskInfo(
//                id: "2",
//                name: "Review code",
//                dueTime: "4:00 PM",
//                categoryColors: ["Green"],
//                pomodoroMinutes: 15
//            )
//        ],
//        weeklyProgress: nil
//    )
//}

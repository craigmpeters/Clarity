//
//  ClarityTaskWidget.swift
//  Clarity
//
//  Created by Craig Peters on 02/09/2025.
//
import WidgetKit
import SwiftUI
import SwiftData
import AppIntents

struct ClarityTaskWidget: Widget {
    let kind: String = "ClarityTaskWidget"
    
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: TaskWidgetConfigurationIntent.self,
            provider: TaskWidgetProvider()
        ) { entry in
            ClarityTaskWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Clarity Tasks")
        .description("View and start timers for your tasks")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct ClarityTaskWidgetEntryView: View {
    @Environment(\.widgetFamily) var widgetFamily
    let entry: TaskWidgetEntry
    
    var body: some View {
        switch widgetFamily {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        case .systemLarge:
            LargeWidgetView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
        }
    }
}

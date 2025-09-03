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

// MARK: - Main Widget
struct ClarityTaskWidget: Widget {
    let kind: String = "ClarityTaskWidget"
    
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: TaskWidgetIntent.self,
            provider: TaskWidgetProvider()
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

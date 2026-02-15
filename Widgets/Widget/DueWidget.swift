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
struct DueWidget: Widget {
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
    let gradient = Gradient(colors: [ .red, .yellow, .orange, .green])
    
    var body: some View {
        
        VStack(alignment: .leading) {
            HStack {
                HStack {
                    Image("clarity-transparent")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 40, alignment: .init(horizontal: .leading, vertical: .center))
                    Text(entry.filter.localizedStringResource)
                        .font(.title3)
                }
                .fixedSize()
                .frame(alignment: .leading)
            }
            
            Spacer()
            if widgetFamily  == .systemSmall {
                // Just show tasks total
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(entry.todos.count)")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                }
            } else {
                ForEach(entry.todos.prefix(widgetFamily == .systemMedium ? 3 : 10), id: \.id ) { todo in
                    TaskRowInteractive(task: todo)
                }
            }
            Spacer()
            HStack {
                Image(systemName: "target")
                    .foregroundStyle(.orange)
                Gauge(value: ((Double(entry.progress.completed) / Double(entry.progress.target)))) {
                }
                .gaugeStyle(LinearCapacityGaugeStyle())
                .tint(gradient)
            }
        }
    }
}

#if DEBUG
#Preview("Small", as: .systemSmall) {
    DueWidget()
} timeline: {
    PreviewData.shared.getPreviewTaskWidgetEntry()
}

#Preview("Medium", as: .systemMedium) {
    DueWidget()
} timeline: {
    PreviewData.shared.getPreviewTaskWidgetEntry()
}

#Preview("Large", as: .systemLarge) {
    DueWidget()
} timeline: {
    PreviewData.shared.getPreviewTaskWidgetEntry()
}

#endif


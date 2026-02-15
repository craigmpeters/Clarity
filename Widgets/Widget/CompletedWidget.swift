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
    
    private var gaugeData : Double
    let gradient = Gradient(colors: [ .red, .yellow, .orange, .green])
    
    init(entry: CompletedTaskEntry) {
        self.entry = entry
        print("Completed: \(entry.progress.completed) Target: \(entry.progress.target) ")
        gaugeData = Double(entry.progress.completed) / Double(entry.progress.target)
        print("GaugeData: \(gaugeData)")
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image("clarity-small")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 40, alignment: .init(horizontal: .leading, vertical: .center))
                Text(entry.filter.localizedStringResource)
                    .font(.title3)
            }
            .fixedSize()
            .frame(alignment: .leading)

            Text(String(entry.tasks.count))
                .font(.largeTitle)
            Text("Completed Tasks")
                .font(.caption2)
            Spacer(minLength: 0)
            if entry.showWeeklyProgress {
                HStack {
                    Image(systemName: "target")
                        .foregroundStyle(.orange)
                    Gauge(value: gaugeData) {
                    }
                    .gaugeStyle(LinearCapacityGaugeStyle())
                    .tint(gradient)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

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


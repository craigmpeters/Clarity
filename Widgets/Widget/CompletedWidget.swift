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
            .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryCircular])
    }
}

struct CompletedWidgetView: View {
    @Environment(\.widgetFamily) var widgetFamily
    let entry: CompletedTaskEntry
    @Query private var categories: [Category]
    
    private var gaugeData : Double
    let gradient = Gradient(colors: [ .red, .orange, .yellow, .green])
    
    init(entry: CompletedTaskEntry) {
        self.entry = entry
        print("Completed: \(entry.progress.completed) Target: \(entry.progress.target) ")
        gaugeData = Double(entry.progress.completed) / Double(entry.progress.target)
        print("GaugeData: \(gaugeData)")
    }
    
    var body: some View {
        switch widgetFamily {
        case .systemLarge, .systemMedium:
            EmptyView()
            
        case .accessoryCircular:
            if entry.showWeeklyProgress {
                Gauge(value: Double(entry.progress.completed), in: 0.0...Double(entry.progress.target)) {
                    Image(systemName: "target")
                } currentValueLabel: {
                    Text(String(entry.tasks.count))
                } minimumValueLabel: {
                    Text(String(0))
                } maximumValueLabel: {
                    Text(String(entry.progress.target))
                }
                .gaugeStyle(.accessoryCircular)
            } else {
                Text(String(entry.tasks.count))
            }
        default:
            EmptyView()
        }
        
        if widgetFamily == .accessoryCircular {


        } else {
            
            
            VStack(alignment: .center, spacing: 6) {
                if widgetFamily != .accessoryRectangular {
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
                }
                
                HStack {
                    if widgetFamily == .accessoryRectangular {
                        HStack {
                            //
                            Image("clarity-small")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 40, alignment: .init(horizontal: .leading, vertical: .center))
                            Spacer()
                            Image(systemName: "checkmark.square.fill")
                            Text(String(entry.tasks.count))
                        }
                    } else {
                        VStack {
                            Text(String(entry.tasks.count))
                                .font(.largeTitle)
                            Text("Completed Tasks")
                                .font(.caption2)
                            Spacer(minLength: 0)
                        }
                    }
                    
                    if widgetFamily == .systemMedium {
                        HStack {
                            WidgetCategoryProgress(entry: entry, entries: 2 )
                        }
                        .frame(alignment: .top)
                    }
                }
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
}

#if DEBUG
#Preview("Today", as: .systemSmall) {
    CompletedWidget()
} timeline: {
    PreviewData.shared.getPreviewCompletedTaskEntry(filter: .Today)
}

#Preview("Today - Rectangular", as: .accessoryRectangular) {
    CompletedWidget()
} timeline: {
    PreviewData.shared.getPreviewCompletedTaskEntry(filter: .Today)
}

#Preview("This Week", as: .systemMedium) {
    CompletedWidget()
} timeline: {
    PreviewData.shared.getPreviewCompletedTaskEntry(filter: .PastWeek)
}

#Preview("This Week - Circular", as: .accessoryCircular) {
    CompletedWidget()
} timeline: {
    PreviewData.shared.getPreviewCompletedTaskEntry(filter: .PastWeek)
}

#Preview("All Time", as: .systemSmall) {
    CompletedWidget()
} timeline: {
    PreviewData.shared.getPreviewCompletedTaskEntry(filter: .Month)
}
#endif


//
//  ClarityWatchCompletedWidget.swift
//  Clarity
//
//  Created by Craig Peters on 01/03/2026.
//


import WidgetKit
import SwiftUI
import OSLog
import XCGLogger

struct WatchCompletedWidgetProvider : AppIntentTimelineProvider {
    
    func recommendations() -> [AppIntentRecommendation<WatchCompleteWidgetIntent>] {
        [
            AppIntentRecommendation(intent: WatchCompleteWidgetIntent(), description: Text("Completed Today")),
            AppIntentRecommendation(intent: WatchCompleteWidgetIntent(ToDoTask.CompletedTaskFilter.PastWeek), description: Text("Completed This Week"))
        ]
    }
    
    func placeholder(in context: Context) -> WatchCompleteEntry {
        WatchCompleteEntry(date: .now, todos: [], filter: .Today, progress: getWeeklyProgress())
    }
    
    func snapshot(for configuration: WatchCompleteWidgetIntent, in context: Context) async -> WatchCompleteEntry {
        var tasks : [ToDoTaskDTO] = []
        do {
            tasks = try WidgetFileCoordinator.shared.readTasks(With: configuration.dateFilter)
            tasks = tasks.filter { $0.completed }
        } catch {
            LogManager.shared.log.error("Could not get tasks: \(error.localizedDescription)")
        }
        return WatchCompleteEntry(date: .now, todos: tasks, filter: configuration.dateFilter, progress: getWeeklyProgress())
    }
    
    func timeline(for configuration: WatchCompleteWidgetIntent, in context: Context) async -> Timeline<WatchCompleteEntry> {
        var tasks: [ToDoTaskDTO] = []
        do {
            tasks = try WidgetFileCoordinator.shared.readTasks(With: configuration.dateFilter)
            tasks = tasks.filter { $0.completed }
        } catch {
            LogManager.shared.log.error("Could not get tasks: \(error.localizedDescription)")
        }
        
        let entry = WatchCompleteEntry(date: .now, todos: tasks, filter: configuration.dateFilter, progress: getWeeklyProgress())
        
        let cal = Calendar.current
        let now = Date()
        
        // Always update at midnight (when day changes)
        let nextMidnight = cal.startOfDay(for: cal.date(byAdding: .day, value: 1, to: now) ?? now)
        
        // For frequent updates during the day, update every 15 minutes
        let next15Minutes = cal.date(byAdding: .minute, value: 15, to: now) ?? now
        
        // Use whichever comes first - this ensures we update at midnight for date changes
        let nextUpdate = min(nextMidnight, next15Minutes)
        
        return Timeline(entries: [entry], policy: .after(nextUpdate))
        
    }
    
    private func getWeeklyProgress() -> WeeklyProgress {
        if let progress = WidgetFileCoordinator.shared.readWeeklyProgress() {
            return progress
        } else {
            return WeeklyProgress(completed: 0, target: 0, error: nil, categories: [])
        }
    }
    
}

struct WatchCompleteWidget: Widget {
    let kind: String = "WatchCompleteWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: WatchCompleteWidgetIntent.self, provider: WatchCompletedWidgetProvider()) { entry in
            ClarityWatchCompleteView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .supportedFamilies([.accessoryCircular, .accessoryCorner, .accessoryRectangular, .accessoryInline])
    }
}


struct ClarityWatchCompleteView: View {
    @Environment(\.widgetFamily) var widgetFamily
    var entry: WatchCompleteEntry
    
    var body: some View {
        switch widgetFamily {
        case .accessoryCorner:
            Image("clarity-teeny")
                .renderingMode(.original)
                .resizable()
                .scaledToFit()
                .widgetLabel {
                    Text("\(entry.todos.count) • \(entry.filter.rawValue)")
                }
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Image("clarity-teeny")
                        .renderingMode(.original)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 12, height: 12)
                    Text(entry.filter.rawValue)
                        .fontWeight(.semibold)
                    Spacer()
                    Text("\(entry.todos.count)")
                        .fontWeight(.bold)
                }
                .font(.caption2)
                if entry.progress.target > 0 {
                    Gauge(value: Double(entry.todos.count), in: 0.0...Double(entry.progress.target)) {
                        EmptyView()
                    }
                    .gaugeStyle(.accessoryLinear)
                    .tint(.clarityYellow)
                }
            }
        default:
            VStack{
                ZStack {
                    if entry.progress.target > 0 {
                        Gauge(value: Double(entry.progress.completed), in: 0.0...Double(entry.progress.target)) {
                            Image(systemName: "target")
                        } currentValueLabel: {
                            Text(String(entry.todos.count))
                        } minimumValueLabel: {
                            Text(String(0))
                        } maximumValueLabel: {
                            Text(String(entry.progress.target))
                        }
                        .gaugeStyle(.accessoryCircular)
                        .tint(.clarityYellow)
                    } else {
                        Gauge(value: Double(entry.todos.count), in: 0...10) {
                            Image(systemName: "checkmark")
                                .widgetAccentable()
                        } currentValueLabel: {
                            Text(String(entry.todos.count))
                                .minimumScaleFactor(0.4)
                                .widgetAccentable()
                        }
                        .gaugeStyle(.accessoryCircular)
                        .tint(entry.todos.count > 0 ? .clarityYellow : .secondary)
                    }
                }
            }
        }
    }
}


#Preview("Accessory - Rectangular", as: .accessoryRectangular) {
    WatchCompleteWidget()
} timeline: {
    PreviewData.shared.getPreviewWatchWidgetCompleteEntry()
}

#Preview("Accessory - Corner", as: .accessoryCorner) {
    WatchCompleteWidget()
} timeline: {
    PreviewData.shared.getPreviewWatchWidgetCompleteEntry()
}

#Preview("Accessory - Circular", as: .accessoryCircular) {
    WatchCompleteWidget()
} timeline: {
    PreviewData.shared.getPreviewWatchWidgetCompleteEntry()
}

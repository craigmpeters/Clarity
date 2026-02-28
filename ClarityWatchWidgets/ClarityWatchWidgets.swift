//
//  ClarityWatchWidgets.swift
//  ClarityWatchWidgets
//
//  Created by Craig Peters on 22/02/2026.
//

import WidgetKit
import SwiftUI
import OSLog
import XCGLogger


struct WatchDueWidgetProvider: AppIntentTimelineProvider {
    func recommendations() -> [AppIntentRecommendation<WatchDueWidgetIntent>] {
        [AppIntentRecommendation(intent: WatchDueWidgetIntent(), description: Text("All Tasks"))]
    }
    
    func placeholder(in context: Context) -> WatchWidgetEntry {
        WatchWidgetEntry(date: .now, todos: [], filter: .all)
    }

    func snapshot(for configuration: WatchDueWidgetIntent, in context: Context) async -> WatchWidgetEntry {
        
        var tasks : [ToDoTaskDTO] = []
        do {
            tasks = try WidgetFileCoordinator.shared.readTasks(with: configuration.filter.toTaskFilter())
            tasks = tasks.filter { !$0.completed }
        } catch {
            LogManager.shared.log.error("Could not get tasks: \(error.localizedDescription)")
        }
        // TODO: Is this required?
        tasks = ToDoTaskDTO.focusFilter(in: tasks)
        return WatchWidgetEntry(date: .now, todos: tasks, filter: configuration.filter)
    }
    
    func timeline(for configuration: WatchDueWidgetIntent, in context: Context) async -> Timeline<WatchWidgetEntry> {
        var tasks : [ToDoTaskDTO] = []
        do {
            tasks = try WidgetFileCoordinator.shared.readTasks(with: configuration.filter.toTaskFilter())
            tasks = tasks.filter { !$0.completed }
        } catch {
            LogManager.shared.log.error("Could not get tasks: \(error.localizedDescription)")
        }
        
        let selectedCategories : [CategoryEntity] = configuration.categoryFilter
        if selectedCategories.count > 0 {
            let selectedCategoryNames = Set(selectedCategories.map(\.name))
            tasks = tasks.filter { task in
                let taskCategories = Set((task.categories).compactMap(\.name))
                return !taskCategories.isDisjoint(with: selectedCategoryNames)
            }
        }
        
        tasks = ToDoTaskDTO.focusFilter(in: tasks)
        let entry = WatchWidgetEntry(date: .now, todos: tasks, filter: configuration.filter)
        
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
}

struct ClarityWatchWidgetDueView : View {
    @Environment(\.widgetFamily) var widgetFamily
    var entry: WatchWidgetEntry

    var body: some View {
        switch widgetFamily {
        case .accessoryRectangular:
            VStack {
                ZStack {
                    Circle()
                        .fill(.clarityBlue)
                        .stroke(.clarityYellow, style: StrokeStyle(lineWidth: 4))
                    VStack {
                        Text(entry.filter.rawValue)
                            .font(.caption)
                        Text(String(entry.todos.count))
                    }
                }
            }
        default:
            EmptyView()
        }
        

    }
}

struct WatchDueWidget: Widget {
    let kind: String = "WatchDueWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: WatchDueWidgetIntent.self, provider: WatchDueWidgetProvider()) { entry in
            ClarityWatchWidgetDueView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
    }
}

#Preview(as: .accessoryRectangular) {
    WatchDueWidget()
} timeline: {
    PreviewData.shared.getPreviewWatchWidgetEntry()
}

#Preview(as: .accessoryCircular) {
    WatchDueWidget()
} timeline: {
    PreviewData.shared.getPreviewWatchWidgetEntry()
}

#Preview(as: .accessoryCorner) {
    WatchDueWidget()
} timeline: {
    PreviewData.shared.getPreviewWatchWidgetEntry()
}

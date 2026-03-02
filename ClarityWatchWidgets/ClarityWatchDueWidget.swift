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


extension ToDoTask.TaskFilterOption {
    var systemImage: String {
        switch self {
        case .all: return "tray.full"
        case .today: return "calendar.circle"
        case .tomorrow: return "calendar.badge.plus"
        case .thisWeek: return "calendar"
        case .overdue: return "exclamationmark.triangle"
        }
    }

    var color: Color {
        switch self {
        case .all: return .gray
        case .today: return .green
        case .tomorrow: return .blue
        case .thisWeek: return .purple
        case .overdue: return .red
        }
    }
}

struct WatchDueWidgetProvider: AppIntentTimelineProvider {
    func recommendations() -> [AppIntentRecommendation<WatchDueWidgetIntent>] {
        [AppIntentRecommendation(intent: WatchDueWidgetIntent(), description: Text("Overdue Tasks")),
         AppIntentRecommendation(intent: WatchDueWidgetIntent(ToDoTask.TaskFilterOption.today, categoryFilter: []), description: Text("Todays Tasks"))
        ]
    }
    
    func placeholder(in context: Context) -> WatchDueEntry {
        WatchDueEntry(date: .now, todos: [], filter: .all)
    }

    func snapshot(for configuration: WatchDueWidgetIntent, in context: Context) async -> WatchDueEntry {
        
        var tasks : [ToDoTaskDTO] = []
        do {
            tasks = try WidgetFileCoordinator.shared.readTasks(with: configuration.filter.toTaskFilter())
            tasks = tasks.filter { !$0.completed }
        } catch {
            LogManager.shared.log.error("Could not get tasks: \(error.localizedDescription)")
        }
        // TODO: Is this required? I am not sure it will even work.
        tasks = ToDoTaskDTO.focusFilter(in: tasks)
        return WatchDueEntry(date: .now, todos: tasks, filter: configuration.filter)
    }
    
    func timeline(for configuration: WatchDueWidgetIntent, in context: Context) async -> Timeline<WatchDueEntry> {
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
        let entry = WatchDueEntry(date: .now, todos: tasks, filter: configuration.filter)
        
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
    var entry: WatchDueEntry

    var body: some View {
        switch widgetFamily {
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
                        .foregroundStyle(entry.filter.color)
                    Spacer()
                    Text("\(entry.todos.count)")
                        .fontWeight(.bold)
                        .foregroundStyle(entry.todos.count > 0 ? entry.filter.color : .secondary)
                }
                .font(.caption2)
                if entry.todos.isEmpty {
                    Text("No tasks")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ForEach(entry.todos.prefix(2), id: \.uuid) { task in
                        Text(task.name)
                            .font(.caption)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            
        case .accessoryCircular:
            ZStack {
                Circle()
                    .fill(.clarityBlue)
                    .stroke(.clarityYellow, style: StrokeStyle(lineWidth: 4))
                Text(String(entry.todos.count))
                    .font(.title)
                    .fontWeight(.bold)
                    .minimumScaleFactor(0.4)
                    .lineLimit(1)
                    .padding(8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
        case .accessoryCorner:
            Image("clarity-teeny")
                .renderingMode(.original)
                .resizable()
                .scaledToFit()
                .widgetLabel {
                    Text("\(entry.todos.count) • \(entry.filter.rawValue)")
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
        .supportedFamilies([.accessoryCircular, .accessoryCorner, .accessoryRectangular, .accessoryInline])
    }
}

#Preview("Accessory - Rectangular", as: .accessoryRectangular) {
    WatchDueWidget()
} timeline: {
    PreviewData.shared.getPreviewWatchWidgetDueEntry()
}

#Preview("Accessory - Circular", as: .accessoryCircular) {
    WatchDueWidget()
} timeline: {
    PreviewData.shared.getPreviewWatchWidgetDueEntry()
}

#Preview("Accessory - Corner", as: .accessoryCorner) {
    WatchDueWidget()
} timeline: {
    PreviewData.shared.getPreviewWatchWidgetDueEntry()
}

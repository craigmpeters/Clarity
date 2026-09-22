import SwiftUI
import os

enum RecurrenceDescription {
    static func forTask(
        repeating: Bool,
        interval: ToDoTask.RecurrenceInterval?,
        customRecurrenceDays: Int,
        everySpecificDayDay: Int?
    ) -> String? {
        guard repeating, let interval else { return nil }

        if interval == .custom {
            if customRecurrenceDays == 1 {
                return "Daily"
            } else {
                return "Every \(customRecurrenceDays) days"
            }
        }

        if interval == .specific {
            if let symbolIndex = everySpecificDayDay {
                return Calendar.current.weekdaySymbols[symbolIndex]
            }
        }
        return interval.displayName
    }
}

struct RecurrenceIndicatorBadge: View {
    let task: ToDoTask
    var showIcon: Bool = true
    var style: BadgeStyle = .subtle
    
    enum BadgeStyle {
        case subtle
        case prominent
        case compact
        
        var backgroundColor: Color {
            switch self {
            case .subtle:
                return Color.secondary.opacity(0.1)
            case .prominent:
                return Color.blue.opacity(0.15)
            case .compact:
                return Color.clear
            }
        }
        
        var foregroundColor: Color {
            switch self {
            case .subtle:
                return .secondary
            case .prominent:
                return .blue
            case .compact:
                return .secondary
            }
        }
    }
    
    
    
    private var recurrenceDescription: String? {
        RecurrenceDescription.forTask(
            repeating: task.repeating ?? false,
            interval: task.recurrenceInterval,
            customRecurrenceDays: task.customRecurrenceDays,
            everySpecificDayDay: task.everySpecificDayDay
        )
    }
    
    var body: some View {
        if let description = recurrenceDescription {
            HStack(spacing: 4) {
                if showIcon {
                    Image(systemName: "repeat")
                        .font(.caption2)
                }
                Text(description)
                    .font(.caption2)
                    .lineLimit(1)
            }
            .foregroundStyle(style.foregroundColor)
            .padding(.horizontal, style == .compact ? 0 : 6)
            .padding(.vertical, style == .compact ? 0 : 2)
            .background(style.backgroundColor)
            .cornerRadius(6)
        }

    }
}

#if DEBUG
#Preview("Every Monday") {
    HStack {
        RecurrenceIndicatorBadge(task: PreviewData.shared.makeEveryMonday(PreviewData.shared.getToDoTask()))
    }
    .padding(4)
    
}
#endif

import Foundation
import SwiftUI

// MARK: - HeatmapTask protocol

/// Abstracts over ToDoTask and ToDoTaskDTO so Heatmap works in both app and widget contexts.
protocol HeatmapTask {
    var heatmapName: String { get }
    var heatmapDue: Date { get }
    var heatmapCompletedAt: Date? { get }
    var heatmapCompleted: Bool { get }
    var heatmapRecurrenceInterval: ToDoTask.RecurrenceInterval? { get }
    var heatmapCustomRecurrenceDays: Int { get }
}

extension ToDoTask: HeatmapTask {
    var heatmapName: String                                      { name ?? "Unnamed" }
    var heatmapDue: Date                                         { due }
    var heatmapCompletedAt: Date?                                { completedAt }
    var heatmapCompleted: Bool                                   { completed }
    var heatmapRecurrenceInterval: ToDoTask.RecurrenceInterval?  { recurrenceInterval }
    var heatmapCustomRecurrenceDays: Int                         { customRecurrenceDays }
}

extension ToDoTaskDTO: HeatmapTask {
    var heatmapName: String                                      { name }
    var heatmapDue: Date                                         { due }
    var heatmapCompletedAt: Date?                                { completedAt }
    var heatmapCompleted: Bool                                   { completed }
    var heatmapRecurrenceInterval: ToDoTask.RecurrenceInterval?  { recurrenceInterval }
    var heatmapCustomRecurrenceDays: Int                         { customRecurrenceDays }
}

// MARK: - Widget size preset

/// Drives sensible defaults for each widget family without importing WidgetKit into shared code.
enum HeatmapSize {
    /// ~155×155 pt — 7 cols × 4 rows = 28 days, no chrome
    case small
    /// ~329×155 pt — 10 cols × 3 rows = 30 days, no chrome
    case medium
    /// ~329×345 pt — 10 cols × 6 rows = 60 days, labels + legend
    case large
    /// Free-form in-app use; caller sets columns/rows/labels/legend manually
    case custom

    var columns: Int {
        switch self {
        case .small:  return 7
        case .medium: return 10
        case .large:  return 10
        case .custom: return 10
        }
    }

    var rows: Int {
        switch self {
        case .small:  return 4
        case .medium: return 3
        case .large:  return 6
        case .custom: return 6
        }
    }

    var showMonthLabels: Bool { self == .large || self == .custom }
    var showLegend: Bool     { self == .large || self == .custom }
    /// Tooltips and haptics are unavailable in widget contexts
    var isInteractive: Bool  { self == .custom }
}

// MARK: - Heatmap math

enum HeatmapMath {
    static func latenessRatio(for task: any HeatmapTask, completedAt: Date?, interval: ToDoTask.RecurrenceInterval?) -> Double {
        guard let completedAt else { return 0 }
        let secondsLate = completedAt.timeIntervalSince(task.heatmapDue)
        guard secondsLate > 0 else { return 0 }

        let intervalSecs = intervalDuration(for: interval, customDays: task.heatmapCustomRecurrenceDays)
        guard intervalSecs > 0 else {
            return min(secondsLate / (7 * 24 * 3600), 1.0)
        }
        return min(secondsLate / intervalSecs, 1.0)
    }

    static func intervalDuration(for interval: ToDoTask.RecurrenceInterval?, customDays: Int) -> TimeInterval {
        guard let interval else { return 0 }
        switch interval {
        case .daily:         return 1  * 24 * 3600
        case .everyOtherDay: return 2  * 24 * 3600
        case .weekly:        return 7  * 24 * 3600
        case .biweekly:      return 14 * 24 * 3600
        case .monthly:       return 30 * 24 * 3600
        case .custom:        return Double(customDays) * 24 * 3600
        case .specific:      return 7  * 24 * 3600
        }
    }

    static func buildDays(totalDays: Int, tasks: [any HeatmapTask], referenceDate: Date) -> [DayEntry] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: referenceDate)

        var dayTasks: [Date: [any HeatmapTask]] = [:]
        for task in tasks where task.heatmapCompleted {
            guard let completedAt = task.heatmapCompletedAt else { continue }
            let dayStart = calendar.startOfDay(for: completedAt)
            dayTasks[dayStart, default: []].append(task)
        }

        return (0..<totalDays).map { offset in
            let daysAgo = (totalDays - 1) - offset
            let date = calendar.date(byAdding: .day, value: -daysAgo, to: today) ?? today
            let tasksOnDay = dayTasks[date] ?? []
            let bestRatio = tasksOnDay.map { HeatmapMath.latenessRatio(for: $0, completedAt: $0.heatmapCompletedAt, interval: $0.heatmapRecurrenceInterval) }.min()
            return DayEntry(date: date, tasks: tasksOnDay, bestLatenessRatio: bestRatio)
        }
    }
}

// MARK: - Public view

struct Heatmap: View {
    let tasks: [any HeatmapTask]

    /// Pass a preset to get sensible widget defaults, or use .custom and set the properties below.
    var size: HeatmapSize = .custom

    /// Override individual properties when using .custom (ignored for other sizes)
    var columns: Int?
    var rows: Int?
    var showMonthLabels: Bool?
    var showLegend: Bool?
    /// Fraction of cell size used as gap (e.g. 0.15 = 15% of a cell width)
    var spacingRatio: CGFloat = 0.15

    @Environment(\.colorScheme) private var colorScheme

    // Resolved values — preset wins unless .custom and override provided
    private var resolvedColumns: Int      { size == .custom ? (columns ?? size.columns) : size.columns }
    private var resolvedRows: Int         { size == .custom ? (rows ?? size.rows) : size.rows }
    private var resolvedMonthLabels: Bool { size == .custom ? (showMonthLabels ?? size.showMonthLabels) : size.showMonthLabels }
    private var resolvedLegend: Bool      { size == .custom ? (showLegend ?? size.showLegend) : size.showLegend }

    var body: some View {
        GeometryReader { geo in
            let totalDays = resolvedColumns * resolvedRows
            let spacing = geo.size.width / CGFloat(resolvedColumns) * spacingRatio
            let cellSize = (geo.size.width - spacing * CGFloat(resolvedColumns - 1)) / CGFloat(resolvedColumns)
            let entries = HeatmapMath.buildDays(totalDays: totalDays, tasks: tasks, referenceDate: Date())

            VStack(alignment: .leading, spacing: spacing) {
                if resolvedMonthLabels {
                    MonthLabelRow(entries: entries, columns: resolvedColumns, cellSize: cellSize, spacing: spacing)
                }

                // Grid — background matches cell hue so gaps don't create contrast halos
                LazyVGrid(
                    columns: Array(repeating: GridItem(.fixed(cellSize), spacing: spacing), count: resolvedColumns),
                    spacing: spacing
                ) {
                    ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                        DayCell(
                            entry: entry,
                            size: cellSize,
                            isInteractive: size.isInteractive
                        )
                        .transition(.opacity)
                        .animation(
                            size.isInteractive
                                ? .easeIn(duration: 0.2).delay(Double(index) * 0.008)
                                : .none,
                            value: entries.count
                        )
                    }
                }
                .padding(spacing)
                .background(
                    RoundedRectangle(cornerRadius: cellSize * 0.18)
                        .fill(gridBackgroundColor)
                )

                if resolvedLegend {
                    HeatmapLegend(cellSize: cellSize, spacing: spacing, colorScheme: colorScheme)
                }
            }
        }
        .frame(minHeight: intrinsicHeight)
    }

    private var gridBackgroundColor: Color {
        colorScheme == .dark
            ? Color(hue: 0.60, saturation: 0.20, brightness: 0.10)
            : Color(hue: 0.60, saturation: 0.08, brightness: 0.96)
    }

    // MARK: Tooltip helpers

    private func latenessRatio(for task: any HeatmapTask) -> Double {
        HeatmapMath.latenessRatio(for: task, completedAt: task.heatmapCompletedAt, interval: task.heatmapRecurrenceInterval)
    }

    private func intervalDuration(for task: any HeatmapTask) -> TimeInterval {
        HeatmapMath.intervalDuration(for: task.heatmapRecurrenceInterval, customDays: task.heatmapCustomRecurrenceDays)
    }

    /// Estimated minimum height so GeometryReader doesn't collapse to zero.
    private var intrinsicHeight: CGFloat {
        let estimatedCell: CGFloat = 32
        let estimatedSpacing: CGFloat = estimatedCell * 0.15
        let gridHeight = CGFloat(resolvedRows) * estimatedCell + CGFloat(resolvedRows - 1) * estimatedSpacing
        let labelsHeight: CGFloat = resolvedMonthLabels ? 16 + estimatedSpacing : 0
        let legendHeight: CGFloat = resolvedLegend ? 20 + estimatedSpacing : 0
        return gridHeight + labelsHeight + legendHeight
    }
}

// MARK: - Day model

struct DayEntry: Identifiable {
    let date: Date
    /// All completed tasks on this day
    let tasks: [any HeatmapTask]
    /// nil = no completion; 0.0 = on time; 1.0 = full interval late
    let bestLatenessRatio: Double?

    var id: Date { date }
    var isToday: Bool { Calendar.current.isDateInToday(date) }
    var isFuture: Bool { date > Calendar.current.startOfDay(for: Date()) }
}

// MARK: - Day cell

private struct DayCell: View {
    let entry: DayEntry
    let size: CGFloat
    /// False in widget contexts — disables tap, haptic, and popover
    let isInteractive: Bool

    @Environment(\.colorScheme) private var colorScheme
    @State private var showTooltip = false

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.18)
            .fill(cellColor)
            .overlay(
                // Today marker — contrasting border
                entry.isToday
                    ? RoundedRectangle(cornerRadius: size * 0.18)
                        .strokeBorder(
                            colorScheme == .dark ? Color.white.opacity(0.85) : Color.black.opacity(0.55),
                            lineWidth: max(1.5, size * 0.06)
                        )
                    : nil
            )
            .frame(width: size, height: size)
            .if(isInteractive) { cell in
                cell
                    .onTapGesture {
                        let impact = UIImpactFeedbackGenerator(style: .light)
                        impact.impactOccurred()
                        showTooltip.toggle()
                    }
                    .popover(isPresented: $showTooltip) {
                        TooltipContent(entry: entry)
                            .padding(12)
                            .presentationCompactAdaptation(.popover)
                    }
            }
            .accessibilityLabel(accessibilityLabel)
            .accessibilityHint(isInteractive && !entry.tasks.isEmpty ? "Double tap to see details" : "")
    }

    private var cellColor: Color {
        if colorScheme == .dark {
            return darkCellColor
        } else {
            return lightCellColor
        }
    }

    // Dark mode: dark navy background, vivid blue = on time
    private var darkCellColor: Color {
        if entry.isFuture {
            return Color(hue: 0.60, saturation: 0.30, brightness: 0.08)
        }
        guard let ratio = entry.bestLatenessRatio else {
            return Color(hue: 0.60, saturation: 0.25, brightness: 0.18)
        }
        return completionColor(for: ratio, scheme: .dark)
    }

    // Light mode: pale blue background, vivid blue = on time, slightly darker = late
    private var lightCellColor: Color {
        if entry.isFuture {
            return Color(hue: 0.60, saturation: 0.06, brightness: 0.94)
        }
        guard let ratio = entry.bestLatenessRatio else {
            return Color(hue: 0.60, saturation: 0.10, brightness: 0.90)
        }
        return completionColor(for: ratio, scheme: .light)
    }

    private var accessibilityLabel: String {
        let dateStr = entry.date.formatted(date: .long, time: .omitted)
        if entry.isFuture {
            return "\(dateStr), future"
        }
        if entry.tasks.isEmpty {
            return "\(dateStr), no tasks completed"
        }
        let count = entry.tasks.count
        let taskWord = count == 1 ? "task" : "tasks"
        let ratio = entry.bestLatenessRatio ?? 0
        let timing = ratio == 0 ? "on time" : "\(Int(ratio * 100))% into interval"
        return "\(dateStr), \(count) \(taskWord) completed, best \(timing)"
    }
}

private extension View {
    /// Applies a transform only when `condition` is true.
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition { transform(self) } else { self }
    }
}

// MARK: - Tooltip

private struct TooltipContent: View {
    let entry: DayEntry
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(entry.date.formatted(date: .long, time: .omitted))
                .font(.caption.bold())

            if entry.tasks.isEmpty {
                Text("No tasks completed")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(entry.tasks.enumerated()), id: \.offset) { _, task in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(completionColor(for: HeatmapMath.latenessRatio(for: task, completedAt: task.heatmapCompletedAt, interval: task.heatmapRecurrenceInterval), scheme: colorScheme))
                            .frame(width: 8, height: 8)

                        Text(task.heatmapName)
                            .font(.caption2)

                        Spacer(minLength: 0)

                        let ratio = HeatmapMath.latenessRatio(for: task, completedAt: task.heatmapCompletedAt, interval: task.heatmapRecurrenceInterval)
                        Text(ratio == 0 ? "On time" : "\(Int(ratio * 100))% late")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .frame(minWidth: 180)
    }
}

// MARK: - Month labels

private struct MonthLabelRow: View {
    let entries: [DayEntry]
    let columns: Int
    let cellSize: CGFloat
    let spacing: CGFloat

    /// Column indices where the month changes (or the first column)
    private var labelPositions: [(column: Int, label: String)] {
        var result: [(Int, String)] = []
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        var lastMonth = -1

        for (index, entry) in entries.enumerated() {
            let col = index % columns
            let month = Calendar.current.component(.month, from: entry.date)
            if month != lastMonth {
                result.append((col, formatter.string(from: entry.date)))
                lastMonth = month
            }
        }
        return result
    }

    var body: some View {
        // Overlay labels at the correct horizontal position
        ZStack(alignment: .topLeading) {
            Color.clear.frame(height: 14)

            ForEach(labelPositions, id: \.column) { col, label in
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .offset(x: CGFloat(col) * (cellSize + spacing))
            }
        }
    }
}

// MARK: - Legend

private struct HeatmapLegend: View {
    let cellSize: CGFloat
    let spacing: CGFloat
    let colorScheme: ColorScheme

    private let swatchSize: CGFloat = 10

    var body: some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2)
                .fill(colorScheme == .dark
                      ? Color(hue: 0.60, saturation: 0.25, brightness: 0.18)
                      : Color(hue: 0.60, saturation: 0.10, brightness: 0.90))
                .frame(width: swatchSize, height: swatchSize)
            Text("None")
                .font(.system(size: 9))
                .foregroundStyle(.secondary)

            Spacer()

            Text("On time")
                .font(.system(size: 9))
                .foregroundStyle(.secondary)

            ForEach(0..<5) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(completionColor(for: Double(i) / 4, scheme: colorScheme))
                    .frame(width: swatchSize, height: swatchSize)
            }

            Text("Late")
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Colour helper

/// Single-hue blue ramp, adapted per colour scheme.
///
/// Dark mode:  vivid bright blue (on time) → dark desaturated navy (late)
/// Light mode: vivid mid blue (on time) → darker, more saturated blue (late)
/// Both directions keep the hue constant so no Mach-band effect occurs at cell boundaries.
private func completionColor(for ratio: Double, scheme: ColorScheme) -> Color {
    if scheme == .dark {
        // Bright vivid → dark desaturated
        let brightness = 0.85 - ratio * 0.60   // 0.85 → 0.25
        let saturation = 1.0  - ratio * 0.55   // 1.00 → 0.45
        return Color(hue: 0.60, saturation: saturation, brightness: brightness)
    } else {
        // Light mode: mid-bright vivid → deeper, more saturated
        // On time: bright sky blue; late: deep navy (still readable on white)
        let brightness = 0.80 - ratio * 0.45   // 0.80 → 0.35
        let saturation = 0.70 + ratio * 0.30   // 0.70 → 1.00
        return Color(hue: 0.60, saturation: saturation, brightness: brightness)
    }
}

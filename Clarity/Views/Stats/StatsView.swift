import SwiftUI
import SwiftData
import Charts
import os
import UniformTypeIdentifiers
import UIKit

// MARK: - Habit Streak Data Types

struct HabitStreakRow: Identifiable, Sendable {
    let id = UUID()
    let uuid: UUID
    let name: String
    let currentStreak: Int
    let longestStreak: Int
    let freezes: Int
    let completedThisWeek: Int
    let weeklyFrequency: Int
}

// Timeframe selection pill component
struct TimeframePill: View {
    let timeframe: StatsTimeframe
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(timeframe.rawValue)
                    .font(.system(.subheadline, weight: isSelected ? .semibold : .regular))

                if isSelected {
                    Text(timeframe.shortDescription)
                        .font(.caption2)
                        .opacity(0.8)
                }
            }
            .foregroundColor(isSelected ? .white : .primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isSelected ? Color.accentColor : Color.secondary.opacity(0.15))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct StatsView: View {
    @Query private var allTasks: [ToDoTask]
    @Query private var allCategories: [Category]
    @Query private var allHabits: [Habit]
    
    
    @State private var selectedTimeframe: StatsTimeframe = .last7Days
    @State private var selectedCategory: Category? = nil
    @Environment(\.modelContext) private var modelContext
    @Environment(CompanionService.self) private var companion
    // Track last-seen streak to only fire companion once per milestone
    @State private var lastReportedStreak: Int = 0
    @State private var habitStreaks: [HabitStreakRow] = []

    @State private var isPresentingShareSheet = false
    @State private var shareItems: [Any]? = nil
    @State private var shareSubject: String? = nil
    @State private var summary: StatisticsSummary = StatisticsCalculator.summary(
        from: [],
        timeframe: .last7Days
    )

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {

                    // Timeframe selector with horizontal scroll
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Time Period")
                            .font(.headline)
                            .padding(.horizontal)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(StatsTimeframe.allCases, id: \.self) { timeframe in
                                    TimeframePill(
                                        timeframe: timeframe,
                                        isSelected: selectedTimeframe == timeframe
                                    ) {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            selectedTimeframe = timeframe
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }

                        Text(selectedTimeframe.dateRange)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                    }

                    // Overview Cards
                    OverviewCardsView(metrics: summary.overview)
                        .padding(.horizontal)

                    // Category completion chart
                    CategoryCompletionChart(
                        data: summary.categoryData,
                        timeframe: selectedTimeframe
                    )
                    .frame(height: 300)
                    .padding(.horizontal)

                    // Productivity Heatmap
                    ProductivityHeatmap(data: summary.hourlyData)
                        .padding()

                    // Weekly Targets Progress
                    WeeklyTargetsProgressView(tasks: allTasks.filter(\.completed))
                        .padding(.horizontal)

                    Divider()
                        .padding(.horizontal)

                    // Daily breakdown
                    WeeklyBreakdownView(
                        data: summary.dailyData,
                        timeframe: selectedTimeframe
                    )
                    .padding(.horizontal)

                    // Streak tracking
                    StreakView(streak: summary.streak)
                        .padding(.horizontal)

                    // Habit streaks
                    HabitStreaksSection(rows: habitStreaks)
                        .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Statistics")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button(action: { exportStats() }) {
                            Label("Export Stats", systemImage: "square.and.arrow.up")
                        }

                        // Add quick link to settings
                        NavigationLink(destination: CategorySettingsView()) {
                            Label("Manage Targets", systemImage: "target")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .accessibilityIdentifier("stats-menu")
                            .accessibilityLabel("More")
                    }
                }
            }
            .sheet(isPresented: $isPresentingShareSheet) {
                if let items = shareItems {
                    ActivityViewController(items: items, subject: shareSubject)
                }
            }
            .onAppear { recomputeSummary() }
            .onChange(of: allTasks) { recomputeSummary() }
            .onChange(of: selectedTimeframe) { recomputeSummary() }
            .onChange(of: selectedCategory) { recomputeSummary() }
        }
    }

    private func recomputeSummary() {
        let completedDTOs = allTasks.filter(\.completed).map(ToDoTaskDTO.init(from:))
        let categoryDTOs = allCategories.map(CategoryDTO.init(from:))
        summary = StatisticsCalculator.summary(
            from: completedDTOs,
            timeframe: selectedTimeframe,
            categoryFilter: selectedCategory?.name,
            categories: categoryDTOs
        )
        loadHabitStreaks()
        checkCompanionTriggers(completedDTOs: completedDTOs)
    }

    private func loadHabitStreaks() {
        let calendar = HabitStreakCalculator.streakCalendar()
        let now = Date()
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        var rows: [HabitStreakRow] = []
        for habit in allHabits.filter({ !$0.isArchived }) {
            
            let allOccurrences = (habit.occurrences ?? []).compactMap(
                HabitOccurrenceDTO.init(from:))
            
            let streak = HabitStreakCalculator.streak(
                occurrences: allOccurrences,
                frequency: habit.weeklyFrequency,
                freezes: habit.streakFreezes)
            
            let weeklyOccurrences = allOccurrences.filter
            
            let weekOccurrences = allOccurrences.filter {
                   $0.periodStart >= startOfWeek && $0.periodStart <= now
               }
           let completedThisWeek = weekOccurrences.filter { $0.completed || $0.freezeUsed }.count
           
           rows.append(HabitStreakRow(
               uuid: habit.uuid,
               name: habit.name,
               currentStreak: streak.current,
               longestStreak: streak.longest,
               freezes: habit.streakFreezes,
               completedThisWeek: completedThisWeek,
               weeklyFrequency: habit.weeklyFrequency
           ))
       }
       habitStreaks = rows
    }

    private func checkCompanionTriggers(completedDTOs: [ToDoTaskDTO]) {
        let streak = summary.streak.current

        // Fire for notable streak milestones (3, 7, 14, 30, ...)
        let milestones = [3, 7, 14, 21, 30, 60, 90, 180, 365]
        if milestones.contains(streak), streak != lastReportedStreak {
            lastReportedStreak = streak
            companion.trigger(.streakMilestone(days: streak))
            return
        }

        // Detect low average mood from recent completions
        let recentMoods = completedDTOs
            .compactMap { $0.completionMoodValence }
            .suffix(10)
        if recentMoods.count >= 3 {
            let avg = recentMoods.reduce(0, +) / Double(recentMoods.count)
            if avg < -0.3 {
                companion.trigger(.lowMoodDetected(averageValence: avg))
                return
            }
        }

        // Habit nudge when there's enough data but no streak trigger
        if streak == 0, !completedDTOs.isEmpty {
            let categoryNames = Array(Set(completedDTOs.flatMap { $0.categories.map(\.name) })).sorted()
            if !categoryNames.isEmpty {
                companion.trigger(.habitSuggestion(
                    categories: categoryNames,
                    completedCount: completedDTOs.count
                ))
            }
        }
    }

    private func exportStats() {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short

        var csv = "Task Name,Completed Date,Categories,Task Time (min)\n"

        let sorted = summary.allCompletedTasks.sorted { ($0.completedAt ?? Date()) > ($1.completedAt ?? Date()) }
        for dto in sorted {
            let cats = dto.categories.map(\.name)
            let categoriesStr = cats.isEmpty ? "Uncategorised" : cats.joined(separator: "; ")
            let pomodoroMinutes = Int(dto.pomodoroTime / 60)
            let completedDate = dto.completedAt.map { formatter.string(from: $0) } ?? "N/A"
            csv += "\"\(dto.name)\",\"\(completedDate)\",\"\(categoriesStr)\",\(pomodoroMinutes),\n"
        }

        LogManager.shared.log.debug("CSV \(csv)")

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let todayString = dateFormatter.string(from: Date())
        let fileName = "ToDoStats_\(todayString).csv"

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        do {
            try csv.write(to: tempURL, atomically: true, encoding: .utf8)
        } catch {
            LogManager.shared.log.error("Failed to write CSV to temp file: \(error.localizedDescription)")
        }
        shareItems = [tempURL]
        shareSubject = "To-Do Statistics — \(selectedTimeframe.rawValue)"
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            isPresentingShareSheet = true
        }
    }
}

// MARK: - Overview Cards

struct OverviewCardsView: View {
    let metrics: OverviewMetrics

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                MetricCard(
                    title: "Completed",
                    value: "\(metrics.totalCompleted)",
                    subtitle: "tasks",
                    icon: "checkmark.circle.fill",
                    color: .green
                )

                MetricCard(
                    title: "Focus Time",
                    value: formatTime(metrics.totalFocusTime),
                    subtitle: "total",
                    icon: "timer",
                    color: .blue
                )

                MetricCard(
                    title: "Daily Average",
                    value: String(format: "%.1f", metrics.averagePerDay),
                    subtitle: "tasks/day",
                    icon: "chart.line.uptrend.xyaxis",
                    color: .purple
                )
            }
        }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let hours = Int(time) / 3600
        let minutes = (Int(time) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title2)
                Spacer()
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.title.bold())
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
                .textCase(.uppercase)
        }
        .padding()
        .frame(width: 140)
        .background(color.opacity(0.1))
        .cornerRadius(16)
    }
}

// MARK: - Category Completion Chart

struct CategoryCompletionChart: View {
    let data: [CategoryCompletionData]
    let timeframe: StatsTimeframe
    @State private var selectedBar: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Completed Tasks by Category")
                .font(.headline)

            if data.isEmpty {
                ContentUnavailableView(
                    "No completed tasks",
                    systemImage: "chart.bar.xaxis",
                    description: Text("Complete some tasks to see your statistics")
                )
                .frame(height: 200)
            } else {
                Chart(data, id: \.categoryName) { item in
                    let color: Color = item.categoryName == "Uncategorized"
                        ? .gray
                        : item.color.SwiftUIColor
                    BarMark(
                        x: .value("Category", item.categoryName),
                        y: .value("Count", item.completionCount)
                    )
                    .foregroundStyle(color.gradient)
                    .cornerRadius(8)
                    .opacity(selectedBar == nil || selectedBar == item.categoryName ? 1.0 : 0.3)
                    .annotation(position: .top) {
                        if selectedBar == item.categoryName {
                            Text("\(item.completionCount)")
                                .font(.caption.bold())
                                .padding(4)
                                .background(Color.black.opacity(0.7))
                                .foregroundColor(.white)
                                .cornerRadius(4)
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks { _ in
                        AxisValueLabel()
                            .font(.caption)
                    }
                }
                .chartOverlay { proxy in
                    GeometryReader { geo in
                        Rectangle()
                            .fill(.clear)
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onEnded { value in
                                        let location = value.location
                                        let origin = geo[proxy.plotAreaFrame].origin
                                        let xInPlot = location.x - origin.x
                                        var nearest: (name: String, distance: CGFloat)? = nil
                                        for item in data {
                                            if let xPos = proxy.position(forX: item.categoryName) {
                                                let distance = abs(xPos - xInPlot)
                                                if nearest == nil || distance < nearest!.distance {
                                                    nearest = (item.categoryName, distance)
                                                }
                                            }
                                        }
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            if let found = nearest?.name {
                                                selectedBar = (selectedBar == found) ? nil : found
                                            } else {
                                                selectedBar = nil
                                            }
                                        }
                                    }
                            )
                    }
                }
            }
        }
    }
}

// MARK: - Productivity Heatmap

struct ProductivityHeatmap: View {
    let data: [HourlyCompletionData]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Productivity Heatmap")
                .font(.headline)

            Text("Most productive hours")
                .font(.caption)
                .foregroundColor(.secondary)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 6), spacing: 4) {
                ForEach(data, id: \.hour) { item in
                    VStack(spacing: 2) {
                        Text(formatHour(item.hour))
                            .font(.caption2)
                            .foregroundColor(.secondary)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.blue.opacity(max(0.1, item.intensity)))
                            .frame(height: 30)
                            .overlay(
                                Text(item.count > 0 ? "\(item.count)" : "")
                                    .font(.caption2)
                                    .foregroundColor(item.intensity > 0.5 ? .white : .primary)
                            )
                    }
                }
            }
        }
    }

    private func formatHour(_ hour: Int) -> String {
        if hour == 0 { return "12AM" }
        if hour < 12 { return "\(hour)AM" }
        if hour == 12 { return "12PM" }
        return "\(hour - 12)PM"
    }
}

// MARK: - Weekly Breakdown

struct WeeklyBreakdownView: View {
    let data: [DailyCompletionData]
    let timeframe: StatsTimeframe

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Daily Breakdown")
                .font(.headline)

            if data.isEmpty {
                Text("No data available")
                    .foregroundColor(.secondary)
            } else {
                ForEach(data, id: \.date) { dayData in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(dayData.dateString)
                                .font(.subheadline)
                                .fontWeight(.medium)

                            Spacer()

                            Text("\(dayData.totalCount) completed")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(Array(dayData.categoryCompletions.keys).sorted(), id: \.self) { category in
                                    CategoryBadge(
                                        name: category,
                                        count: dayData.categoryCompletions[category] ?? 0
                                    )
                                }
                            }
                        }
                    }
                    .padding(.vertical, 8)

                    Divider()
                }
            }
        }
    }
}

// MARK: - Streak View

struct StreakView: View {
    let streak: StreakResult

    var body: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Label("Current Streak", systemImage: "flame.fill")
                    .font(.caption)
                    .foregroundColor(.orange)

                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text("\(streak.current)")
                        .font(.title2.bold())
                    Text(streak.current == 1 ? "day" : "days")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Divider()
                .frame(height: 40)

            VStack(alignment: .leading, spacing: 4) {
                Label("Longest Streak", systemImage: "trophy.fill")
                    .font(.caption)
                    .foregroundColor(.yellow)

                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text("\(streak.longest)")
                        .font(.title2.bold())
                    Text(streak.longest == 1 ? "day" : "days")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Habit Streaks Section

struct HabitStreaksSection: View {
    let rows: [HabitStreakRow]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Habits")
                .font(.headline)
                .padding(.horizontal)

            if rows.isEmpty {
                Text("No active habits yet.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
            } else {
                ForEach(rows) { row in
                    HabitStreakCard(row: row)
                }
                .padding(.horizontal)
            }
        }
    }
}

struct HabitStreakCard: View {
    let row: HabitStreakRow

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(row.name)
                .font(.subheadline.weight(.semibold))

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Label("Current", systemImage: "flame.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                    Text("\(row.currentStreak) \(row.currentStreak == 1 ? "day" : "days")")
                        .font(.title3.bold())
                }

                VStack(alignment: .leading, spacing: 2) {
                    Label("Longest", systemImage: "trophy.fill")
                        .font(.caption)
                        .foregroundColor(.yellow)
                    Text("\(row.longestStreak) \(row.currentStreak == 1 ? "day" : "days")")
                        .font(.title3.bold())
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Label("Freezes", systemImage: "snowflake")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(row.freezes)")
                        .font(.title3.bold())
                }
            }

            Text("\(row.completedThisWeek) / \(row.weeklyFrequency) days this week")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Category Badge

struct CategoryBadge: View {
    let name: String
    let count: Int
    @Query private var allCategories: [Category]

    private var categoryColor: Color {
        allCategories.first { $0.name == name }?.color?.SwiftUIColor ?? .gray
    }

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(categoryColor)
                .frame(width: 8, height: 8)
            Text("\(name): \(count)")
                .font(.caption)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(categoryColor.opacity(0.15))
        .cornerRadius(12)
    }
}

// MARK: - Activity View Controller

struct ActivityViewController: UIViewControllerRepresentable {
    let items: [Any]
    let subject: String?

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        if let subject {
            controller.setValue(subject, forKey: "subject")
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}


#if DEBUG
#Preview {
    StatsView()
    .modelContainer(PreviewData.shared.previewContainer)
    .environment(CompanionService.shared)
}
#endif

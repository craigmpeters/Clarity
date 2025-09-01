import SwiftUI
import SwiftData
import Charts

// Timeframe selection pill component
struct TimeframePill: View {
    let timeframe: StatsView.StatsTimeframe
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
    @State private var selectedTimeframe: StatsTimeframe = .last7Days
    @State private var selectedCategory: Category? = nil
    @Environment(\.modelContext) private var modelContext
    
    enum StatsTimeframe: String, CaseIterable {
        case today = "Today"
        case last7Days = "7 Days"
        case last30Days = "30 Days"
        case last90Days = "90 Days"
        case thisYear = "This Year"
        case allTime = "All Time"
        
        var dateRange: String {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            let now = Date()
            
            switch self {
            case .today:
                return "Today only"
            case .last7Days:
                let start = Calendar.current.date(byAdding: .day, value: -7, to: now) ?? now
                return "\(formatter.string(from: start)) - Today"
            case .last30Days:
                let start = Calendar.current.date(byAdding: .day, value: -30, to: now) ?? now
                return "\(formatter.string(from: start)) - Today"
            case .last90Days:
                let start = Calendar.current.date(byAdding: .day, value: -90, to: now) ?? now
                return "\(formatter.string(from: start)) - Today"
            case .thisYear:
                let start = Calendar.current.dateInterval(of: .year, for: now)?.start ?? now
                return "Since \(formatter.string(from: start))"
            case .allTime:
                return "All completed tasks"
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Overview Cards
                    OverviewCardsView(tasks: filteredTasks)
                        .padding(.horizontal)
                    
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
                    
                    // Weekly Targets Progress - NEW SECTION
                    // This replaces the old CategorySummaryView
                    WeeklyTargetsProgressView(tasks: completedTasks)
                        .padding(.horizontal)
                    
                    Divider()
                        .padding(.horizontal)
                    
                    // Category completion chart
                    CategoryCompletionChart(
                        tasks: filteredTasks,
                        timeframe: selectedTimeframe
                    )
                    .frame(height: 300)
                    .padding(.horizontal)
                    
                    // Productivity Heatmap
                    ProductivityHeatmap(tasks: filteredTasks)
                        .padding()
                    
                    // Weekly breakdown
                    WeeklyBreakdownView(
                        tasks: filteredTasks,
                        timeframe: selectedTimeframe
                    )
                    .padding(.horizontal)
                    
                    // Streak tracking
                    StreakView(tasks: allTasks)
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
                    }
                }
            }
        }
    }
    
    private var completedTasks: [ToDoTask] {
        allTasks.filter { $0.completed }
    }
    
    private var filteredTasks: [ToDoTask] {
        let calendar = Calendar.current
        let now = Date()
        
        let dateFilteredTasks: [ToDoTask]
        
        switch selectedTimeframe {
        case .today:
            dateFilteredTasks = completedTasks.filter { task in
                guard let completedAt = task.completedAt else { return false }
                return calendar.isDateInToday(completedAt)
            }
        case .last7Days:
            let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now
            dateFilteredTasks = completedTasks.filter { task in
                guard let completedAt = task.completedAt else { return false }
                return completedAt >= sevenDaysAgo
            }
        case .last30Days:
            let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: now) ?? now
            dateFilteredTasks = completedTasks.filter { task in
                guard let completedAt = task.completedAt else { return false }
                return completedAt >= thirtyDaysAgo
            }
        case .last90Days:
            let ninetyDaysAgo = calendar.date(byAdding: .day, value: -90, to: now) ?? now
            dateFilteredTasks = completedTasks.filter { task in
                guard let completedAt = task.completedAt else { return false }
                return completedAt >= ninetyDaysAgo
            }
        case .thisYear:
            let startOfYear = calendar.dateInterval(of: .year, for: now)?.start ?? now
            dateFilteredTasks = completedTasks.filter { task in
                guard let completedAt = task.completedAt else { return false }
                return completedAt >= startOfYear
            }
        case .allTime:
            dateFilteredTasks = completedTasks
        }
        
        // Apply category filter if selected
        if let selectedCategory = selectedCategory {
            return dateFilteredTasks.filter { task in
                task.categories.contains(selectedCategory)
            }
        }
        
        return dateFilteredTasks
    }
    
    private func exportStats() {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        
        var csv = "Task Name,Completed Date,Categories,Pomodoro Time (min),Was Pomodoro\n"
        
        for task in completedTasks.sorted(by: { ($0.completedAt ?? Date()) > ($1.completedAt ?? Date()) }) {
            let categories = task.categories.map { $0.name }.joined(separator: "; ")
            let pomodoroMinutes = Int(task.pomodoroTime / 60)
            let completedDate = task.completedAt.map { formatter.string(from: $0) } ?? "N/A"
            
            csv += "\"\(task.name)\",\"\(completedDate)\",\"\(categories)\",\(pomodoroMinutes),\(task.pomodoro)\n"
        }
        
        // In a real app, you'd present a share sheet here
        // For now, just print or save to documents
        print("CSV Export:\n\(csv)")
    }
}

// Overview cards showing key metrics
struct OverviewCardsView: View {
    let tasks: [ToDoTask]
    
    private var totalCompleted: Int {
        tasks.count
    }
    
    private var totalFocusTime: TimeInterval {
        tasks.reduce(0) { $0 + ($1.pomodoro ? $1.pomodoroTime : 0) }
    }
    
    private var averagePerDay: Double {
        guard !tasks.isEmpty else { return 0 }
        let calendar = Calendar.current
        let dates = tasks.compactMap { $0.completedAt }.sorted()
        guard let firstDate = dates.first,
              let lastDate = dates.last else { return 0 }
        
        let days = calendar.dateComponents([.day], from: firstDate, to: lastDate).day ?? 1
        return Double(tasks.count) / Double(max(days, 1))
    }
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                MetricCard(
                    title: "Completed",
                    value: "\(totalCompleted)",
                    subtitle: "tasks",
                    icon: "checkmark.circle.fill",
                    color: .green
                )
                
                MetricCard(
                    title: "Focus Time",
                    value: formatTime(totalFocusTime),
                    subtitle: "total",
                    icon: "timer",
                    color: .blue
                )
                
                MetricCard(
                    title: "Daily Average",
                    value: String(format: "%.1f", averagePerDay),
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

struct CategoryCompletionChart: View {
    let tasks: [ToDoTask]
    let timeframe: StatsView.StatsTimeframe
    @Query private var allCategories: [Category]
    @State private var selectedBar: String? = nil
    
    private var chartData: [CategoryCompletionData] {
        var categoryCount: [String: Int] = [:]
        
        // Count completions per category
        for task in tasks {
            for category in task.categories {
                categoryCount[category.name, default: 0] += 1
            }
        }
        
        // Add "Uncategorized" if there are tasks without categories
        let uncategorizedCount = tasks.filter { $0.categories.isEmpty }.count
        if uncategorizedCount > 0 {
            categoryCount["Uncategorized"] = uncategorizedCount
        }
        
        // Convert to chart data with colors
        return categoryCount.map { (name, count) in
            let color = allCategories.first { $0.name == name }?.color.SwiftUIColor ?? .gray
            return CategoryCompletionData(
                categoryName: name,
                completionCount: count,
                color: color
            )
        }.sorted { $0.completionCount > $1.completionCount }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Completed Tasks by Category")
                .font(.headline)
            
            if chartData.isEmpty {
                ContentUnavailableView(
                    "No completed tasks",
                    systemImage: "chart.bar.xaxis",
                    description: Text("Complete some tasks to see your statistics")
                )
                .frame(height: 200)
            } else {
                Chart(chartData, id: \.categoryName) { data in
                    BarMark(
                        x: .value("Category", data.categoryName),
                        y: .value("Count", data.completionCount)
                    )
                    .foregroundStyle(data.color.gradient)
                    .cornerRadius(8)
                    .opacity(selectedBar == nil || selectedBar == data.categoryName ? 1.0 : 0.3)
                    .annotation(position: .top) {
                        if selectedBar == data.categoryName {
                            Text("\(data.completionCount)")
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
                .onTapGesture { location in
                    // Simple tap detection - in production you'd calculate which bar was tapped
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedBar = selectedBar == nil ? chartData.first?.categoryName : nil
                    }
                }
            }
        }
    }
}

struct ProductivityHeatmap: View {
    let tasks: [ToDoTask]
    
    private var hourlyData: [(hour: Int, count: Int, intensity: Double)] {
        let calendar = Calendar.current
        var hourCounts: [Int: Int] = [:]
        
        for task in tasks {
            if let completedAt = task.completedAt {
                let hour = calendar.component(.hour, from: completedAt)
                hourCounts[hour, default: 0] += 1
            }
        }
        
        let maxCount = hourCounts.values.max() ?? 1
        
        return (0..<24).map { hour in
            let count = hourCounts[hour] ?? 0
            let intensity = Double(count) / Double(maxCount)
            return (hour, count, intensity)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Productivity Heatmap")
                .font(.headline)
            
            Text("Most productive hours")
                .font(.caption)
                .foregroundColor(.secondary)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 6), spacing: 4) {
                ForEach(hourlyData, id: \.hour) { data in
                    VStack(spacing: 2) {
                        Text(formatHour(data.hour))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.blue.opacity(max(0.1, data.intensity)))
                            .frame(height: 30)
                            .overlay(
                                Text(data.count > 0 ? "\(data.count)" : "")
                                    .font(.caption2)
                                    .foregroundColor(data.intensity > 0.5 ? .white : .primary)
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

struct WeeklyBreakdownView: View {
    let tasks: [ToDoTask]
    let timeframe: StatsView.StatsTimeframe
    
    private var dailyData: [DailyCompletionData] {
        let calendar = Calendar.current
        var dailyCount: [Date: [Category]] = [:]
        
        for task in tasks {
            guard let completedAt = task.completedAt else { continue }
            let startOfDay = calendar.startOfDay(for: completedAt)
            
            if dailyCount[startOfDay] == nil {
                dailyCount[startOfDay] = []
            }
            dailyCount[startOfDay]?.append(contentsOf: task.categories)
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        
        return dailyCount.map { (date, categories) in
            var categoryCount: [String: Int] = [:]
            for category in categories {
                categoryCount[category.name, default: 0] += 1
            }
            
            return DailyCompletionData(
                date: date,
                dateString: formatter.string(from: date),
                categoryCompletions: categoryCount,
                totalCount: categories.count
            )
        }.sorted { $0.date > $1.date }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Daily Breakdown")
                .font(.headline)
            
            if dailyData.isEmpty {
                Text("No data available")
                    .foregroundColor(.secondary)
            } else {
                ForEach(dailyData, id: \.date) { dayData in
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

struct CategorySummaryView: View {
    let tasks: [ToDoTask]
    let filteredTasks: [ToDoTask]
    @Query private var allCategories: [Category]
    
    private var categoryStats: [(category: Category, completed: Int, total: Int, rate: Double)] {
        allCategories.map { category in
            let totalInCategory = tasks.filter { task in
                task.categories.contains(category)
            }.count
            
            let completedInCategory = filteredTasks.filter { task in
                task.categories.contains(category)
            }.count
            
            let rate = totalInCategory > 0 ? Double(completedInCategory) / Double(totalInCategory) : 0
            
            return (category, completedInCategory, totalInCategory, rate)
        }.sorted { $0.completed > $1.completed }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Category Performance")
                .font(.headline)
            
            if categoryStats.isEmpty {
                Text("No categories created yet")
                    .foregroundColor(.secondary)
            } else {
                ForEach(categoryStats, id: \.category.id) { stat in
                    HStack {
                        Circle()
                            .fill(stat.category.color.SwiftUIColor)
                            .frame(width: 12, height: 12)
                        
                        Text(stat.category.name)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(stat.completed) tasks")
                                .font(.caption)
                            
                            if stat.total > 0 {
                                Text("\(Int(stat.rate * 100))% completion")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
}

struct StreakView: View {
    let tasks: [ToDoTask]
    
    private var currentStreak: Int {
        calculateStreak(lookingBack: true)
    }
    
    private var longestStreak: Int {
        calculateLongestStreak()
    }
    
    var body: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Label("Current Streak", systemImage: "flame.fill")
                    .font(.caption)
                    .foregroundColor(.orange)
                
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text("\(currentStreak)")
                        .font(.title2.bold())
                    Text(currentStreak == 1 ? "day" : "days")
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
                    Text("\(longestStreak)")
                        .font(.title2.bold())
                    Text(longestStreak == 1 ? "day" : "days")
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
    
    private func calculateStreak(lookingBack: Bool) -> Int {
        let calendar = Calendar.current
        let completedDates = Set(tasks.compactMap { task -> Date? in
            guard let completedAt = task.completedAt else { return nil }
            return calendar.startOfDay(for: completedAt)
        })
        
        guard !completedDates.isEmpty else { return 0 }
        
        var streak = 0
        var currentDate = calendar.startOfDay(for: Date())
        
        // Check if we have tasks completed today
        if !completedDates.contains(currentDate) && lookingBack {
            // If no tasks today, check yesterday
            currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate
        }
        
        // Count consecutive days going backwards
        while completedDates.contains(currentDate) {
            streak += 1
            currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate
        }
        
        return streak
    }
    
    private func calculateLongestStreak() -> Int {
        let calendar = Calendar.current
        let sortedDates = tasks.compactMap { task -> Date? in
            guard let completedAt = task.completedAt else { return nil }
            return calendar.startOfDay(for: completedAt)
        }.sorted()
        
        guard !sortedDates.isEmpty else { return 0 }
        
        var longestStreak = 1
        var currentStreak = 1
        
        for i in 1..<sortedDates.count {
            let daysDifference = calendar.dateComponents([.day], from: sortedDates[i-1], to: sortedDates[i]).day ?? 0
            
            if daysDifference == 1 {
                currentStreak += 1
                longestStreak = max(longestStreak, currentStreak)
            } else if daysDifference > 1 {
                currentStreak = 1
            }
            // If daysDifference == 0, same day, don't reset streak
        }
        
        return longestStreak
    }
}

struct CategoryBadge: View {
    let name: String
    let count: Int
    @Query private var allCategories: [Category]
    
    private var categoryColor: Color {
        allCategories.first { $0.name == name }?.color.SwiftUIColor ?? .gray
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

// Data structures
struct CategoryCompletionData {
    let categoryName: String
    let completionCount: Int
    let color: Color
}

struct DailyCompletionData {
    let date: Date
    let dateString: String
    let categoryCompletions: [String: Int]
    let totalCount: Int
}

// Add to StatsTimeframe enum
extension StatsView.StatsTimeframe {
    var shortDescription: String {
        switch self {
        case .today:
            return "24 hrs"
        case .last7Days:
            return "1 week"
        case .last30Days:
            return "1 month"
        case .last90Days:
            return "3 months"
        case .thisYear:
            return Calendar.current.component(.year, from: Date()).description
        case .allTime:
            return "Everything"
        }
    }
}

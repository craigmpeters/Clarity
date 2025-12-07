//
//  DevelopmentTools.swift
//  Clarity
//
//  Created by Development Team
//

import SwiftUI
import SwiftData
import Foundation

#if DEBUG

// MARK: - Development Menu View
struct DevelopmentMenuView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            List {
                Section("File Data"){
                    Text("Total Tasks in File Database:  \(getTotalTasksinFileDB())")
                }
                Section("Test Data") {
                    Button("Populate Sample Tasks") {
                        populateSampleTasks()
                    }
                    
                    Button("Populate Specific Day Tasks") {
                        populateEverySpecificDayTasks()
                    }
                    
                    Button("Add Sample Categories") {
                        populateSampleCategories()
                    }
                    
                    Button("Generate Weekly Progress Data") {
                        generateWeeklyProgressData()
                    }
                    
                    Button("Create Test Recurring Tasks") {
                        createRecurringTasks()
                    }
                }
                
                Section("Completed Tasks") {
                    Button("Add This Week's Completed Tasks") {
                        addCompletedTasksThisWeek()
                    }
                    
                    Button("Add Historical Data (30 days)") {
                        addHistoricalData()
                    }
                    
                    Button("Simulate Productivity Streaks") {
                        simulateProductivityStreaks()
                    }
                }
                
                Section("Edge Cases") {
                    Button("Create Overdue Tasks") {
                        createOverdueTasks()
                    }
                    
                    Button("Tasks with Long Names") {
                        createLongNameTasks()
                    }
                    
                    Button("Tasks Without Categories") {
                        createUncategorizedTasks()
                    }
                }
                
                Section("Data Management") {
                    Button("Clear All Tasks", role: .destructive) {
                        clearAllTasks()
                    }
                    
                    Button("Clear All Categories", role: .destructive) {
                        clearAllCategories()
                    }
                    
                    Button("Reset Everything", role: .destructive) {
                        resetEverything()
                    }
                }
            }
            .navigationTitle("Development Tools")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .alert("Development Tools", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    // MARK: - File Debug Section Functions
    
    private func getTotalTasksinFileDB() -> Int {
        do {
            let tasks = try WidgetFileCoordinator.shared.readTasks()
            return tasks.count
        } catch {
            print("Failed to read tasks from file DB: \(error)")
            return 0
        }
    }
    
    // MARK: - Test Data Population Methods
    
    private func populateSampleCategories() {
        let categories = [
            Category(name: "Work", color: .Blue, weeklyTarget: 8),
            Category(name: "Personal", color: .Green, weeklyTarget: 5),
            Category(name: "Learning", color: .Purple, weeklyTarget: 3),
            Category(name: "Health", color: .Red, weeklyTarget: 7),
            Category(name: "Creative", color: .Orange, weeklyTarget: 2),
            Category(name: "Urgent", color: .Yellow, weeklyTarget: 0),
            Category(name: "Planning", color: .Cyan, weeklyTarget: 2)
        ]
        
        for category in categories {
            modelContext.insert(category)
        }
        
        saveContext()
        showAlert("Added \(categories.count) sample categories")
    }
    
    private func populateEverySpecificDayTasks() {
        // Get existing categories or create basic ones
        let allCategories = getAllCategories()
        if allCategories.isEmpty {
            populateSampleCategories()
        }
        
        let categories = getAllCategories()
        let workCategory = categories.first { $0.name == "Work" }
        
        let sampleTasks = [
            ("Monday Overdue Task", 1, Date().addingTimeInterval(-86400 * 7), [workCategory].compactMap { $0 }),
            ("Tuesday Overdue Task", 2, Date().addingTimeInterval(-864200 * 7), [workCategory].compactMap { $0 }),
            ("Wednesday Overdue Task", 3, Date().addingTimeInterval(-864200 * 7), [workCategory].compactMap { $0 }),
            ("Thursday Overdue Task", 4, Date().addingTimeInterval(-864200 * 7), [workCategory].compactMap { $0 }),
            ("Friday Overdue Task", 5, Date().addingTimeInterval(-864200 * 7), [workCategory].compactMap { $0 }),
            ("Saturday Overdue Task", 6, Date().addingTimeInterval(-864200 * 7), [workCategory].compactMap { $0 }),
            ("Sunday Overdue Task", 0, Date().addingTimeInterval(-864200 * 7), [workCategory].compactMap { $0 }),
        ]
        
        for (name, day, dueDate, taskCategories) in sampleTasks {
            let task = ToDoTask(
                name: name,
                pomodoroTime: TimeInterval(5 * 60),
                repeating: true,
                recurrenceInterval: .specific,
                due: dueDate,
                everySpecificDayDay: day,
                categories: taskCategories,
                uuid: UUID()
            )
            modelContext.insert(task)
        }
        
        saveContext()
        showAlert("Added \(sampleTasks.count) sample tasks")
        
    }
    
    private func populateSampleTasks() {
        // Get existing categories or create basic ones
        let allCategories = getAllCategories()
        if allCategories.isEmpty {
            populateSampleCategories()
        }
        
        let categories = getAllCategories()
        let workCategory = categories.first { $0.name == "Work" }
        let personalCategory = categories.first { $0.name == "Personal" }
        let learningCategory = categories.first { $0.name == "Learning" }
        
        let sampleTasks = [
            // Overdue taks
            ("Review quarterly reports", 25, Date().addingTimeInterval(-86400), [workCategory].compactMap { $0 }),
            
            // Today's tasks
            ("Team standup meeting prep", 15, Date(), [workCategory].compactMap { $0 }),
            ("Grocery shopping", 5, Date(), [personalCategory].compactMap { $0 }),
            ("SwiftUI documentation reading", 25, Date(), [learningCategory].compactMap { $0 }),
            
            // Tomorrow's tasks
            ("Client presentation slides", 10, Date().addingTimeInterval(86400), [workCategory].compactMap { $0 }),
            ("Doctor appointment", 5, Date().addingTimeInterval(86400), [personalCategory].compactMap { $0 }),
            
            // This week
            ("Code review session", 25, Date().addingTimeInterval(86400 * 2), [workCategory].compactMap { $0 }),
            ("Weekend hiking preparation", 20, Date().addingTimeInterval(86400 * 3), [personalCategory].compactMap { $0 }),
            ("iOS 18 features research", 25, Date().addingTimeInterval(86400 * 4), [learningCategory].compactMap { $0 }),
        ]
        
        for (name, minutes, dueDate, taskCategories) in sampleTasks {
            let task = ToDoTask(
                name: name,
                pomodoroTime: TimeInterval(minutes * 60),
                due: dueDate,
                categories: taskCategories
            )
            modelContext.insert(task)
        }
        
        saveContext()
        showAlert("Added \(sampleTasks.count) sample tasks")
    }
    
    private func generateWeeklyProgressData() {
        // Set global weekly target
        let globalSettings = GlobalTargetSettings(weeklyGlobalTarget: 15)
        modelContext.insert(globalSettings)
        
        // Update existing categories with targets
        let categories = getAllCategories()
        for category in categories {
            switch category.name {
            case "Work":
                category.weeklyTarget = 8
            case "Personal":
                category.weeklyTarget = 5
            case "Learning":
                category.weeklyTarget = 3
            case "Health":
                category.weeklyTarget = 7
            default:
                category.weeklyTarget = 2
            }
        }
        
        saveContext()
        showAlert("Set up weekly targets for progress tracking")
    }
    
    private func createRecurringTasks() {
        let categories = getAllCategories()
        let healthCategory = categories.first { $0.name == "Health" }
        let workCategory = categories.first { $0.name == "Work" }
        
        let recurringTasks = [
            ("Daily standup", ToDoTask.RecurrenceInterval.daily, 15, [workCategory].compactMap { $0 }),
            ("Weekly planning session", ToDoTask.RecurrenceInterval.weekly, 30, [workCategory].compactMap { $0 }),
            ("Morning workout", ToDoTask.RecurrenceInterval.daily, 25, [healthCategory].compactMap { $0 }),
            ("Bi-weekly team retrospective", ToDoTask.RecurrenceInterval.biweekly, 45, [workCategory].compactMap { $0 }),
        ]
        
        for (name, interval, minutes, taskCategories) in recurringTasks {
            let task = ToDoTask(
                name: name,
                pomodoroTime: TimeInterval(minutes * 60),
                repeating: true,
                recurrenceInterval: interval,
                due: Date(),
                categories: taskCategories
            )
            modelContext.insert(task)
        }
        
        saveContext()
        showAlert("Created \(recurringTasks.count) recurring tasks")
    }
    
    private func addCompletedTasksThisWeek() {
        let categories = getAllCategories()
        let calendar = Calendar.current
        let now = Date()
        
        // Get start of current week (Monday)
        var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
        components.weekday = 2 // Monday
        let weekStart = calendar.date(from: components) ?? now
        
        let completedTasks = [
            ("Updated project documentation", 20, weekStart, categories.randomElement()),
            ("Code review for feature branch", 25, calendar.date(byAdding: .day, value: 1, to: weekStart)!, categories.randomElement()),
            ("Team planning meeting", 30, calendar.date(byAdding: .day, value: 1, to: weekStart)!, categories.randomElement()),
            ("Bug fix deployment", 15, calendar.date(byAdding: .day, value: 2, to: weekStart)!, categories.randomElement()),
            ("Client feedback review", 20, calendar.date(byAdding: .day, value: 2, to: weekStart)!, categories.randomElement()),
            ("Weekly report writing", 20, calendar.date(byAdding: .day, value: 3, to: weekStart)!, categories.randomElement()),
            ("Database optimization", 25, calendar.date(byAdding: .day, value: 3, to: weekStart)!, categories.randomElement()),
        ]
        
        for (name, minutes, completedDate, category) in completedTasks {
            let task = ToDoTask(
                name: name,
                pomodoroTime: TimeInterval(minutes * 60),
                due: completedDate,
                categories: category != nil ? [category!] : []
            )
            task.completed = true
            task.completedAt = completedDate.addingTimeInterval(Double.random(in: 0...3600)) // Random time within hour
            modelContext.insert(task)
        }
        
        saveContext()
        showAlert("Added \(completedTasks.count) completed tasks this week")
    }
    
    private func addHistoricalData() {
        let categories = getAllCategories()
        let calendar = Calendar.current
        let now = Date()
        
        // Generate completed tasks for the past 30 days
        for dayOffset in 1...30 {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: now) else { continue }
            
            // Random number of completed tasks per day (0-5)
            let taskCount = Int.random(in: 0...5)
            
            for taskIndex in 0..<taskCount {
                let taskNames = [
                    "Sprint planning", "Code review", "Bug fixes", "Feature development",
                    "Client meeting", "Documentation update", "Testing", "Deployment",
                    "Research", "Learning session", "Team sync", "Performance optimization"
                ]
                
                let name = taskNames.randomElement() ?? "Task \(taskIndex + 1)"
                let minutes = [15, 20, 25, 30, 35, 45].randomElement() ?? 25
                let category = categories.randomElement()
                
                let task = ToDoTask(
                    name: "\(name) - Day \(dayOffset)",
                    pomodoroTime: TimeInterval(minutes * 60),
                    due: date,
                    categories: category != nil ? [category!] : []
                )
                task.completed = true
                task.completedAt = date.addingTimeInterval(Double.random(in: 0...86400)) // Random time during day
                modelContext.insert(task)
            }
        }
        
        saveContext()
        showAlert("Added historical data for the past 30 days")
    }
    
    private func simulateProductivityStreaks() {
        let categories = getAllCategories()
        let calendar = Calendar.current
        let now = Date()
        
        // Create a 7-day streak ending today
        for dayOffset in 0...6 {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: now) else { continue }
            
            let taskCount = Int.random(in: 2...4)
            for taskIndex in 0..<taskCount {
                let task = ToDoTask(
                    name: "Streak task \(taskIndex + 1) - Day \(dayOffset)",
                    pomodoroTime: TimeInterval(25 * 60),
                    due: date,
                    categories: categories.randomElement().map { [$0] } ?? []
                )
                task.completed = true
                task.completedAt = date.addingTimeInterval(Double.random(in: 28800...64800)) // Between 8 AM and 6 PM
                modelContext.insert(task)
            }
        }
        
        saveContext()
        showAlert("Created a 7-day productivity streak")
    }
    
    private func createOverdueTasks() {
        let categories = getAllCategories()
        
        let overdueTasks = [
            ("Overdue project review", 30, Calendar.current.date(byAdding: .day, value: -3, to: Date())!),
            ("Late client response", 15, Calendar.current.date(byAdding: .day, value: -1, to: Date())!),
            ("Missed deadline task", 45, Calendar.current.date(byAdding: .day, value: -5, to: Date())!),
        ]
        
        for (name, minutes, dueDate) in overdueTasks {
            let task = ToDoTask(
                name: name,
                pomodoroTime: TimeInterval(minutes * 60),
                due: dueDate,
                categories: categories.randomElement().map { [$0] } ?? []
            )
            modelContext.insert(task)
        }
        
        saveContext()
        showAlert("Created \(overdueTasks.count) overdue tasks")
    }
    
    private func createLongNameTasks() {
        let categories = getAllCategories()
        
        let longNameTasks = [
            "This is a very long task name that should test the UI layout and text truncation behavior in various views",
            "Another extremely lengthy task description that might cause layout issues if not handled properly in the interface",
            "一个非常长的中文任务名称，用来测试国际化和文本处理的功能是否正常工作"
        ]
        
        for (index, name) in longNameTasks.enumerated() {
            let task = ToDoTask(
                name: name,
                pomodoroTime: TimeInterval(25 * 60),
                due: Date().addingTimeInterval(Double(index) * 86400),
                categories: categories.randomElement().map { [$0] } ?? []
            )
            modelContext.insert(task)
        }
        
        saveContext()
        showAlert("Created tasks with long names")
    }
    
    private func createUncategorizedTasks() {
        let uncategorizedTasks = [
            "Uncategorized task 1",
            "Task without category",
            "No category assigned"
        ]
        
        for (index, name) in uncategorizedTasks.enumerated() {
            let task = ToDoTask(
                name: name,
                pomodoroTime: TimeInterval(20 * 60),
                due: Date().addingTimeInterval(Double(index) * 86400),
                categories: []
            )
            modelContext.insert(task)
        }
        
        saveContext()
        showAlert("Created \(uncategorizedTasks.count) uncategorized tasks")
    }
    
    // MARK: - Data Management Methods
    
    private func clearAllTasks() {
        let tasks = getAllTasks()
        for task in tasks {
            modelContext.delete(task)
        }
        saveContext()
        showAlert("Cleared all tasks")
    }
    
    private func clearAllCategories() {
        let categories = getAllCategories()
        for category in categories {
            modelContext.delete(category)
        }
        saveContext()
        showAlert("Cleared all categories")
    }
    
    private func resetEverything() {
        // Clear all data
        let tasks = getAllTasks()
        let categories = getAllCategories()
        let settings = getAllGlobalSettings()
        
        for task in tasks {
            modelContext.delete(task)
        }
        for category in categories {
            modelContext.delete(category)
        }
        for setting in settings {
            modelContext.delete(setting)
        }
        
        saveContext()
        UserDefaults.resetOnboardingState()
        showAlert("Reset all data")
    }
    
    // MARK: - Helper Methods
    
    private func getAllTasks() -> [ToDoTask] {
        do {
            let descriptor = FetchDescriptor<ToDoTask>()
            return try modelContext.fetch(descriptor)
        } catch {
            print("Failed to fetch tasks: \(error)")
            return []
        }
    }
    
    private func getAllCategories() -> [Category] {
        do {
            let descriptor = FetchDescriptor<Category>()
            return try modelContext.fetch(descriptor)
        } catch {
            print("Failed to fetch categories: \(error)")
            return []
        }
    }
    
    private func getAllGlobalSettings() -> [GlobalTargetSettings] {
        do {
            let descriptor = FetchDescriptor<GlobalTargetSettings>()
            return try modelContext.fetch(descriptor)
        } catch {
            print("Failed to fetch global settings: \(error)")
            return []
        }
    }
    
    private func saveContext() {
        do {
            try modelContext.save()
        } catch {
            print("Failed to save context: \(error)")
        }
    }
    
    private func showAlert(_ message: String) {
        alertMessage = message
        showingAlert = true
    }
}

// MARK: - Development Menu Modifier
struct DevelopmentMenuModifier: ViewModifier {
    @State private var showingDevelopmentMenu = false
    @State private var tapCount = 0
    
    func body(content: Content) -> some View {
        content
            .onTapGesture(count: 3) {
                showingDevelopmentMenu = true
            }
            .sheet(isPresented: $showingDevelopmentMenu) {
                DevelopmentMenuView()
            }
    }
}

extension View {
    func developmentMenu() -> some View {
        #if DEBUG
        return self.modifier(DevelopmentMenuModifier())
        #else
        return self
        #endif
    }
}

// MARK: - Development Helper for Settings
struct DevelopmentSection: View {
    @State private var showingDevelopmentMenu = false
    
    var body: some View {
        #if DEBUG
        Section("Development") {
            Button("Open Development Tools") {
                showingDevelopmentMenu = true
            }
            .foregroundStyle(.orange)
        }
        .sheet(isPresented: $showingDevelopmentMenu) {
            DevelopmentMenuView()
        }
        #else
        EmptyView()
        #endif
    }
}

#endif


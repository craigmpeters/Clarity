// Updated Category.swift with weekly targets
import Foundation
import SwiftData
import SwiftUI

// MARK: - Category Settings View with Targets
struct CategorySettingsView: View {
    @Query private var categories: [Category]
    @Query private var globalSettings: [GlobalTargetSettings]
    @Environment(\.modelContext) private var modelContext
    @State private var globalTarget: Int = 0
    @State private var showingAddCategory = false
    @State private var editingCategory: Category?
    
    private var currentGlobalSettings: GlobalTargetSettings? {
        globalSettings.first
    }
    
    var body: some View {
        NavigationView {
            Form {
                // Global Weekly Target Section
                Section {
                    HStack {
                        Label("Global Weekly Target", systemImage: "target")
                            .foregroundStyle(.orange)
                        
                        Spacer()
                        
                        Stepper(value: $globalTarget, in: 0...100) {
                            HStack {
                                TextField("", value: $globalTarget, format: .number)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 50)
                                    .multilineTextAlignment(.center)
                                    .keyboardType(.numberPad)
                            }
                        }
                    }
                } header: {
                    Text("Overall Target")
                } footer: {
                    Text("Set a target for total tasks to complete each week across all categories")
                        .font(.caption)
                }
                
                // Individual Category Targets
                Section {
                    ForEach(categories) { category in
                        CategoryTargetRow(category: category)
                    }
                    .onDelete(perform: deleteCategories)
                    
                    Button(action: { showingAddCategory = true }) {
                        Label("Add Category", systemImage: "plus.circle.fill")
                            .foregroundStyle(.blue)
                    }
                } header: {
                    Text("Category Targets")
                } footer: {
                    Text("Set individual weekly targets for each category. Week resets on Monday.")
                        .font(.caption)
                }
                
                // Target Summary
                if !categories.isEmpty {
                    Section("Target Summary") {
                        HStack {
                            Text("Sum of Category Targets")
                            Spacer()
                            Text("\(categories.reduce(0) { $0 + $1.weeklyTarget })")
                                .foregroundStyle(.secondary)
                        }
                        
                        if globalTarget > 0 {
                            HStack {
                                Text("Global Target")
                                Spacer()
                                Text("\(globalTarget)")
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Categories & Targets")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    EditButton()
                }
            }
            .onAppear {
                loadGlobalSettings()
            }
            .onChange(of: globalTarget) { _, newValue in
                saveGlobalTarget(newValue)
            }
            .sheet(isPresented: $showingAddCategory) {
                AddCategoryView()
            }
            .sheet(item: $editingCategory) { category in
                EditCategoryView(category: category)
            }
        }
    }
    
    private func loadGlobalSettings() {
        if let settings = currentGlobalSettings {
            globalTarget = settings.weeklyGlobalTarget
        } else {
            // Create default settings if none exist
            let settings = GlobalTargetSettings()
            modelContext.insert(settings)
            try? modelContext.save()
        }
    }
    
    private func saveGlobalTarget(_ value: Int) {
        if let settings = currentGlobalSettings {
            settings.weeklyGlobalTarget = value
        } else {
            let settings = GlobalTargetSettings(weeklyGlobalTarget: value)
            modelContext.insert(settings)
        }
        try? modelContext.save()
    }
    
    private func deleteCategories(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(categories[index])
        }
        try? modelContext.save()
    }
}

// MARK: - Category Target Row
struct CategoryTargetRow: View {
    @Bindable var category: Category
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        HStack {
            HStack(spacing: 8) {
                Circle()
                    .fill(category.color.SwiftUIColor)
                    .frame(width: 16, height: 16)
                
                Text(category.name)
                    .fontWeight(.medium)
            }
            
            Spacer()
            
            HStack(spacing: 4) {
                Button(action: { decrementTarget() }) {
                    Image(systemName: "minus.circle")
                        .foregroundStyle(category.weeklyTarget > 0 ? .blue : .gray)
                }
                .buttonStyle(.plain)
                .disabled(category.weeklyTarget == 0)
                
                Text("\(category.weeklyTarget)")
                    .frame(minWidth: 30)
                    .font(.system(.body, design: .monospaced))
                
                Button(action: { incrementTarget() }) {
                    Image(systemName: "plus.circle")
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
                
                Text("/ week")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func incrementTarget() {
        category.weeklyTarget += 1
        try? modelContext.save()
    }
    
    private func decrementTarget() {
        if category.weeklyTarget > 0 {
            category.weeklyTarget -= 1
            try? modelContext.save()
        }
    }
}

// MARK: - Weekly Targets Progress View for Stats
struct WeeklyTargetsProgressView: View {
    let tasks: [ToDoTask] // Completed tasks for the current week
    @Query private var categories: [Category]
    @Query private var globalSettings: [GlobalTargetSettings]
    
    private var currentWeekStart: Date {
        let calendar = Calendar.current
        let now = Date()
        // Get start of week (Monday)
        var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
        components.weekday = 2 // Monday
        return calendar.date(from: components) ?? now
    }
    
    private var tasksThisWeek: [ToDoTask] {
        tasks.filter { task in
            guard let completedAt = task.completedAt else { return false }
            return completedAt >= currentWeekStart
        }
    }
    
    private var globalTarget: Int {
        globalSettings.first?.weeklyGlobalTarget ?? 0
    }
    
    private var totalCompletedThisWeek: Int {
        tasksThisWeek.count
    }
    
    private var categoryProgress: [(category: Category, completed: Int, target: Int, progress: Double)] {
        categories.compactMap { category in
            let completed = tasksThisWeek.filter { task in
                task.categories.contains(category)
            }.count
            
            let target = category.weeklyTarget
            let progress = target > 0 ? Double(completed) / Double(target) : 0
            
            // Only show categories with targets set
            if target > 0 {
                return (category, completed, target, min(progress, 1.0))
            }
            return nil
        }.sorted { $0.progress > $1.progress }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with week dates
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Weekly Targets")
                        .font(.headline)
                    Text(weekDateRange)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                
                // Days remaining in week
                Text("\(daysRemainingInWeek) days left")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(8)
            }
            
            // Global Progress (if set)
            if globalTarget > 0 {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label("Overall Progress", systemImage: "target")
                            .font(.subheadline)
                            .foregroundStyle(.orange)
                        
                        Spacer()
                        
                        Text("\(totalCompletedThisWeek) / \(globalTarget)")
                            .font(.system(.subheadline, design: .monospaced))
                            .fontWeight(.medium)
                    }
                    
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.secondary.opacity(0.2))
                                .frame(height: 24)
                            
                            RoundedRectangle(cornerRadius: 8)
                                .fill(progressColor(for: Double(totalCompletedThisWeek) / Double(globalTarget)))
                                .frame(
                                    width: geometry.size.width * min(Double(totalCompletedThisWeek) / Double(globalTarget), 1.0),
                                    height: 24
                                )
                            
                            Text("\(Int(min(Double(totalCompletedThisWeek) / Double(globalTarget), 1.0) * 100))%")
                                .font(.caption.bold())
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                        }
                    }
                    .frame(height: 24)
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(12)
            }
            
            // Category Progress
            if !categoryProgress.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(categoryProgress, id: \.category.id) { item in
                        CategoryProgressRow(
                            category: item.category,
                            completed: item.completed,
                            target: item.target,
                            progress: item.progress
                        )
                    }
                }
            } else if globalTarget == 0 {
                // No targets set
                VStack(spacing: 12) {
                    Image(systemName: "target")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    
                    Text("No weekly targets set")
                        .font(.headline)
                    
                    Text("Set targets in Category Settings")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(12)
            }
        }
    }
    
    private var weekDateRange: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        let endOfWeek = Calendar.current.date(byAdding: .day, value: 6, to: currentWeekStart) ?? Date()
        return "\(formatter.string(from: currentWeekStart)) - \(formatter.string(from: endOfWeek))"
    }
    
    private var daysRemainingInWeek: Int {
        let calendar = Calendar.current
        let now = Date()
        let endOfWeek = calendar.date(byAdding: .day, value: 6, to: currentWeekStart) ?? now
        let days = calendar.dateComponents([.day], from: now, to: endOfWeek).day ?? 0
        return max(0, days + 1) // +1 to include today
    }
    
    private func progressColor(for progress: Double) -> Color {
        if progress >= 1.0 { return .green }
        if progress >= 0.7 { return .blue }
        if progress >= 0.4 { return .orange }
        return .red
    }
}

// MARK: - Category Progress Row
struct CategoryProgressRow: View {
    let category: Category
    let completed: Int
    let target: Int
    let progress: Double
    
    private var progressColor: Color {
        if progress >= 1.0 { return .green }
        if progress >= 0.7 { return .blue }
        if progress >= 0.4 { return .orange }
        return .red
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill(category.color.SwiftUIColor)
                        .frame(width: 12, height: 12)
                    
                    Text(category.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                Spacer()
                
                HStack(spacing: 4) {
                    Text("\(completed) / \(target)")
                        .font(.system(.caption, design: .monospaced))
                    
                    if progress >= 1.0 {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
            }
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(progressColor)
                        .frame(
                            width: geometry.size.width * min(progress, 1.0),
                            height: 8
                        )
                }
            }
            .frame(height: 8)
        }
        .padding(.vertical, 4)
    }
}

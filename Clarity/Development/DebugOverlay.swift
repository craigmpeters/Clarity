//
//  DebugOverlay.swift
//  Clarity
//
//  Created by Development Team
//

import SwiftUI
import SwiftData

#if DEBUG

// MARK: - Debug Information Overlay
struct DebugOverlay: View {
    @Environment(\.modelContext) private var modelContext
    @State private var showingDetails = false
    @State private var debugInfo = DebugInfo()
    
    var body: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                
                Button(action: {
                    showingDetails.toggle()
                    if showingDetails {
                        updateDebugInfo()
                    }
                }) {
                    Image(systemName: "ladybug")
                        .font(.title2)
                        .padding(12)
                        .background(Color.black.opacity(0.1))
                        .foregroundStyle(.orange)
                        .clipShape(Circle())
                }
                .padding()
            }
        }
        .overlay(
            debugDetailsOverlay
                .opacity(showingDetails ? 1 : 0)
                .animation(.easeInOut(duration: 0.3), value: showingDetails)
        )
    }
    
    @ViewBuilder
    private var debugDetailsOverlay: some View {
        if showingDetails {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Debug Info")
                        .font(.headline)
                    Spacer()
                    Button("✕") {
                        showingDetails = false
                    }
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    debugInfoRow("Tasks", value: "\(debugInfo.taskCount)")
                    debugInfoRow("Completed", value: "\(debugInfo.completedTaskCount)")
                    debugInfoRow("Categories", value: "\(debugInfo.categoryCount)")
                    debugInfoRow("Recurring", value: "\(debugInfo.recurringTaskCount)")
                    debugInfoRow("Overdue", value: "\(debugInfo.overdueTaskCount)")
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Memory Usage")
                        .font(.subheadline.bold())
                    debugInfoRow("Model Context", value: modelContextStatus)
                }
                
                Spacer()
            }
            .padding()
            .background(.regularMaterial)
            .cornerRadius(12)
            .padding()
            .frame(maxWidth: 300, maxHeight: 400)
        }
    }
    
    private func debugInfoRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(.caption, design: .monospaced))
                .fontWeight(.medium)
        }
    }
    
    private var modelContextStatus: String {
        modelContext.hasChanges ? "Modified" : "Clean"
    }
    
    private func updateDebugInfo() {
        do {
            let allTasksDescriptor = FetchDescriptor<ToDoTask>()
            let allTasks = try modelContext.fetch(allTasksDescriptor)
            
            let categoriesDescriptor = FetchDescriptor<Category>()
            let categories = try modelContext.fetch(categoriesDescriptor)
            
            let now = Date()
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: now)
            
            debugInfo = DebugInfo(
                taskCount: allTasks.count,
                completedTaskCount: allTasks.filter { $0.completed }.count,
                categoryCount: categories.count,
                recurringTaskCount: allTasks.filter { $0.repeating! }.count,
                overdueTaskCount: allTasks.filter { $0.due < startOfDay && !$0.completed }.count
            )
        } catch {
            print("Failed to fetch debug info: \(error)")
        }
    }
}

// MARK: - Debug Information Structure
struct DebugInfo {
    var taskCount: Int = 0
    var completedTaskCount: Int = 0
    var categoryCount: Int = 0
    var recurringTaskCount: Int = 0
    var overdueTaskCount: Int = 0
}

// MARK: - Quick Actions Bar
struct DebugQuickActions: View {
    @Environment(\.modelContext) private var modelContext
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        HStack(spacing: 16) {
            quickActionButton("🎯", title: "Add Sample") {
                addQuickSampleData()
            }
            
            quickActionButton("🧹", title: "Clear All") {
                clearAllData()
            }
            
            quickActionButton("📊", title: "Stats Data") {
                addStatsData()
            }
            
            quickActionButton("⏰", title: "Overdue") {
                addOverdueData()
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .alert("Debug Action", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func quickActionButton(_ icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(icon)
                    .font(.title2)
                Text(title)
                    .font(.caption2)
                    .multilineTextAlignment(.center)
            }
            .frame(minWidth: 60)
        }
        .buttonStyle(.plain)
    }
    
    private func addQuickSampleData() {
        // Add 3 quick tasks for testing
        let sampleTasks = [
            ("Quick Test Task 1", 15),
            ("Quick Test Task 2", 25),
            ("Quick Test Task 3", 30)
        ]
        
        for (name, minutes) in sampleTasks {
            let task = ToDoTask(
                name: name,
                pomodoroTime: TimeInterval(minutes * 60)
            )
            modelContext.insert(task)
        }
        
        saveContext()
        showAlert("Added 3 sample tasks")
    }
    
    private func clearAllData() {
        do {
            let tasksDescriptor = FetchDescriptor<ToDoTask>()
            let tasks = try modelContext.fetch(tasksDescriptor)
            
            let categoriesDescriptor = FetchDescriptor<Category>()
            let categories = try modelContext.fetch(categoriesDescriptor)
            
            for task in tasks {
                modelContext.delete(task)
            }
            for category in categories {
                modelContext.delete(category)
            }
            
            saveContext()
            showAlert("Cleared all data")
        } catch {
            showAlert("Failed to clear data: \(error.localizedDescription)")
        }
    }
    
    private func addStatsData() {
        let calendar = Calendar.current
        let now = Date()
        
        // Add completed tasks for the past week
        for dayOffset in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: now) else { continue }
            
            let taskCount = Int.random(in: 1...3)
            for taskIndex in 0..<taskCount {
                let task = ToDoTask(
                    name: "Stats Task \(dayOffset)-\(taskIndex)",
                    pomodoroTime: TimeInterval(25 * 60),
                    due: date
                )
                task.completed = true
                task.completedAt = date.addingTimeInterval(Double.random(in: 0...86400))
                modelContext.insert(task)
            }
        }
        
        saveContext()
        showAlert("Added stats data for past week")
    }
    
    private func addOverdueData() {
        let calendar = Calendar.current
        let overdueDates = [
            calendar.date(byAdding: .day, value: -1, to: Date())!,
            calendar.date(byAdding: .day, value: -3, to: Date())!,
            calendar.date(byAdding: .day, value: -7, to: Date())!
        ]
        
        for (index, date) in overdueDates.enumerated() {
            let task = ToDoTask(
                name: "Overdue Task \(index + 1)",
                pomodoroTime: TimeInterval(20 * 60),
                due: date
            )
            modelContext.insert(task)
        }
        
        saveContext()
        showAlert("Added 3 overdue tasks")
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

// MARK: - Debug View Modifiers
struct DebugOverlayModifier: ViewModifier {
    @State private var showingQuickActions = false
    
    func body(content: Content) -> some View {
        content
            .overlay(
                VStack {
                    if showingQuickActions {
                        DebugQuickActions()
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    Spacer()
                }
                .animation(.easeInOut(duration: 0.3), value: showingQuickActions)
            )
            .overlay(
                DebugOverlay()
            )
            .onShake {
                showingQuickActions.toggle()
            }
    }
}

// MARK: - Shake Gesture Detection
extension UIDevice {
    static let deviceDidShakeNotification = Notification.Name(rawValue: "deviceDidShakeNotification")
}

extension UIWindow {
    open override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            NotificationCenter.default.post(name: UIDevice.deviceDidShakeNotification, object: nil)
        }
    }
}

struct DeviceShakeViewModifier: ViewModifier {
    let action: () -> Void
    
    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: UIDevice.deviceDidShakeNotification)) { _ in
                action()
            }
    }
}

extension View {
    func onShake(perform action: @escaping () -> Void) -> some View {
        self.modifier(DeviceShakeViewModifier(action: action))
    }
    
    func debugOverlay() -> some View {
        #if DEBUG
        return self.modifier(DebugOverlayModifier())
        #else
        return self
        #endif
    }
}

#endif

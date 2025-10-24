//
//  LogCenter.swift
//  Clarity
//
//  Created by Craig Peters on 24/10/2025.
//

import SwiftUI
import Combine

// MARK: - Feature Flags
struct FeatureFlags {
    // Reads default enablement from Info.plist key `LOG_VIEWER_ENABLED` (Boolean) or falls back to false.
    static var logViewerDefaultEnabled: Bool = {
        if let info = Bundle.main.infoDictionary {
            if let value = info["LOG_VIEWER_ENABLED"] as? Bool {
                return value
            }
            if let stringValue = info["LOG_VIEWER_ENABLED"] as? String {
                return (stringValue as NSString).boolValue
            }
        }
        // As a convenience, allow enabling via process env (useful for previews/tests)
        if let env = ProcessInfo.processInfo.environment["LOG_VIEWER_ENABLED"], (env as NSString).boolValue == true {
            return true
        }
        return false
    }()
}

private struct LogViewerEnabledKey: EnvironmentKey {
    static let defaultValue: Bool = FeatureFlags.logViewerDefaultEnabled
}

extension EnvironmentValues {
    var isLogViewerEnabled: Bool {
        get { self[LogViewerEnabledKey.self] }
        set { self[LogViewerEnabledKey.self] = newValue }
    }
}

final class LogCenter: ObservableObject {
    @Published var entries: [LogEntry] = []
    
    static let shared = LogCenter()
    
    func append(message: String, level: LogLevel) {
        DispatchQueue.main.async {
            self.entries.append(LogEntry(id: UUID(), date: Date(), level: level, message: message))
        }
    }
    
    func clear() {
        DispatchQueue.main.async {
            self.entries.removeAll()
        }
    }
}

struct LogEntry: Identifiable {
    let id: UUID
    let date: Date
    let level: LogLevel
    let message: String
}

enum LogLevel: String, CaseIterable, Identifiable {
    case debug = "Debug"
    case info = "Info"
    case warning = "Warning"
    case error = "Error"
    
    var id: String { rawValue }
    
    var color: Color {
        switch self {
        case .debug: return .gray
        case .info: return .blue
        case .warning: return .orange
        case .error: return .red
        }
    }
}

func log(_ message: String, level: LogLevel = .info) {
    LogCenter.shared.append(message: message, level: level)
}

private struct LogCenterKey: EnvironmentKey {
    static let defaultValue: LogCenter = LogCenter.shared
}

extension EnvironmentValues {
    var logCenter: LogCenter {
        get { self[LogCenterKey.self] }
        set { self[LogCenterKey.self] = newValue }
    }
}

struct LogView: View {
    @Environment(\.logCenter) var logCenter
    @State private var selectedFilter: LogLevel? = nil
    @State private var query: String = ""
    
    private var filteredEntries: [LogEntry] {
        logCenter.entries
            .filter { entry in
                (selectedFilter == nil || entry.level == selectedFilter)
                && (query.isEmpty || entry.message.localizedCaseInsensitiveContains(query))
            }
            .sorted { $0.date > $1.date }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                Picker("Level", selection: $selectedFilter) {
                    Text("All").tag(LogLevel?.none)
                    ForEach(LogLevel.allCases) { level in
                        Text(level.rawValue).tag(Optional(level))
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                
                List(filteredEntries) { entry in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(entry.date, style: .time)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(entry.level.rawValue)
                                .font(.caption2.bold())
                                .padding(4)
                                .background(entry.level.color.opacity(0.2))
                                .foregroundColor(entry.level.color)
                                .cornerRadius(4)
                        }
                        Text(entry.message)
                            .font(.body)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 4)
                }
                .listStyle(PlainListStyle())
            }
            .navigationTitle("Logs")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Clear") {
                        logCenter.clear()
                    }
                }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search logs")
        }
    }
}

#Preview {
    let center = LogCenter()
    center.append(message: "System started", level: .info)
    center.append(message: "User logged in", level: .info)
    center.append(message: "Failed to load resource", level: .warning)
    center.append(message: "Unexpected error occurred", level: .error)
    center.append(message: "Debugging info: variable x = 42", level: .debug)
    return LogView()
        .environment(\.logCenter, center)
        .environment(\.isLogViewerEnabled, true)
}

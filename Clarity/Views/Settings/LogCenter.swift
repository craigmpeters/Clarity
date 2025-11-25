//
//  LogCenter.swift
//  Clarity
//
//  Created by Craig Peters on 24/10/2025.
//

import SwiftUI
import Combine
import OSLog

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

final class LogCenter: @MainActor ObservableObject {
    @Published var entries: [String] = []
    
    nonisolated(unsafe) static let shared = LogCenter()
    
    func loadEntries() async {
        do {
            let store = try OSLogStore(scope: .currentProcessIdentifier)
            let bundleID = Bundle.main.bundleIdentifier ?? ""
            let predicate = NSPredicate(format: "subsystem == %@", bundleID)
            let position = store.position(date: .distantPast)
            let entriesSeq = try store.getEntries(at: position, matching: predicate)

            // Count total entries before narrowing to logs and include multiple entry types
            
            var totalCount = 0
            var lines: [String] = []
            for entry in entriesSeq {
                totalCount += 1

                // Only include entries from this app's subsystem (bundle identifier)
                if let log = entry as? OSLogEntryLog, log.subsystem == bundleID {
                    lines.append("[\(log.date.formatted())] [\(log.subsystem)][\(log.category)] \(log.composedMessage)")
                    continue
                }
                if let signpost = entry as? OSLogEntrySignpost, signpost.subsystem == bundleID {
                    lines.append("[\(signpost.date.formatted())] [\(signpost.subsystem)][\(signpost.category)] <signpost: \(signpost.signpostName)>")
                    continue
                }
                if let activity = entry as? OSLogEntryActivity {
                    // Some activity entries may not carry subsystem; include only if process matches our bundleID when available
                    lines.append("[\(activity.date.formatted())] <activity: \(activity.process)>")
                    continue
                }
            }
            await MainActor.run { [lines] in
                self.entries = lines
                Logger.LogViewer.trace("Total lines displayed: \(self.entries.count)")
            }
        } catch {
            Logger.LogViewer.error("Error Fetching OSLogStore: \(error.localizedDescription)")
        }
        
    }
}

private struct LogCenterKey: EnvironmentKey {
    nonisolated static let defaultValue: LogCenter = LogCenter.shared
}

extension EnvironmentValues {
    var logCenter: LogCenter {
        get { self[LogCenterKey.self] }
        set { self[LogCenterKey.self] = newValue }
    }
}

struct LogView: View {
    @EnvironmentObject var logCenter: LogCenter

    private func styleFor(entry: String) -> (date: String, subsystem: String, category: String, message: String, color: Color) {
        // Expected format: [date] [subsystem][category] message
        var date = ""
        var subsystem = ""
        var category = ""
        var message = entry
        var color: Color = .primary

        // Extract [date]
        if let firstClose = entry.firstIndex(of: "]") {
            date = String(entry[entry.index(after: entry.startIndex)..<firstClose])
            let rest = entry[entry.index(after: firstClose)...].trimmingCharacters(in: .whitespaces)

            // Extract [subsystem][category]
            if rest.hasPrefix("["),
               let secondClose = rest.dropFirst().firstIndex(of: "]") {
                let afterOpen = rest.index(after: rest.startIndex)
                subsystem = String(rest[afterOpen..<secondClose])
                let afterSub = rest[rest.index(after: secondClose)...].trimmingCharacters(in: .whitespaces)

                if afterSub.hasPrefix("["),
                   let thirdClose = afterSub.dropFirst().firstIndex(of: "]") {
                    let afterOpen2 = afterSub.index(after: afterSub.startIndex)
                    category = String(afterSub[afterOpen2..<thirdClose])
                    let afterCat = afterSub[afterSub.index(after: thirdClose)...].trimmingCharacters(in: .whitespaces)
                    message = String(afterCat)
                } else {
                    message = String(afterSub)
                }
            } else {
                message = String(rest)
            }
        }

        // Color heuristic based on category/keywords
        let lower = (category + " " + message).lowercased()
        if lower.contains("fault") || lower.contains("error") || lower.contains("fail") {
            color = .red
        } else if lower.contains("warn") || lower.contains("warning") || lower.contains("notice") {
            color = .orange
        } else if lower.contains("info") {
            color = .blue
        } else if lower.contains("debug") || lower.contains("trace") {
            color = .gray
        } else {
            color = .primary
        }

        return (date, subsystem, category, message, color)
    }
    
    var body: some View {
        NavigationView {
            List(logCenter.entries, id: \.self) { entry in
                let styled = styleFor(entry: entry)
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(styled.date)
                            .font(.caption2.monospaced())
                            .foregroundStyle(.secondary)
                        if !styled.category.isEmpty {
                            Text(styled.category.uppercased())
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(styled.color.opacity(0.12))
                                )
                                .foregroundStyle(styled.color)
                        }
                        Spacer(minLength: 0)
                    }

                    Text(styled.message)
                        .font(.callout)
                        .foregroundStyle(styled.color == .primary ? .primary : styled.color)
                        .textSelection(.enabled)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 6)
            }
            .listStyle(PlainListStyle())
            .navigationTitle("Logs")
            .onAppear {
                Logger.LogViewer.info("LogView appeared – requesting logs")
                Task { await logCenter.loadEntries() }
            }
            .refreshable {
                Logger.LogViewer.info("User pulled to refresh – requesting logs")
                await logCenter.loadEntries()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Load") {
                        Logger.LogViewer.info("Load button tapped – requesting logs")
                        Task { await logCenter.loadEntries() }
                    }
                }
            }
        }
    }
}


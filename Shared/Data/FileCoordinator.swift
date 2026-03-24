//
//  FileCoordinator.swift
//  Clarity
//
//  Created by Craig Peters on 06/12/2025.
//
import Foundation
import os
import SwiftData
import Compression
import XCGLogger
#if canImport(WidgetKit)
import WidgetKit
#endif


// File payload is an array of tasks. Adjust if your schema differs.
public typealias ToDoTaskList = [ToDoTaskDTO]

// MARK: - File Presenter to observe external changes
final class WidgetFilePresenter: NSObject, NSFilePresenter {
    let presentedItemURL: URL?
    let presentedItemOperationQueue: OperationQueue
    private let onChange: @Sendable () -> Void

    init(url: URL, onChange: @escaping @Sendable () -> Void) {
        self.presentedItemURL = url
        self.presentedItemOperationQueue = {
            let q = OperationQueue()
            q.maxConcurrentOperationCount = 1
            q.qualityOfService = .userInitiated
            return q
        }()
        self.onChange = onChange
        super.init()
        NSFileCoordinator.addFilePresenter(self)
    }

    deinit {
        NSFileCoordinator.removeFilePresenter(self)
    }

    func presentedSubitemDidChange(at url: URL) { /* not used */ }

    func presentedItemDidChange() {
        onChange()
    }
}

// MARK: - Coordinator for safe reads/writes via App Group
public final class WidgetFileCoordinator: @unchecked Sendable {
    public static let shared = WidgetFileCoordinator()

    private let appGroupID = "group.me.craigpeters.clarity"
    private let fileName = "ClarityWidget.json"
    private let weeklyProgressFileName = "ClarityWeeklyProgress.json"
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Clarity", category: "WidgetFileCoordinator")

    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let queue = DispatchQueue(label: "WidgetFileCoordinator.serial")

    private var presenter: WidgetFilePresenter?

    private init() {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
        enc.dateEncodingStrategy = .iso8601
        self.encoder = enc

        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        self.decoder = dec

        // Ensure directory and file exist, set up presenter
        if let url = fileURL() {
            createDirectoryIfNeeded(url.deletingLastPathComponent())
            createFileIfNeeded(at: url)
            self.presenter = WidgetFilePresenter(url: url) { [weak self] in
                LogManager.shared.log.notice("Presented item changed")
                // Hook: Post notifications or refresh caches if needed
            }
        } else {
            LogManager.shared.log.error("Failed to resolve App Group container URL.")
        }
    }

    // MARK: URL Helpers
    private func containerURL() -> URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
    }

    private func fileURL() -> URL? {
        containerURL()?.appendingPathComponent(fileName)
    }

    private func createDirectoryIfNeeded(_ dir: URL) {
        var isDir: ObjCBool = false
        if !FileManager.default.fileExists(atPath: dir.path, isDirectory: &isDir) || !isDir.boolValue {
            do { try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true) } catch {
                LogManager.shared.log.error("Failed to create directory: \(error.localizedDescription)")
            }
        }
    }

    private func createFileIfNeeded(at url: URL) {
        if !FileManager.default.fileExists(atPath: url.path) {
            do {
                let tasks: ToDoTaskList = ClarityServices.snapshotTasks(filter: .all)
                let data = try encoder.encode(tasks)
                FileManager.default.createFile(atPath: url.path, contents: data)
            } catch {
                LogManager.shared.log.error("Failed to create initial file: \(error.localizedDescription)")
            }
        }
    }
    
    func readTasks(With filter: ToDoTask.CompletedTaskFilter) throws -> ToDoTaskList {
        let tasks = try readTasks()
        return tasks
            .filter { filter.matches($0)}
    }
    
    func readTasks(with filter: ToDoTask.TaskFilter) throws -> ToDoTaskList {
        let now = Date()
        let tasks = try readTasks()
        return tasks
            .filter { filter.matches(dto: $0, at: now) }
    }

    // MARK: Reading
    
    public func readTaskById(id: PersistentIdentifier) throws -> ToDoTaskDTO? {
        do {
            let tasks = ToDoTaskDTO.focusFilter(in: try readTasks())
            return tasks.first { $0.id == id }
        } catch {
            LogManager.shared.log.error("Cannot find Task: \(error.localizedDescription)")
            return nil
        }
    }
    
    public func readTaskByUuid(_ id: UUID) throws -> ToDoTaskDTO? {
        do {
            let tasks = ToDoTaskDTO.focusFilter(in: try readTasks())
            return tasks.first { $0.uuid == id}
        } catch {
            LogManager.shared.log.error("Cannot find task: \(error.localizedDescription)")
            return nil
        }
    }
    
    public func readTasks() throws -> ToDoTaskList {
        guard let url = fileURL() else { throw NSError(domain: "WidgetFileCoordinator", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing App Group URL"]) }

        var readError: NSError?
        var result: ToDoTaskList = []

        let coordinator = NSFileCoordinator(filePresenter: presenter)

        // Use separate inner error/result to avoid overlapping access with the error pointer borrowed by NSFileCoordinator
        var coordinationError: NSError?
        var innerError: NSError?
        var innerResult: ToDoTaskList = []

        coordinator.coordinate(readingItemAt: url, options: .withoutChanges, error: &coordinationError) { readURL in
            do {
                let data = try Data(contentsOf: readURL, options: [.mappedIfSafe])
                if data.isEmpty {
                    innerResult = []
                } else {
                    innerResult = try decoder.decode(ToDoTaskList.self, from: data)
                }
            } catch {
                innerError = error as NSError
            }
        }

        // Copy inner values back after coordination completes
        if let coordinationError { readError = coordinationError }
        if let innerError { readError = innerError }
        result = innerResult
        LogManager.shared.log.debug("Found \(result.count) tasks of which \(result.filter(\.completed).count) are completed")

        if let readError { throw readError }
        return result
    }

    // MARK: Writing (atomic)
    public func writeTasks(_ tasks: ToDoTaskList) throws {
        guard let url = fileURL() else { throw NSError(domain: "WidgetFileCoordinator", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing App Group URL"]) }

        var writeError: NSError?
        let coordinator = NSFileCoordinator(filePresenter: presenter)
        LogManager.shared.log.debug("Found \(tasks.count) tasks of which \(tasks.filter(\.completed).count) are completed")

        // Use separate inner error to avoid overlapping access with the error pointer borrowed by NSFileCoordinator
        var coordinationError: NSError?
        var innerError: NSError?

        coordinator.coordinate(writingItemAt: url, options: .forReplacing, error: &coordinationError) { writeURL in
            do {
                let data = try encoder.encode(tasks)
                // Write atomically to a temporary file, then replace
                let tmp = writeURL.deletingLastPathComponent().appendingPathComponent(".tmp_\(UUID().uuidString)")
                try data.write(to: tmp, options: .atomic)
                // Replace the destination with the temp file
                try _ = FileManager.default.replaceItemAt(writeURL, withItemAt: tmp)
            } catch {
                innerError = error as NSError
            }
        }

        // Copy inner error back after coordination completes
        if let coordinationError { writeError = coordinationError }
        if let innerError { writeError = innerError }

        if let writeError { throw writeError }
        notifyWidgetReload()
    }

    // Async convenience wrappers
    public func readTasksAsync() async throws -> ToDoTaskList {
        try await withCheckedThrowingContinuation { cont in
            queue.async {
                do { cont.resume(returning: try self.readTasks()) }
                catch { cont.resume(throwing: error) }
            }
        }
    }

    public func writeTasksAsync(_ tasks: ToDoTaskList) async throws {
        try await withCheckedThrowingContinuation { cont in
            queue.async {
                do { try self.writeTasks(tasks); cont.resume() }
                catch { cont.resume(throwing: error) }
            }
        }
    }
    
    // MARK: Compressed Data
    public func compressedData() throws -> Data {
        // Read tasks from file and compress the JSON payload (zlib/deflate)
        let tasks = try readTasks()
        LogManager.shared.log.debug("Compress: Found \(tasks.count) of which \(tasks.filter(\.completed).count) are completed")
        let json = try encoder.encode(tasks)
        // Compress using OutputFilter (.compress) with zlib settings
        var compressed = Data()
        var filter = try OutputFilter(.compress, using: .zlib) { chunk in
            if let chunk { compressed.append(chunk) }
        }
        try filter.write(json)
        try filter.finalize()
        return compressed
    }

    /// Decompress compressed task data (zlib/deflate) and decode it into a task list.
    /// - Parameter data: Compressed data created by `compressedData()`
    /// - Returns: Decoded list of tasks
    public func decodeCompressedData(_ data: Data) throws -> ToDoTaskList {
        var output = Data()
        var filter = try OutputFilter(.decompress, using: .zlib) { chunk in
            if let chunk { output.append(chunk) }
        }
        try filter.write(data)
        try filter.finalize()
        let tasks = try decoder.decode(ToDoTaskList.self, from: output)
        LogManager.shared.log.debug("Decompress: Found \(tasks.count) of which \(tasks.filter(\.completed).count) are completed")
        return tasks
    }
        
        
        public func writeLogFile(fileName: String, data: Data) throws {
            let unzipped = try unzipData(data)
            let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.me.craigpeters.clarity")
            let fileURL = (containerURL ?? LogManager.fallbackDocumentsDirectory()).appendingPathComponent(fileName)
            try unzipped.write(to: fileURL, options: .atomic)
        }
        
        func logFileURLs() -> [URL] {
            let dir = LogManager.sharedLogFileURL().deletingLastPathComponent()
            let fm = FileManager.default
            let contents = (try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])) ?? []
            // Include primary log and rotated logs
            return contents.filter { $0.pathExtension.lowercased() == "log" }
        }
        
        /// Collects logs into a list of data which is then compressed
        public func collectlogs() -> Data {
            let urls = logFileURLs()
            let fm = FileManager.default

            // Sort URLs by modification date (oldest first)
            let sortedURLs: [URL] = urls.sorted { a, b in
                let aDate = (try? fm.attributesOfItem(atPath: a.path)[.modificationDate] as? Date) ?? .distantPast
                let bDate = (try? fm.attributesOfItem(atPath: b.path)[.modificationDate] as? Date) ?? .distantPast
                return aDate < bDate
            }

            // Concatenate as text with separators to preserve readability/order
            var combinedText = ""
            for (idx, url) in sortedURLs.enumerated() {
                do {
                    let text = try String(contentsOf: url, encoding: .utf8)
                    let header = "\n\n===== BEGIN LOG (\(idx + 1))/\(sortedURLs.count): \(url.lastPathComponent) =====\n"
                    let footer = "\n===== END LOG: \(url.lastPathComponent) =====\n"
                    combinedText.append(header)
                    combinedText.append(text)
                    combinedText.append(footer)
                } catch {
                    LogManager.shared.log.error("Cannot read log file: \(error.localizedDescription)")
                }
            }

            // Compress the concatenated text
            let payload = Data(combinedText.utf8)
            do {
                return try zipData(with: [payload])
            } catch {
                LogManager.shared.log.error("Compression failed: \(error.localizedDescription)")
                return Data()
            }
        }
        
        private func zipData(with data: [Data]) throws -> Data {
            var compressed = Data()
            var filter = try OutputFilter(.compress, using: .zlib) { chunk in
                if let chunk { compressed.append(chunk) }
            }
            // Concatenate all data parts into a single buffer. Alternatively, we could stream them one by one.
            let combined = data.reduce(into: Data()) { $0.append($1) }
            try filter.write(combined)
            try filter.finalize()
            return compressed
        }
        
        /// Decompresses zlib-compressed data produced by `zipData(with:)`.
    private func unzipData(_ compressed: Data) throws -> Data {
        var output = Data()
        var filter = try OutputFilter(.decompress, using: .zlib) { chunk in
            if let chunk { output.append(chunk) }
        }
        try filter.write(compressed)
        try filter.finalize()
        // The compressed payload is a concatenation of logs without delimiters; return as a single part for now.
        return output
    }

    /// Decompresses and writes the provided compressed data to the shared file atomically.
    public func applyCompressedData(_ data: Data) throws {
        let tasks = try decodeCompressedData(data)
        try writeTasks(tasks)
    }
    
    // MARK: Snapshot (tasks + progress bundled)

    /// Compresses a `WatchUserInfo` (tasks + weekly progress) into a single Data payload.
    public func compressedSnapshot() throws -> Data {
        let tasks = try readTasks()
        let progress = readWeeklyProgress() ?? WeeklyProgress(completed: 0, target: 0, error: nil, categories: [])
        let snapshot = WatchUserInfo(tasks: tasks, progress: progress)
        let json = try encoder.encode(snapshot)
        var compressed = Data()
        var filter = try OutputFilter(.compress, using: .zlib) { chunk in
            if let chunk { compressed.append(chunk) }
        }
        try filter.write(json)
        try filter.finalize()
        return compressed
    }

    /// Decompresses and decodes a `WatchUserInfo` payload produced by `compressedSnapshot()`.
    public func decodeCompressedSnapshot(_ data: Data) throws -> WatchUserInfo {
        var output = Data()
        var filter = try OutputFilter(.decompress, using: .zlib) { chunk in
            if let chunk { output.append(chunk) }
        }
        try filter.write(data)
        try filter.finalize()
        return try decoder.decode(WatchUserInfo.self, from: output)
    }

    // MARK: Weekly Progress
    private func weeklyProgressURL() -> URL? {
        containerURL()?.appendingPathComponent(weeklyProgressFileName)
    }

    public func writeWeeklyProgress(_ progress: WeeklyProgress) throws {
        guard let url = weeklyProgressURL() else { return }
        let data = try encoder.encode(progress)
        try data.write(to: url, options: .atomic)
        notifyWidgetReload()
    }

    public func readWeeklyProgress() -> WeeklyProgress? {
        guard let url = weeklyProgressURL(),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode(WeeklyProgress.self, from: data)
    }

    // MARK: Widget refresh hook
    private func notifyWidgetReload() {
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
}


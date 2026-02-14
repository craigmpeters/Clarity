//
//  FileCoordinator.swift
//  Clarity
//
//  Created by Craig Peters on 06/12/2025.
//
import Foundation
import os
import SwiftData
import XCGLogger

// File payload is an array of tasks. Adjust if your schema differs.
public typealias ToDoTaskList = [ToDoTaskDTO]

// MARK: Data file kinds
public enum DataFileKind: Sendable, CaseIterable {
    case incomplete
    case completed

    var fileName: String {
        switch self {
        case .incomplete:
            return "ClarityWidget.json" // existing default file
        case .completed:
            return "ClarityCompletedLastWeek.json"
        }
    }
}

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

    private let logger = LogManager.shared.log

    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let queue = DispatchQueue(label: "WidgetFileCoordinator.serial")

    private var presenter: WidgetFilePresenter?
    private var presenters: [DataFileKind: WidgetFilePresenter] = [:]

    private init() {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
        enc.dateEncodingStrategy = .iso8601
        self.encoder = enc

        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        self.decoder = dec

        // Ensure directories/files exist for all kinds and set up presenters
        for kind in DataFileKind.allCases {
            guard let url = fileURL(for: kind) else {
                LogManager.shared.log.error("Failed to resolve App Group container URL for kind: \(kind)")
                continue
            }
            createDirectoryIfNeeded(url.deletingLastPathComponent())
            createFileIfNeeded(at: url, for: kind)
            let presenter = WidgetFilePresenter(url: url) { [weak self] in
                LogManager.shared.log.notice("Presented item changed for kind: \(kind)")
                // Hook: Post notifications or refresh caches if needed
            }
            self.presenters[kind] = presenter
        }
    }

    // MARK: URL Helpers
    private func containerURL() -> URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
    }

    private func fileURL(for kind: DataFileKind) -> URL? {
        containerURL()?.appendingPathComponent(kind.fileName)
    }

    private func createDirectoryIfNeeded(_ dir: URL) {
        var isDir: ObjCBool = false
        if !FileManager.default.fileExists(atPath: dir.path, isDirectory: &isDir) || !isDir.boolValue {
            do { try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true) } catch {
                LogManager.shared.log.error("Failed to create directory: \(error.localizedDescription)")
            }
        }
    }

    private func createFileIfNeeded(at url: URL, for kind: DataFileKind) {
        if !FileManager.default.fileExists(atPath: url.path) {
            do {
                let now = Date()
                var tasks: ToDoTaskList
                switch kind {
                case .incomplete:
                    tasks = ClarityServices.snapshotTasks(filter: .all)
                case .completed:
                    tasks = ClarityServices.snapshotCompleted()
                }
                let data = try encoder.encode(tasks)
                FileManager.default.createFile(atPath: url.path, contents: data)
            } catch {
                LogManager.shared.log.error("Failed to create initial file for kind \(kind): \(error.localizedDescription)")
            }
        }
    }

    func readTasks(with filter: ToDoTask.TaskFilter, kind: DataFileKind = .incomplete) throws -> ToDoTaskList {
        let now = Date()
        let tasks = try readTasks(kind: kind)
        return tasks.filter { filter.matches(dto: $0, at: now) }
    }

    // MARK: Reading

    public func readTaskById(id: PersistentIdentifier, kind: DataFileKind = .incomplete) throws -> ToDoTaskDTO? {
        do {
            let tasks = ToDoTaskDTO.focusFilter(in: try readTasks(kind: kind))
            return tasks.first { $0.id == id }
        } catch {
            LogManager.shared.log.error("Cannot find Task: \(error.localizedDescription)")
            return nil
        }
    }

    public func readTaskByUuid(_ id: UUID, kind: DataFileKind = .incomplete) throws -> ToDoTaskDTO? {
        do {
            let tasks = ToDoTaskDTO.focusFilter(in: try readTasks(kind: kind))
            return tasks.first { $0.uuid == id }
        } catch {
            LogManager.shared.log.error("Cannot find task: \(error.localizedDescription)")
            return nil
        }
    }

    public func readTasks(kind: DataFileKind = .incomplete) throws -> ToDoTaskList {
        guard let url = fileURL(for: kind) else { throw NSError(domain: "WidgetFileCoordinator", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing App Group URL"]) }

        var readError: NSError?
        var result: ToDoTaskList = []

        // Prefer a presenter for this kind, fall back to the original single presenter for backward compatibility
        let coordinator = NSFileCoordinator(filePresenter: presenters[kind] ?? presenter)

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

        if let coordinationError { readError = coordinationError }
        if let innerError { readError = innerError }
        result = innerResult

        if let readError { throw readError }
        return result
    }

    // MARK: Writing (atomic)
    public func writeTasks(_ tasks: ToDoTaskList, kind: DataFileKind = .incomplete) throws {
        guard let url = fileURL(for: kind) else { throw NSError(domain: "WidgetFileCoordinator", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing App Group URL"]) }
        
        LogManager.shared.log.verbose("Writing \(tasks.count) tasks for \(kind)")
        var writeError: NSError?
        let coordinator = NSFileCoordinator(filePresenter: presenters[kind] ?? presenter)

        var coordinationError: NSError?
        var innerError: NSError?

        coordinator.coordinate(writingItemAt: url, options: .forReplacing, error: &coordinationError) { writeURL in
            do {
                let data = try encoder.encode(tasks)
                let tmp = writeURL.deletingLastPathComponent().appendingPathComponent(".tmp_\(UUID().uuidString)")
                try data.write(to: tmp, options: .atomic)
                try _ = FileManager.default.replaceItemAt(writeURL, withItemAt: tmp)
            } catch {
                innerError = error as NSError
            }
        }

        if let coordinationError { writeError = coordinationError }
        if let innerError { writeError = innerError }

        if let writeError {
            LogManager.shared.log.error("Error writing tasks for type \(kind) : \(writeError)")
            throw writeError
        }
        notifyWidgetReload()
    }

    // Async convenience wrappers
    public func readTasksAsync(kind: DataFileKind = .incomplete) async throws -> ToDoTaskList {
        try await withCheckedThrowingContinuation { cont in
            queue.async {
                do { cont.resume(returning: try self.readTasks(kind: kind)) }
                catch { cont.resume(throwing: error) }
            }
        }
    }

    public func writeTasksAsync(_ tasks: ToDoTaskList, kind: DataFileKind = .incomplete) async throws {
        try await withCheckedThrowingContinuation { cont in
            queue.async {
                do { try self.writeTasks(tasks, kind: kind); cont.resume() }
                catch { cont.resume(throwing: error) }
            }
        }
    }

    // MARK: Widget refresh hook
    private func notifyWidgetReload() {
        // If you have WidgetKit imported in this target, you can uncomment:
        // WidgetCenter.shared.reloadAllTimelines()
    }
}


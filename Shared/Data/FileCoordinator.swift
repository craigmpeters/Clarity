//
//  FileCoordinator.swift
//  Clarity
//
//  Created by Craig Peters on 06/12/2025.
//
import Foundation
import os
import SwiftData

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
                self?.logger.debug("Presented item changed")
                // Hook: Post notifications or refresh caches if needed
            }
        } else {
            logger.error("Failed to resolve App Group container URL.")
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
                logger.error("Failed to create directory: \(error.localizedDescription)")
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
                logger.error("Failed to create initial file: \(error.localizedDescription)")
            }
        }
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
            Logger.ClarityServices.error("Cannot find Task: \(error.localizedDescription, privacy: .public)")
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

        if let readError { throw readError }
        return result
    }

    // MARK: Writing (atomic)
    public func writeTasks(_ tasks: ToDoTaskList) throws {
        guard let url = fileURL() else { throw NSError(domain: "WidgetFileCoordinator", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing App Group URL"]) }

        var writeError: NSError?
        let coordinator = NSFileCoordinator(filePresenter: presenter)

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
                try FileManager.default.replaceItemAt(writeURL, withItemAt: tmp)
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

    // MARK: Widget refresh hook
    private func notifyWidgetReload() {
        // If you have WidgetKit imported in this target, you can uncomment:
        // WidgetCenter.shared.reloadAllTimelines()
    }
}


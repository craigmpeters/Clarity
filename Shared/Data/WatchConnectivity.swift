//
//  WatchConnectivity.swift
//  Clarity
//
//  Created by Craig Peters on 29/09/2025.
//

import Foundation
import WatchConnectivity
import Combine
import XCGLogger

// MARK: - Message Keys

public enum WCKeys: Sendable {
    public static nonisolated let request = "request"
    public static nonisolated let payload = "payload"

    public enum Requests: Sendable {
        public static nonisolated let listAll        = "listAll"
        public static nonisolated let complete       = "complete"
        public static nonisolated let create         = "create"
        public static nonisolated let delete         = "delete"
        public static nonisolated let startPomodoro  = "startPomodoro"
        public static nonisolated let stopPomodoro   = "stopPomodoro"
        public static nonisolated let pomodoroStarted = "pomodoroStarted"
        public static nonisolated let pomodoroStopped = "pomodoroStopped"
        public static nonisolated let sendLogs       = "sendLogs"
        public static nonisolated let widgetData     = "widgetData"
        public static nonisolated let weeklyProgress = "weeklyProgress"
        public static nonisolated let widgetSnapshot = "widgetSnapshot"
    }
}

// MARK: - Transfer Types

public struct PomodoroDTO: Sendable {
    public var startTime: Date?
    public var endTime: Date?
    public var toDoTask: ToDoTaskDTO
}

extension PomodoroDTO: Codable {
    enum CodingKeys: String, CodingKey { case startTime, endTime, toDoTask }
    nonisolated public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.startTime = try c.decodeIfPresent(Date.self, forKey: .startTime)
        self.endTime = try c.decodeIfPresent(Date.self, forKey: .endTime)
        self.toDoTask = try c.decode(ToDoTaskDTO.self, forKey: .toDoTask)
    }
    nonisolated public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(startTime, forKey: .startTime)
        try c.encodeIfPresent(endTime, forKey: .endTime)
        try c.encode(toDoTask, forKey: .toDoTask)
    }
}

/// Generic envelope used for all watch message payloads.
public struct Envelope: Sendable {
    public let kind: String
    public let todos: [ToDoTaskDTO]?
    public let todo: ToDoTaskDTO?
    public let todotaskid: String?
    public let pomodoro: PomodoroDTO?
    public let logs: Data?
    public let widgetData: WatchWidgetData?
    public let weeklyProgress: WeeklyProgress?

    public init(
        kind: String,
        todos: [ToDoTaskDTO]? = nil,
        todo: ToDoTaskDTO? = nil,
        todotaskid: String? = nil,
        pomodoro: PomodoroDTO? = nil,
        logs: Data? = nil,
        data: WatchWidgetData? = nil,
        progress: WeeklyProgress? = nil
    ) {
        self.kind = kind
        self.todos = todos
        self.todo = todo
        self.todotaskid = todotaskid
        self.pomodoro = pomodoro
        self.logs = logs
        self.widgetData = data
        self.weeklyProgress = progress
    }
}

extension Envelope: Codable {
    enum CodingKeys: String, CodingKey {
        case kind, todos, todo, todotaskid, pomodoro, logs, widgetData, weeklyProgress
    }

    nonisolated public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.kind = try c.decode(String.self, forKey: .kind)
        self.todos = try c.decodeIfPresent([ToDoTaskDTO].self, forKey: .todos)
        self.todo = try c.decodeIfPresent(ToDoTaskDTO.self, forKey: .todo)
        self.todotaskid = try c.decodeIfPresent(String.self, forKey: .todotaskid)
        self.pomodoro = try c.decodeIfPresent(PomodoroDTO.self, forKey: .pomodoro)
        self.logs = try c.decodeIfPresent(Data.self, forKey: .logs)
        self.widgetData = try c.decodeIfPresent(WatchWidgetData.self, forKey: .widgetData)
        self.weeklyProgress = try c.decodeIfPresent(WeeklyProgress.self, forKey: .weeklyProgress)
    }

    nonisolated public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(kind, forKey: .kind)
        try c.encodeIfPresent(todos, forKey: .todos)
        try c.encodeIfPresent(todo, forKey: .todo)
        try c.encodeIfPresent(todotaskid, forKey: .todotaskid)
        try c.encodeIfPresent(pomodoro, forKey: .pomodoro)
        try c.encodeIfPresent(logs, forKey: .logs)
        try c.encodeIfPresent(widgetData, forKey: .widgetData)
        try c.encodeIfPresent(weeklyProgress, forKey: .weeklyProgress)
    }
}

// MARK: - Connectivity Service

/// Manages Watch ↔ iPhone communication.
///
/// The class is `@MainActor` so that `@Published` properties can be observed
/// directly by SwiftUI views. All `WCSessionDelegate` callbacks are `nonisolated`
/// and hop back to the main actor for any state mutations.
@MainActor
final class ClarityWatchConnectivity: NSObject, ObservableObject {

    static let shared = ClarityWatchConnectivity()

    // MARK: Published State

    @Published private(set) var lastSnapshot: WatchUserInfo = .init(
        tasks: [],
        progress: .init(completed: 0, target: 0, error: nil, categories: [])
    )

    #if os(watchOS)
    @Published var activePomodoro: PomodoroDTO?
    func dismissPomodoro() { activePomodoro = nil }
    #endif

    // MARK: Private

    private let session = WCSession.default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    /// Debounce task for `pushSnapshot` to coalesce rapid calls.
    private var snapshotDebounceTask: Task<Void, Never>?

    /// Hash of the last data sent via `transferCurrentComplicationUserInfo`.
    private var lastComplicationHash: Int = 0

    private override init() {
        super.init()
    }

    // MARK: - Setup

    func start() {
        guard WCSession.isSupported() else { return }
        session.delegate = self
        session.activate()
        LogManager.shared.log.verbose("⌚️ WCSession activating")
    }

    // MARK: - iOS → Watch: Snapshot Push

    /// Pushes the current task/progress snapshot to the watch, debounced 500 ms.
    func pushSnapshot() {
        snapshotDebounceTask?.cancel()
        snapshotDebounceTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled, let self else { return }
            self._sendSnapshot()
        }
    }

    @MainActor
    private func _sendSnapshot() {
        guard session.activationState == .activated else { return }
        do {
            let data = try WidgetFileCoordinator.shared.compressedSnapshot()
            try session.updateApplicationContext([WCKeys.payload: data])
            #if os(iOS)
            guard session.isPaired, session.isWatchAppInstalled else { return }
            if session.isComplicationEnabled {
                let hash = data.hashValue
                guard hash != lastComplicationHash else { return }
                lastComplicationHash = hash
                session.transferCurrentComplicationUserInfo([WCKeys.Requests.widgetSnapshot: data])
            } else {
                session.transferUserInfo([WCKeys.Requests.widgetSnapshot: data])
            }
            #endif
        } catch {
            LogManager.shared.log.error("❌ pushSnapshot failed: \(error)")
        }
    }

    // MARK: - Watch → iPhone: Commands

    /// Sends a task-complete command. Uses immediate path when reachable, reliable fallback otherwise.
    func sendComplete(todotaskid: String) {
        sendReliable(Envelope(kind: WCKeys.Requests.complete, todotaskid: todotaskid))
    }

    /// Sends a pomodoro-start command.
    func sendPomodoroStart(todotaskid: String) {
        sendReliable(Envelope(kind: WCKeys.Requests.startPomodoro, todotaskid: todotaskid))
    }

    /// Sends log data to the phone.
    func sendLogs(_ data: Data) {
        sendReliable(Envelope(kind: WCKeys.Requests.sendLogs, logs: data))
    }

    /// Notifies the watch that a pomodoro has started (iOS → watch).
    func sendPomodoroStarted(_ dto: PomodoroDTO) {
        sendReliable(Envelope(kind: WCKeys.Requests.pomodoroStarted, pomodoro: dto))
    }

    /// Notifies the watch that the current pomodoro has stopped (iOS → watch).
    func sendPomodoroStopped(_ task: ToDoTaskDTO? = nil) {
        sendReliable(Envelope(kind: WCKeys.Requests.pomodoroStopped, todo: task))
    }

    // MARK: - Watch: Request Fresh List

    /// Requests the full task list from the phone.
    /// Calls `completion` with the latest snapshot (either live or cached).
    func requestListAll(preferReliable: Bool = false, completion: @escaping (Result<WatchUserInfo, Error>) -> Void) {
        guard session.activationState == .activated else {
            sendReliable(Envelope(kind: WCKeys.Requests.listAll))
            completion(.success(lastSnapshot))
            return
        }

        if !preferReliable, session.isReachable {
            let msg: [String: Any] = [WCKeys.request: WCKeys.Requests.listAll]
            session.sendMessage(msg, replyHandler: { [weak self] reply in
                guard let self else { return }
                Task { @MainActor in
                    if let data = reply[WCKeys.payload] as? Data,
                       let env = try? self.decoder.decode(Envelope.self, from: data),
                       let todos = env.todos {
                        self.lastSnapshot.tasks = todos
                    }
                    completion(.success(self.lastSnapshot))
                }
            }, errorHandler: { [weak self] _ in
                guard let self else { return }
                Task { @MainActor in
                    self.sendReliable(Envelope(kind: WCKeys.Requests.listAll))
                    completion(.success(self.lastSnapshot))
                }
            })
        } else {
            sendReliable(Envelope(kind: WCKeys.Requests.listAll))
            completion(.success(lastSnapshot))
        }
    }

    // MARK: - Helpers

    private func sendReliable(_ envelope: Envelope) {
        guard session.activationState == .activated,
              let data = try? encoder.encode(envelope) else { return }
        session.transferUserInfo([WCKeys.payload: data])
    }
}

// MARK: - WCSessionDelegate

extension ClarityWatchConnectivity: WCSessionDelegate {

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: (any Error)?
    ) {
        LogManager.shared.log.verbose("⌚️ activationDidCompleteWith state=\(activationState.rawValue)")
        #if os(watchOS)
        guard activationState == .activated else { return }
        Task { @MainActor [weak self] in
            self?.requestListAll { _ in }
        }
        #endif
    }

    #if os(iOS)
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        LogManager.shared.log.verbose("⌚️ watchStateDidChange isPaired=\(session.isPaired)")
    }
    #endif

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        guard session.isReachable else { return }
        Task { @MainActor [weak self] in
            self?.requestListAll { _ in }
        }
    }

    /// Handles immediate messages (reachable path).
    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        let envelope = (message[WCKeys.payload] as? Data)
            .flatMap { try? JSONDecoder().decode(Envelope.self, from: $0) }

        // replyHandler is a non-Sendable Obj-C closure; nonisolated(unsafe) is the accepted
        // workaround for bridging legacy callbacks that are safe to call from any thread.
        nonisolated(unsafe) let sendableReply = replyHandler

        Task { @MainActor [weak self] in
            guard let self, let envelope else { sendableReply([:]); return }
            let response = await self.process(envelope: envelope)
            if let data = try? self.encoder.encode(response) {
                sendableReply([WCKeys.payload: data])
            } else {
                sendableReply([:])
            }
        }
    }

    /// Handles reliable background transfers.
    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        // Extract Data values before crossing into MainActor — [String: Any] is not Sendable.
        #if os(watchOS)
        let snapshotData = userInfo[WCKeys.Requests.widgetSnapshot] as? Data
        #endif
        let payloadData = userInfo[WCKeys.payload] as? Data

        Task { @MainActor [weak self] in
            guard let self else { return }

            #if os(watchOS)
            if let data = snapshotData {
                do {
                    let snapshot = try WidgetFileCoordinator.shared.decodeCompressedSnapshot(data)
                    try WidgetFileCoordinator.shared.writeTasks(snapshot.tasks)
                    try WidgetFileCoordinator.shared.writeWeeklyProgress(snapshot.progress)
                    self.lastSnapshot = snapshot
                } catch {
                    LogManager.shared.log.error("❌ Failed to apply widgetSnapshot: \(error)")
                }
                return
            }
            #endif

            guard let data = payloadData,
                  let envelope = try? self.decoder.decode(Envelope.self, from: data) else { return }
            _ = await self.process(envelope: envelope)
        }
    }

    /// Handles application context updates (sent via `updateApplicationContext`).
    nonisolated func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        guard let data = applicationContext[WCKeys.payload] as? Data else { return }
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let snapshot = try WidgetFileCoordinator.shared.decodeCompressedSnapshot(data)
                self.lastSnapshot = snapshot
                #if os(watchOS)
                try WidgetFileCoordinator.shared.writeTasks(snapshot.tasks)
                try WidgetFileCoordinator.shared.writeWeeklyProgress(snapshot.progress)
                #endif
            } catch {
                LogManager.shared.log.error("❌ Failed to apply applicationContext: \(error)")
            }
        }
    }
}

// MARK: - Message Processing

extension ClarityWatchConnectivity {

    /// Decodes an envelope from a raw message dict and dispatches it.
    @MainActor
    private func process(message: [String: Any]) async -> Envelope {
        guard let data = message[WCKeys.payload] as? Data,
              let envelope = try? decoder.decode(Envelope.self, from: data) else {
            return Envelope(kind: "error")
        }
        return await process(envelope: envelope)
    }

    /// Dispatches a decoded envelope to the appropriate platform handler.
    @MainActor
    private func process(envelope: Envelope) async -> Envelope {
        #if os(iOS)
        return await processiOS(envelope)
        #elseif os(watchOS)
        return processWatchOS(envelope)
        #else
        return Envelope(kind: "error")
        #endif
    }

    // MARK: iOS Handlers

    #if os(iOS)
    @MainActor
    private func processiOS(_ envelope: Envelope) async -> Envelope {
        switch envelope.kind {

        case WCKeys.Requests.listAll:
            pushSnapshot()
            let tasks = (try? WidgetFileCoordinator.shared.readTasks()) ?? []
            return Envelope(kind: WCKeys.Requests.listAll, todos: tasks)

        case WCKeys.Requests.complete:
            if let idString = envelope.todotaskid, let uuid = UUID(uuidString: idString) {
                do {
                    try await ClarityServices.store().completeTask(uuid)
                } catch {
                    LogManager.shared.log.error("⌚️ complete task failed: \(error)")
                }
                pushSnapshot()
            }
            return Envelope(kind: WCKeys.Requests.complete)

        case WCKeys.Requests.startPomodoro:
            if let idString = envelope.todotaskid, let uuid = UUID(uuidString: idString) {
                // Write pending key so the app picks it up when it foregrounds.
                let defaults = UserDefaults(suiteName: "group.me.craigpeters.clarity")
                defaults?.set(uuid.uuidString, forKey: "pendingStartTimerTaskId")
                // Attempt inline start if the app is already active.
                if let dto = try? WidgetFileCoordinator.shared.readTaskByUuid(uuid) {
                    do {
                        let store = try await ClarityServices.store()
                        PomodoroService.shared.startPomodoro(for: dto, container: store.modelContainer, device: .watchOS)
                        defaults?.removeObject(forKey: "pendingStartTimerTaskId")
                    } catch {
                        LogManager.shared.log.error("⌚️ inline pomodoro start failed: \(error)")
                    }
                }
            }
            return Envelope(kind: WCKeys.Requests.startPomodoro)

        case WCKeys.Requests.sendLogs:
            if let logData = envelope.logs {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd_HHmmss"
                let filename = "watch_logs_\(formatter.string(from: Date())).log"
                try? WidgetFileCoordinator.shared.writeLogFile(fileName: filename, data: logData)
            }
            return Envelope(kind: WCKeys.Requests.sendLogs)

        default:
            LogManager.shared.log.verbose("⌚️ iOS: unhandled kind=\(envelope.kind)")
            return Envelope(kind: "error")
        }
    }
    #endif

    // MARK: watchOS Handlers

    #if os(watchOS)
    @MainActor
    private func processWatchOS(_ envelope: Envelope) -> Envelope {
        switch envelope.kind {

        case WCKeys.Requests.pomodoroStarted:
            if let dto = envelope.pomodoro {
                // Ignore already-expired pomodoros to avoid flashing the sheet on launch.
                if let end = dto.endTime, end <= Date() { break }
                activePomodoro = dto
            }
            return Envelope(kind: WCKeys.Requests.pomodoroStarted)

        case WCKeys.Requests.pomodoroStopped:
            activePomodoro = nil
            requestListAll { _ in }
            return Envelope(kind: WCKeys.Requests.pomodoroStopped)

        case WCKeys.Requests.weeklyProgress:
            if let progress = envelope.weeklyProgress {
                try? WidgetFileCoordinator.shared.writeWeeklyProgress(progress)
                lastSnapshot.progress = progress
            }
            return Envelope(kind: WCKeys.Requests.weeklyProgress)

        default:
            LogManager.shared.log.verbose("⌚️ watchOS: unhandled kind=\(envelope.kind)")
            return Envelope(kind: "error")
        }

        return Envelope(kind: envelope.kind)
    }
    #endif
}


//
//  WatchConnectivity.swift
//  Clarity
//
//  Created by Craig Peters on 29/09/2025.
//

import Foundation
import WatchConnectivity
import Combine
import SwiftData
import os
import XCGLogger

@MainActor
final class ClarityWatchConnectivity: NSObject, @MainActor WCSessionDelegate, ObservableObject {
    static let shared = ClarityWatchConnectivity()
    private let session = WCSession.default
    private let jsonEncoder = JSONEncoder()
    private let jsonDecoder = JSONDecoder()

    @Published private(set) var lastSnapshot: [ToDoTaskDTO] = []
    #if os(watchOS)
    @Published var activePomodoro: PomodoroDTO?
    func dismissPomodoro() { activePomodoro = nil }
    #endif

    func start() {
        guard WCSession.isSupported() else { return }
        session.delegate = self
        #if os(iOS)
        LogManager.shared.log.verbose("[iOS] ⌚️ Creating Watch Session")
        #elseif os(watchOS)
        LogManager.shared.log.verbose("[watchOS] ⌚️ Creating Watch Session")
        #else
        LogManager.shared.log.verbose("⌚️ Creating Watch Session")
        #endif
        session.activate()
        #if os(iOS)
        // Initial state diagnostics for iOS
        LogManager.shared.log.verbose("[iOS] ⌚️ isPaired=\(self.session.isPaired) isWatchAppInstalled=\(self.session.isWatchAppInstalled) isReachable=\(self.session.isReachable)")
        #endif
    }

    // MARK: - Requests (phone<->watch both implement these)

    func requestListAll(preferReliable: Bool = false, reply: @escaping (Result<[ToDoTaskDTO], Error>) -> Void) {
        LogManager.shared.log.verbose("⌚️ Requesting Watch Data (preferReliable=\(preferReliable))")
        let msg: [String: Any] = [WCKeys.request: WCKeys.Requests.listAll]

        // If session isn't activated, just queue reliable and return snapshot
        guard self.session.activationState == .activated else {
            LogManager.shared.log.verbose("⌚️ Session not activated; queue reliable listAll and return snapshot")
            self.enqueueRequest(.init(kind: WCKeys.Requests.listAll))
            reply(.success(self.lastSnapshot))
            return
        }

        // Caller prefers reliable, but we'll still attempt immediate when reachable and fall back to reliable
        if preferReliable {
            LogManager.shared.log.verbose("⌚️ preferReliable=true but reachable path will be attempted; will fall back to reliable on timeout/failure")
        }

        // Reachable path with extended timeout and reliable fallback
        if self.session.isReachable {
            // Setup a timeout work item to fall back to reliable
            let timeoutSeconds: TimeInterval = 6.0
            var completed = false
            let timeout = DispatchWorkItem { [weak self] in
                guard let self = self, !completed else { return }
                completed = true
                LogManager.shared.log.verbose("⌚️ Immediate listAll timed out after \(timeoutSeconds)s → queue reliable and return snapshot")
                self.enqueueRequest(.init(kind: WCKeys.Requests.listAll))
                reply(.success(self.lastSnapshot))
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + timeoutSeconds, execute: timeout)

            self.session.sendMessage(msg, replyHandler: { dict in
                guard !completed else { return }
                do {
                    if let data = dict[WCKeys.payload] as? Data {
                        let env = try self.jsonDecoder.decode(Envelope.self, from: data)
                        completed = true
                        timeout.cancel()
                        // Also push snapshot so counterpart stays in sync
                        if let todos = env.todos {
                            self.pushSnapshot(todos)
                        }
                        reply(.success(env.todos ?? []))
                    } else {
                        completed = true
                        timeout.cancel()
                        LogManager.shared.log.verbose("⚠️ Immediate listAll missing payload; queue reliable and return snapshot")
                        self.enqueueRequest(.init(kind: WCKeys.Requests.listAll))
                        reply(.success(self.lastSnapshot))
                    }
                } catch {
                    // If decode fails, queue reliable request and fall back to snapshot
                    completed = true
                    timeout.cancel()
                    self.enqueueRequest(.init(kind: WCKeys.Requests.listAll))
                    LogManager.shared.log.verbose("⚠️ Immediate listAll decode failed, queued reliable fallback: \(error)")
                    reply(.success(self.lastSnapshot))
                }
            }, errorHandler: { error in
                guard !completed else { return }
                completed = true
                timeout.cancel()
                // If immediate message fails, queue a reliable request and fall back to snapshot
                self.enqueueRequest(.init(kind: WCKeys.Requests.listAll))
                LogManager.shared.log.verbose("⌚️ sendMessage failed, queued listAll via transferUserInfo: \(error)")
                reply(.success(self.lastSnapshot))
            })
        } else {
            LogManager.shared.log.verbose("⌚️ Session not reachable; queue reliable listAll and return snapshot")
            // Queue a reliable request so counterpart can respond later
            self.enqueueRequest(.init(kind: WCKeys.Requests.listAll))
            // Fallback to cached snapshot
            reply(.success(self.lastSnapshot))
        }
    }

    /// Try to send immediately if reachable; fall back to reliable transfer if not or on failure.
    private func sendImmediateOrReliable(_ env: Envelope) {
        guard self.session.activationState == .activated else {
            LogManager.shared.log.verbose("⌚️ sendImmediateOrReliable aborted: session not activated; falling back to queue")
            self.enqueueRequest(env)
            return
        }
        guard let data = try? self.jsonEncoder.encode(env) else {
            LogManager.shared.log.verbose("⌚️ sendImmediateOrReliable aborted: encode failed for \(env.kind)")
            return
        }

        let message: [String: Any] = [WCKeys.request: env.kind, WCKeys.payload: data]

        if self.session.isReachable {
            LogManager.shared.log.verbose("⌚️ Attempting immediate send(kind:\(env.kind)) …")
            self.session.sendMessage(message, replyHandler: { reply in
                #if DEBUG
                if JSONSerialization.isValidJSONObject(reply),
                   let data = try? JSONSerialization.data(withJSONObject: reply, options: [.prettyPrinted]),
                   let json = String(data: data, encoding: .utf8) {
                    LogManager.shared.log.verbose("📬 Immediate reply for \(env.kind):\n\(json)")
                } else {
                    LogManager.shared.log.verbose("📬 Immediate reply for \(env.kind): \(reply)")
                }
                #endif
            }, errorHandler: { error in
                LogManager.shared.log.verbose("⚠️ Immediate send(kind:\(env.kind)) failed → falling back to reliable: \(error)")
                self.session.transferUserInfo([WCKeys.payload: data])
            })
        } else {
            LogManager.shared.log.verbose("⌚️ Not reachable; queueing reliable transfer(kind:\(env.kind))")
            self.session.transferUserInfo([WCKeys.payload: data])
        }
    }

    func sendCreate(_ dto: ToDoTaskDTO) {
        self.sendImmediateOrReliable(.init(kind: WCKeys.Requests.create, todo: dto))
    }
    
    func sendLogs(_ data: Data) {
        LogManager.shared.log.debug("Sending Watch Log Data")
        self.sendImmediateOrReliable(.init(kind: WCKeys.Requests.sendLogs, logs: data))
    }

    func sendComplete(todotaskid: String) {
        LogManager.shared.log.verbose("Complete Toggled with ID")
        self.sendImmediateOrReliable(.init(kind: WCKeys.Requests.complete, todotaskid: todotaskid))
    }
    
    func sendPomodoroStart(todotaskid: String) {
        self.sendImmediateOrReliable(.init(kind: WCKeys.Requests.startPomodoro, todotaskid: todotaskid))
    }
    
    func sendPomodoroStopped(_ dto: ToDoTaskDTO? = nil) async {
        guard let task = dto else {
            self.sendImmediateOrReliable(.init(kind: WCKeys.Requests.pomodoroStopped))
            return
        }
        LogManager.shared.log.info("Stopping Pomodoro for \(task.name) - Completing Task")
        let uuid = task.uuid
        try? await ClarityServices.store().completeTask(uuid)
        
        self.sendImmediateOrReliable(.init(kind: WCKeys.Requests.pomodoroStopped))
    }
    
    func sendPomodoroStarted(_ dto: PomodoroDTO) {
        self.sendImmediateOrReliable(.init(kind: WCKeys.Requests.pomodoroStarted, pomodoro: dto))
    }
    
    // Watch to Phone to stop the Pomodoro
    func sendPomodoroStop(pomodoro: PomodoroDTO) {
        self.sendImmediateOrReliable(.init(kind: WCKeys.Requests.stopPomodoro, pomodoro: pomodoro))
    }

    func sendDelete(id: String) {
        self.sendImmediateOrReliable(.init(kind: WCKeys.Requests.delete, todotaskid: id))
    }

    /// Sends a reliable ping over transferUserInfo to test the background/reliable channel.
    /// Use this when `isReachable` is false or to validate delivery while the counterpart is suspended.
    func sendReliablePing() {
        let env = Envelope(kind: "ping")
        self.enqueueRequest(env)
    }

    func pushSnapshot(_ todos: [ToDoTaskDTO]) {
        guard self.session.activationState == .activated else { return }
        DispatchQueue.main.async { self.lastSnapshot = todos }
        if let data = try? self.jsonEncoder.encode(Envelope(kind: "snapshot", todos: todos)) {
            do {
                try self.session.updateApplicationContext([WCKeys.payload: data])
            } catch {
                LogManager.shared.log.error("❌ Failed to update application context: \(error)")
            }
        }
    }

    private func enqueueRequest(_ env: Envelope) {
        guard self.session.activationState == .activated else {
            LogManager.shared.log.error("⌚️ enqueueRequest aborted: session not activated"); return
        }
        guard let data = try? self.jsonEncoder.encode(env) else {
            LogManager.shared.log.error("⌚️ enqueueRequest aborted: encode failed for \(env.kind)"); return
        }
        LogManager.shared.log.verbose("⌚️ enqueue transferUserInfo(kind:\(env.kind)) queued; reachable=\(self.session.isReachable)")
        self.session.transferUserInfo([WCKeys.payload: data])
    }

    private func sendReliable(_ env: Envelope) {
        guard self.session.activationState == .activated else {
            LogManager.shared.log.error("⌚️ sendReliable aborted: session not activated"); return
        }
        guard let data = try? self.jsonEncoder.encode(env) else {
            LogManager.shared.log.error("⌚️ sendReliable aborted: encode failed for \(env.kind)"); return
        }
        LogManager.shared.log.verbose("⌚️ outstanding transfers (pre-queue): \(self.session.outstandingUserInfoTransfers.count)")
        #if DEBUG
        if let jsonString = String(data: data, encoding: .utf8) {
            LogManager.shared.log.verbose("📮 sendReliable payload JSON:\n\(jsonString)")
        }
        #endif
        LogManager.shared.log.verbose("⌚️ transferUserInfo(kind:\(env.kind)) queued; reachable=\(self.session.isReachable)")
        self.session.transferUserInfo([WCKeys.payload: data])
        LogManager.shared.log.verbose("⌚️ outstanding transfers (post-queue): \(self.session.outstandingUserInfoTransfers.count)")
        LogManager.shared.log.verbose("⌚️ outstanding transfers: \(self.session.outstandingUserInfoTransfers.count)")
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            LogManager.shared.log.verbose("⌚️ outstanding transfers (5s later): \(self.session.outstandingUserInfoTransfers.count)")
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 15) {
            LogManager.shared.log.verbose("⌚️ outstanding transfers (15s later): \(self.session.outstandingUserInfoTransfers.count)")
        }
    }


    // MARK: - WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        LogManager.shared.log.verbose("⌚️ activationDidCompleteWith state=\(activationState.rawValue) error=\(String(describing: error))")
        #if os(watchOS)
        // When the watch session activates, immediately request the latest tasks
        if activationState == .activated {
            self.requestListAll(preferReliable: false) { result in
                switch result {
                case .success(let todos):
                    DispatchQueue.main.async {
                        LogManager.shared.log.verbose("⌚️ Watch pulled \(todos.count) tasks after activation")
                        self.lastSnapshot = todos
                    }
                case .failure(let err):
                    LogManager.shared.log.verbose("⚠️ listAll after activation failed: \(err)")
                }
            }
        }
        #endif
    }

    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
//        Task { @MainActor in
//            ClarityWatchConnectivity.shared.pushSnapshot(ClarityWatchConnectivity.getAllTasks())
//        }
    }
    
    func sessionWatchStateDidChange(_ session: WCSession) {
        // This fires when pairing status, installed state, or complication enabled changes
        LogManager.shared.log.verbose("[iOS] ⌚️ sessionWatchStateDidChange → isPaired=\(session.isPaired) isWatchAppInstalled=\(session.isWatchAppInstalled) isComplicationEnabled=\(session.isComplicationEnabled)")
        LogManager.shared.log.verbose("[iOS] ⌚️ reachable=\(session.isReachable) activationState=\(session.activationState.rawValue)")
    }
    #endif

    // Incoming immediate request
    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        
        Task { @MainActor in
            #if DEBUG
            if JSONSerialization.isValidJSONObject(message),
               let data = try? JSONSerialization.data(withJSONObject: message, options: [.prettyPrinted]),
               let jsonString = String(data: data, encoding: .utf8) {
                LogManager.shared.log.verbose("📥 didReceiveMessage full JSON:\n\(jsonString)")
            } else {
                LogManager.shared.log.verbose("📥 didReceiveMessage raw message: \(message)")
            }
            #endif
            
            let kind = message[WCKeys.request] as? String
            let result = await Self.process(kind: kind, message: message)
            let data = try? self.jsonEncoder.encode(result)
            replyHandler([WCKeys.payload: data as Any])
        }
    }

    // Incoming reliable events
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        LogManager.shared.log.verbose("📨 iOS received userInfo raw keys: \(Array(userInfo.keys))")
        if let payloadData = userInfo[WCKeys.payload] as? Data {
            LogManager.shared.log.verbose("📦 userInfo payload bytes: \(payloadData.count)")
            if let env = try? self.jsonDecoder.decode(Envelope.self, from: payloadData),
               let pretty = try? JSONEncoder().encode(env),
               let json = String(data: pretty, encoding: .utf8) {
                LogManager.shared.log.verbose("📦 userInfo decoded Envelope JSON:\n\(json)")
            }
        }
        guard let data = userInfo[WCKeys.payload] as? Data else {
            LogManager.shared.log.error("❌ iOS userInfo missing payload under key \(WCKeys.payload)")
            return
        }
        guard let env = try? self.jsonDecoder.decode(Envelope.self, from: data) else {
            LogManager.shared.log.error("❌ iOS failed to decode Envelope from userInfo (\(data.count) bytes)")
            return
        }
        LogManager.shared.log.verbose("📨 …. kind=\(env.kind)")
        Task {
            await Self.applyEvent(env)
            LogManager.shared.log.verbose("✅ iOS applied event kind=\(env.kind)")
        } // implemented per-platform
    }

    // Snapshot push from counterpart
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        guard let data = applicationContext[WCKeys.payload] as? Data,
              let env = try? self.jsonDecoder.decode(Envelope.self, from: data),
              let todos = env.todos else { return }
        DispatchQueue.main.async { self.lastSnapshot = todos }
    }
}
// MARK: Processing Responses
extension ClarityWatchConnectivity {
    static func process(kind: String?, message: [String: Any]?) async -> Envelope {
        guard let kind else { return .init(kind: "error") }
        #if DEBUG
        LogManager.shared.log.verbose("🧭 process received kind=\(kind)")
        #endif
        #if os(iOS)
        switch kind {
        case WCKeys.Requests.listAll:
            return await processWatchListAllRequest(message)
        case WCKeys.Requests.create: // Not Implimented
            return Envelope(kind: WCKeys.Requests.complete)
        case WCKeys.Requests.delete: // Not Implimented
            return Envelope(kind:WCKeys.Requests.delete)
        case WCKeys.Requests.complete:
            return await processWatchCompleteRequest(message)
        case WCKeys.Requests.startPomodoro:
            // Pomodoro Started on Watch
            return await ProcessWatchPomodoroStart(message)
        case WCKeys.Requests.stopPomodoro:
            // Pomodoro Stopped on Watch
            return await ProcessWatchPomodoroStop(message)
        case WCKeys.Requests.pomodoroStopped:
            return await ProcessWatchPomodoroStopped(message)
        case WCKeys.Requests.sendLogs:
            return await ProcessSendLogs(message)
        case WCKeys.Requests.widgetData:
            return await ProcessSendWWatchWidgetData(message)
        default:
            LogManager.shared.log.error("Invalid Request Type: \(kind)")
            return Envelope(kind: "error")
        }
        
        #endif
        #if os(watchOS)
        switch kind {
        case WCKeys.Requests.pomodoroStarted:
            return await ProcessPhonePomodoroStarted(message)
        case WCKeys.Requests.pomodoroStopped:
            return await ProcessPhonePomodoroStopped(message)
        default:
            LogManager.shared.log.verbose("Not proessing request type on watch: \(kind)")
            return Envelope(kind: "error")
        }
        #endif

    }

    static func applyEvent(_ env: Envelope) async {
        // Wrap the Envelope into a message-like dictionary so we can reuse process(kind:message:)
        var message: [String: Any] = [WCKeys.request: env.kind]
        if let data = try? JSONEncoder().encode(env) {
            message[WCKeys.payload] = data
        }
        _ = await process(kind: env.kind, message: message)
    }
    
    // MARK: iOS Process Functions
    #if os(iOS)
    
    
    
    private static func getAllTasks() -> [ToDoTaskDTO] {
        //TODO: Need to add a filter at some point, until then getting all
        var todos: [ToDoTaskDTO] = []
        do {
            todos = try WidgetFileCoordinator.shared.readTasks()
            todos = ToDoTaskDTO.focusFilter(in: todos)
        } catch {
            LogManager.shared.log.error("📱 Could not fetch tasks from WidgetFileCoordinator \(error.localizedDescription)")
        }
        return todos
    }
    
    private static func ProcessSendWWatchWidgetData(_ message: [String: Any]?) async -> Envelope {
        
        let data = WatchWidgetData(due: 1, completed: 2, progress: 1, target: 3)
        return Envelope(kind: WCKeys.Requests.widgetData, data: data)
    }
    
    private static func processWatchListAllRequest(_ message: [String: Any]?) async -> Envelope {
        let todos = getAllTasks()
        ClarityWatchConnectivity.shared.pushSnapshot(todos)
        return Envelope(kind: WCKeys.Requests.listAll, todos: todos)
    }
    
    private static func processWatchCompleteRequest(_ message: [String:Any]?) async -> Envelope {
        if let uuid = decodeMessagetoUUID(message) {
            do {
                try await ClarityServices.store().completeTask(uuid)
            } catch {
                LogManager.shared.log.error("Could not complete task \(error.localizedDescription)")
            }
        } else {
            LogManager.shared.log.error("Could not decode message to UUID. Failed to complete Task")
        }
        let todos = getAllTasks()
        ClarityWatchConnectivity.shared.pushSnapshot(todos)
        
        return Envelope(kind: WCKeys.Requests.complete)
    }
    
    private static func ProcessWatchPomodoroStart(_ message: [String:Any]?) async -> Envelope {
        // Get the Task ID
        // TODO: Change Watch to send DTO
        if let uuid = decodeMessagetoUUID(message) {
            do {
                guard let dto = try? WidgetFileCoordinator.shared.readTaskByUuid(uuid) else {
                //guard let dto = try? await ClarityServices.store().fetchTaskById(id) else {
                    LogManager.shared.log.error("Task Not Found")
                    return Envelope(kind: WCKeys.Requests.startPomodoro)
                }
                try await PomodoroService.shared.startPomodoro(for: dto, container: ClarityServices.store().modelContainer, device: .watchOS)
            } catch {
                LogManager.shared.log.error("📱 Failed to start Pomodoro: \(error) ")
            }
        }
        return Envelope(kind: WCKeys.Requests.startPomodoro)
    }
    
    private static func ProcessWatchPomodoroStop(_ message: [String:Any]?) async -> Envelope {
        guard let dto = decodeMessageToPomodoro(message) else {
            LogManager.shared.log.error("Error in decoding Pomodoro from message")
            return Envelope(kind: WCKeys.Requests.stopPomodoro)
        }
        LogManager.shared.log.info("Recieved End Pomodoro for Task \(dto.toDoTask.name) ending Pomodoro and Completing Task")
        //TODO: Replace with intent
        await PomodoroService.shared.endPomodoro()
        let uuid = dto.toDoTask.uuid
        do {
            try await ClarityServices.store().completeTask(uuid)
        } catch {
            LogManager.shared.log.error("Error in completing task \(dto.toDoTask.name) error: \(error)")
        }
        ClarityWatchConnectivity.shared.pushSnapshot(getAllTasks())
        return Envelope(kind: WCKeys.Requests.stopPomodoro)
    }
    
    private static func ProcessWatchPomodoroStopped(_ message: [String:Any]?) async -> Envelope {
        // If a ToDoTaskDTO is provided, attempt to complete the task on iOS
        guard let dto = decodeMessageToToDoTask(message) else {
            LogManager.shared.log.error("Error in decoding ToDoTask from message")
            return Envelope(kind: WCKeys.Requests.pomodoroStopped)
        }
        LogManager.shared.log.info("Recieved A Stopped Pomodoro for Task \(dto.name)")
        
        let uuid = dto.uuid
            do {
                try await ClarityServices.store().completeTask(uuid)
            } catch {
                LogManager.shared.log.error("Error Completing Task \(dto.name) error: \(error)")
            }
        return Envelope(kind: WCKeys.Requests.pomodoroStopped)
    }
    
    private static func ProcessSendLogs(_ message: [String:Any]?) async -> Envelope {
        
        guard let data = decodeMessageToData(message) else {
            LogManager.shared.log.error("Error in decoding Data from message")
            return Envelope(kind: WCKeys.Requests.sendLogs)
        }
    
        LogManager.shared.log.debug("Recieved a watch log")
        LogManager.shared.log.debug("Log File: \(String(describing: String(data: data, encoding: .utf8)))")
        guard let containerUrl = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.me.craigpeters.clarity") else {
            LogManager.shared.log.error("Could not create container for watch log files")
            return Envelope(kind: WCKeys.Requests.sendLogs)
        }
        let watchLogPath = containerUrl.appendingPathComponent("watch_logs.log")
        do {
            try data.write(to: watchLogPath, options: .atomic)
            LogManager.shared.log.info("Written Watch log to \(watchLogPath)")
        } catch {
            LogManager.shared.log.error("Could not write Watch Logs: \(error.localizedDescription)")
        }
        
        return Envelope(kind: WCKeys.Requests.sendLogs)
    }
    
    #endif
    
    // MARK: WatchOS Process Functions
    #if os(watchOS)
    
    private static func ProcessPhonePomodoroStarted(_ message: [String:Any]?) async -> Envelope {
        guard let dto = decodeMessageToPomodoro(message) else {
            LogManager.shared.log.verbose("Cannot decode DTO")
            return Envelope(kind: WCKeys.Requests.pomodoroStarted)
        }
        ClarityWatchConnectivity.shared.activePomodoro = dto
        LogManager.shared.log.verbose("⌚️ Received pomodoroStarted with DTO for task: \(dto.toDoTask.name)")
        return Envelope(kind: WCKeys.Requests.pomodoroStarted)
    }
    
    private static func ProcessPhonePomodoroStopped(_ message: [String:Any]?) async -> Envelope {
        LogManager.shared.log.verbose("⌚️ Dismissing Pomodoro")
        ClarityWatchConnectivity.shared.activePomodoro = nil
        
        // After stopping, request a fresh snapshot from the phone
        ClarityWatchConnectivity.shared.requestListAll(preferReliable: false) { result in
            switch result {
            case .success(let todos):
                DispatchQueue.main.async {
                    LogManager.shared.log.verbose("⌚️ Watch requested snapshot after pomodoroStopped: \(todos.count) tasks")
                    ClarityWatchConnectivity.shared.lastSnapshot = todos
                }
            case .failure(let error):
                LogManager.shared.log.verbose("⚠️ Watch failed to request snapshot after pomodoroStopped: \(error)")
            }
        }
        return Envelope(kind: WCKeys.Requests.pomodoroStopped)
    }
    
    #endif
    
    // MARK: Helper Functions
    
    private static func decodeMessageToData(_ message: [String:Any]?) -> Data? {
        var encodedData: Data?
        if let msg = message, let data = msg[WCKeys.payload] as? Data,
           let env = try? JSONDecoder().decode(Envelope.self, from: data) {
            encodedData = env.logs
        }
        return encodedData
    }
    
    private static func decodeMessageToToDoTask(_ message: [String:Any]?) -> ToDoTaskDTO? {
        var encodedDto: ToDoTaskDTO?
        if let msg = message, let data = msg[WCKeys.payload] as? Data,
           let env = try? JSONDecoder().decode(Envelope.self, from: data) {
            encodedDto = env.todo
        }
        return encodedDto
    }
    
    private static func decodeMessagetoUUID(_ message: [String:Any]?) -> UUID? {
        var encodedUuid: UUID?
        if let msg = message, let data = msg[WCKeys.payload] as? Data,
           let env = try? JSONDecoder().decode(Envelope.self, from: data) {
            encodedUuid = UUID(uuidString: env.todotaskid!)
        }
        return encodedUuid
    }
    
    private static func decodeMessageToPomodoro(_ message: [String:Any]?) -> PomodoroDTO? {
        
        // get PomodoroDTO
        var encodedDto: PomodoroDTO?
        if let msg = message, let data = msg[WCKeys.payload] as? Data,
           let env = try? JSONDecoder().decode(Envelope.self, from: data) {
            encodedDto = env.pomodoro
        }
        return encodedDto
    }
    
}

public enum WCKeys {
    public static let request = "request"
    public static let payload = "payload"
    
    public enum Requests {
        public static let listAll = "listAll"
        public static let complete  = "complete"
        public static let create  = "create"
        public static let delete  = "delete"
        public static let startPomodoro = "startPomodoro"
        public static let stopPomodoro = "stopPomodoro"
        public static let pomodoroStarted = "pomodoroStarted"
        public static let pomodoroStopped = "pomodoroStopped"
        public static let sendLogs = "sendLogs"
        public static let widgetData = "widgetData"
    }
}

public struct PomodoroDTO: Codable, Sendable {
    var startTime: Date?
    var endTime: Date?
    var toDoTask: ToDoTaskDTO
}

public struct Envelope: Codable, Sendable {
    public let kind: String
    public let todos: [ToDoTaskDTO]?       // for list/snapshot
    public let todo: ToDoTaskDTO?          // for single op
    public let todotaskid: String?
    public let pomodoro: PomodoroDTO?
    public let logs: Data?
    public let widgetData: WatchWidgetData?

    public init(kind: String, todos: [ToDoTaskDTO]? = nil, todo: ToDoTaskDTO? = nil, todotaskid : String? = nil, pomodoro: PomodoroDTO? = nil, logs: Data? = nil, data: WatchWidgetData? = nil) {
        self.kind = kind
        self.todos = todos
        self.todo = todo
        self.todotaskid = todotaskid
        self.pomodoro = pomodoro
        self.logs = logs
        self.widgetData = data
    }
}


extension ClarityWatchConnectivity {
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        LogManager.shared.log.verbose("⌚️ Reachability changed → \(session.isReachable)")
        LogManager.shared.log.verbose("⌚️ activationState=\(session.activationState.rawValue)")

        // Only pull new data when the phone becomes reachable
        guard session.isReachable else { return }

        self.requestListAll(preferReliable: false) { result in
            if case let .success(todos) = result {
                DispatchQueue.main.async {
                    LogManager.shared.log.verbose("⌚️ Watch pulled \(todos.count) tasks from phone")
                    self.lastSnapshot = todos
                }
            } else {
                let message: String
                switch result {
                case .success(let todos):
                    message = "success with \(todos.count) tasks"
                case .failure(let error):
                    message = "error: \(error.localizedDescription)"
                }
                LogManager.shared.log.verbose("⌚️ Watch failed to pull list from phone: \(message)")
            }
        }
    }
}


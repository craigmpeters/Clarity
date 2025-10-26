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

@MainActor
final class ClarityWatchConnectivity: NSObject, WCSessionDelegate, ObservableObject {
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
        print("[iOS] ⌚️ Creating Watch Session")
        #elseif os(watchOS)
        print("[watchOS] ⌚️ Creating Watch Session")
        #else
        print("⌚️ Creating Watch Session")
        #endif
        session.activate()
        #if os(iOS)
        // Initial state diagnostics for iOS
        print("[iOS] ⌚️ isPaired=\(session.isPaired) isWatchAppInstalled=\(session.isWatchAppInstalled) isReachable=\(session.isReachable)")
        #endif
    }

    // MARK: - Requests (phone<->watch both implement these)

    func requestListAll(preferReliable: Bool = false, reply: @escaping (Result<[ToDoTaskDTO], Error>) -> Void) {
        print("⌚️ Requesting Watch Data (preferReliable=\(preferReliable))")
        let msg: [String: Any] = [WCKeys.request: WCKeys.Requests.listAll]

        // If session isn't activated, just queue reliable and return snapshot
        guard session.activationState == .activated else {
            print("⌚️ Session not activated; queue reliable listAll and return snapshot")
            enqueueRequest(.init(kind: WCKeys.Requests.listAll))
            reply(.success(self.lastSnapshot))
            return
        }

        // Caller prefers reliable, but we'll still attempt immediate when reachable and fall back to reliable
        if preferReliable {
            print("⌚️ preferReliable=true but reachable path will be attempted; will fall back to reliable on timeout/failure")
        }

        // Reachable path with extended timeout and reliable fallback
        if session.isReachable {
            // Setup a timeout work item to fall back to reliable
            let timeoutSeconds: TimeInterval = 6.0
            var completed = false
            let timeout = DispatchWorkItem { [weak self] in
                guard let self, !completed else { return }
                completed = true
                print("⌚️ Immediate listAll timed out after \(timeoutSeconds)s → queue reliable and return snapshot")
                self.enqueueRequest(.init(kind: WCKeys.Requests.listAll))
                reply(.success(self.lastSnapshot))
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + timeoutSeconds, execute: timeout)

            session.sendMessage(msg, replyHandler: { dict in
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
                        print("⚠️ Immediate listAll missing payload; queue reliable and return snapshot")
                        self.enqueueRequest(.init(kind: WCKeys.Requests.listAll))
                        reply(.success(self.lastSnapshot))
                    }
                } catch {
                    // If decode fails, queue reliable request and fall back to snapshot
                    completed = true
                    timeout.cancel()
                    self.enqueueRequest(.init(kind: WCKeys.Requests.listAll))
                    print("⚠️ Immediate listAll decode failed, queued reliable fallback: \(error)")
                    reply(.success(self.lastSnapshot))
                }
            }, errorHandler: { error in
                guard !completed else { return }
                completed = true
                timeout.cancel()
                // If immediate message fails, queue a reliable request and fall back to snapshot
                self.enqueueRequest(.init(kind: WCKeys.Requests.listAll))
                print("⌚️ sendMessage failed, queued listAll via transferUserInfo: \(error)")
                reply(.success(self.lastSnapshot))
            })
        } else {
            print("⌚️ Session not reachable; queue reliable listAll and return snapshot")
            // Queue a reliable request so counterpart can respond later
            enqueueRequest(.init(kind: WCKeys.Requests.listAll))
            // Fallback to cached snapshot
            reply(.success(self.lastSnapshot))
        }
    }

    /// Try to send immediately if reachable; fall back to reliable transfer if not or on failure.
    private func sendImmediateOrReliable(_ env: Envelope) {
        guard session.activationState == .activated else {
            print("⌚️ sendImmediateOrReliable aborted: session not activated; falling back to queue")
            enqueueRequest(env)
            return
        }
        guard let data = try? jsonEncoder.encode(env) else {
            print("⌚️ sendImmediateOrReliable aborted: encode failed for \(env.kind)")
            return
        }

        let message: [String: Any] = [WCKeys.request: env.kind, WCKeys.payload: data]

        if session.isReachable {
            print("⌚️ Attempting immediate send(kind:\(env.kind)) …")
            session.sendMessage(message, replyHandler: { reply in
                #if DEBUG
                if JSONSerialization.isValidJSONObject(reply),
                   let rdata = try? JSONSerialization.data(withJSONObject: reply, options: [.prettyPrinted]),
                   let json = String(data: rdata, encoding: .utf8) {
                    print("📬 Immediate reply for \(env.kind):\n\(json)")
                } else {
                    print("📬 Immediate reply for \(env.kind): \(reply)")
                }
                #endif
            }, errorHandler: { error in
                print("⚠️ Immediate send(kind:\(env.kind)) failed → falling back to reliable: \(error)")
                self.session.transferUserInfo([WCKeys.payload: data])
            })
        } else {
            print("⌚️ Not reachable; queueing reliable transfer(kind:\(env.kind))")
            session.transferUserInfo([WCKeys.payload: data])
        }
    }

    func sendCreate(_ dto: ToDoTaskDTO) {
        sendImmediateOrReliable(.init(kind: WCKeys.Requests.create, todo: dto))
    }

    func sendComplete(todotaskid: String) {
        print("Complete Toggled with ID")
        sendImmediateOrReliable(.init(kind: WCKeys.Requests.complete, todotaskid: todotaskid))
    }
    
    func sendPomodoroStart(todotaskid: String) {
        sendImmediateOrReliable(.init(kind: WCKeys.Requests.startPomodoro, todotaskid: todotaskid))
    }
    
    func sendPomodoroStopped(_ dto: ToDoTaskDTO? = nil) async {
        guard let task = dto else {
            sendImmediateOrReliable(.init(kind: WCKeys.Requests.pomodoroStopped))
            return
        }
        Logger.WatchConnectivity.debug("Stopping Pomodoro for \(task.name)")
        if let pid = task.id {
            try? await ClarityServices.store().completeTask(pid)
        } else {
            Logger.WatchConnectivity.error("Could not decode Persistent ID for \(task.name)")
        }
        
        sendImmediateOrReliable(.init(kind: WCKeys.Requests.pomodoroStopped))
    }
    
    func sendPomodoroStarted(_ dto: PomodoroDTO) {
        sendImmediateOrReliable(.init(kind: WCKeys.Requests.pomodoroStarted, pomodoro: dto))
    }
    
    // Watch to Phone to stop the Pomodoro
    func sendPomodoroStop(pomodoro: PomodoroDTO) {
        sendImmediateOrReliable(.init(kind: WCKeys.Requests.stopPomodoro, pomodoro: pomodoro))
    }

    func sendDelete(id: String) {
        sendImmediateOrReliable(.init(kind: WCKeys.Requests.delete, todotaskid: id))
    }

    /// Sends a reliable ping over transferUserInfo to test the background/reliable channel.
    /// Use this when `isReachable` is false or to validate delivery while the counterpart is suspended.
    func sendReliablePing() {
        let env = Envelope(kind: "ping")
        enqueueRequest(env)
    }

    func pushSnapshot(_ todos: [ToDoTaskDTO]) {
        guard session.activationState == .activated else { return }
        DispatchQueue.main.async { self.lastSnapshot = todos }
        if let data = try? jsonEncoder.encode(Envelope(kind: "snapshot", todos: todos)) {
            try? session.updateApplicationContext([WCKeys.payload: data])
        }
    }

    private func enqueueRequest(_ env: Envelope) {
        guard session.activationState == .activated else {
            print("⌚️ enqueueRequest aborted: session not activated"); return
        }
        guard let data = try? jsonEncoder.encode(env) else {
            print("⌚️ enqueueRequest aborted: encode failed for \(env.kind)"); return
        }
        print("⌚️ enqueue transferUserInfo(kind:\(env.kind)) queued; reachable=\(session.isReachable)")
        session.transferUserInfo([WCKeys.payload: data])
    }

    private func sendReliable(_ env: Envelope) {
        guard session.activationState == .activated else {
            print("⌚️ sendReliable aborted: session not activated"); return
        }
        guard let data = try? jsonEncoder.encode(env) else {
            print("⌚️ sendReliable aborted: encode failed for \(env.kind)"); return
        }
        print("⌚️ outstanding transfers (pre-queue):", session.outstandingUserInfoTransfers.count)
        #if DEBUG
        if let jsonString = String(data: data, encoding: .utf8) {
            print("📮 sendReliable payload JSON:\n\(jsonString)")
        }
        #endif
        print("⌚️ transferUserInfo(kind:\(env.kind)) queued; reachable=\(session.isReachable)")
        session.transferUserInfo([WCKeys.payload: data])
        print("⌚️ outstanding transfers (post-queue):", session.outstandingUserInfoTransfers.count)
        print("⌚️ outstanding transfers:", session.outstandingUserInfoTransfers.count)
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            print("⌚️ outstanding transfers (5s later):", self.session.outstandingUserInfoTransfers.count)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 15) {
            print("⌚️ outstanding transfers (15s later):", self.session.outstandingUserInfoTransfers.count)
        }
    }


    // MARK: - WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        print("⌚️ activationDidCompleteWith state=\(activationState.rawValue) error=\(String(describing: error))")
    }

    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) { session.activate() }
    func sessionWatchStateDidChange(_ session: WCSession) {
        // This fires when pairing status, installed state, or complication enabled changes
        print("[iOS] ⌚️ sessionWatchStateDidChange → isPaired=\(session.isPaired) isWatchAppInstalled=\(session.isWatchAppInstalled) isComplicationEnabled=\(session.isComplicationEnabled)")
        print("[iOS] ⌚️ reachable=\(session.isReachable) activationState=\(session.activationState.rawValue)")
    }
    #endif

    // Incoming immediate request
    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        
        Task { @MainActor in
            #if DEBUG
            if JSONSerialization.isValidJSONObject(message),
               let data = try? JSONSerialization.data(withJSONObject: message, options: [.prettyPrinted]),
               let jsonString = String(data: data, encoding: .utf8) {
                print("📥 didReceiveMessage full JSON:\n\(jsonString)")
            } else {
                print("📥 didReceiveMessage raw message: \(message)")
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
        print("📨 iOS received userInfo raw keys: \(Array(userInfo.keys))")
        if let payloadData = userInfo[WCKeys.payload] as? Data {
            print("📦 userInfo payload bytes: \(payloadData.count)")
            if let env = try? jsonDecoder.decode(Envelope.self, from: payloadData),
               let pretty = try? JSONEncoder().encode(env),
               let json = String(data: pretty, encoding: .utf8) {
                print("📦 userInfo decoded Envelope JSON:\n\(json)")
            }
        }
        guard let data = userInfo[WCKeys.payload] as? Data else {
            print("❌ iOS userInfo missing payload under key \(WCKeys.payload)")
            return
        }
        guard let env = try? jsonDecoder.decode(Envelope.self, from: data) else {
            print("❌ iOS failed to decode Envelope from userInfo (\(data.count) bytes)")
            return
        }
        print("📨 …. kind=\(env.kind)")
        Task {
            await Self.applyEvent(env)
            print("✅ iOS applied event kind=\(env.kind)")
        } // implemented per-platform
    }

    // Snapshot push from counterpart
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        guard let data = applicationContext[WCKeys.payload] as? Data,
              let env = try? jsonDecoder.decode(Envelope.self, from: data),
              let todos = env.todos else { return }
        DispatchQueue.main.async { self.lastSnapshot = todos }
    }
}
// MARK: Processing Responses
extension ClarityWatchConnectivity {
    static func process(kind: String?, message: [String: Any]?) async -> Envelope {
        guard let kind else { return .init(kind: "error") }
        #if DEBUG
        print("🧭 process received kind=\(kind)")
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
        default:
            Logger.WatchConnectivity.error("Invalid Request Type: \(kind)")
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
            print("Not proessing request type on watch: \(kind)")
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
    
    private static func processWatchListAllRequest(_ message: [String: Any]?) async -> Envelope {
        if let todos = try? await ClarityServices.store().fetchTasks(filter: .all) {
            print("📦 iOS listAll returning \(todos.count) tasks")
            // Push snapshot so counterpart updates when this is triggered via reliable path
            ClarityWatchConnectivity.shared.pushSnapshot(todos)
            return Envelope(kind: WCKeys.Requests.listAll, todos: todos)
        } else {
            Logger.WatchConnectivity.error("📱 Could not fetch tasks")
            return Envelope(kind: WCKeys.Requests.listAll, todos: nil)
        }
    }
    
    private static func processWatchCompleteRequest(_ message: [String:Any]?) async -> Envelope {
        if let id = decodeMessageToPid(message) {
            do {
                try await ClarityServices.store().completeTask(id)
            } catch {
                Logger.WatchConnectivity.error("📱 Failed to complete Watch to Phone Task")
            }
            
            if let todos = try? await ClarityServices.store().fetchTasks(filter: .all) {
                ClarityWatchConnectivity.shared.pushSnapshot(todos)
            }
        }
        return Envelope(kind: WCKeys.Requests.complete)
    }
    
    private static func ProcessWatchPomodoroStart(_ message: [String:Any]?) async -> Envelope {
        // Get the Task ID
        // TODO: Change Watch to send DTO
        if let id = decodeMessageToPid(message) {
            do {
                guard let dto = try? await ClarityServices.store().fetchTaskById(id) else {
                    Logger.WatchConnectivity.error("Task Not Found")
                    return Envelope(kind: WCKeys.Requests.startPomodoro)
                }
                try await PomodoroService.shared.startPomodoro(for: dto, container: ClarityServices.store().modelContainer, device: .watchOS)
            } catch {
                Logger.WatchConnectivity.error("📱 Failed to start Pomodoro: \(error) ")
            }
        }
        return Envelope(kind: WCKeys.Requests.startPomodoro)
    }
    
    private static func ProcessWatchPomodoroStop(_ message: [String:Any]?) async -> Envelope {
        guard let dto = decodeMessageToPomodoro(message) else {
            Logger.WatchConnectivity.error("Error in decoding Pomodoro from message")
            return Envelope(kind: WCKeys.Requests.stopPomodoro)
        }
        Logger.WatchConnectivity.debug("Recieved End Pomodoro for Task \(dto.toDoTask.name)")
        await PomodoroService.shared.endPomodoro()
        if let pid = dto.toDoTask.id {
            do {
                try await ClarityServices.store().completeTask(pid)
            } catch {
                Logger.WatchConnectivity.error("Error in completing task \(dto.toDoTask.name) error: \(error)")
            }
        } else {
            Logger.WatchConnectivity.error("Could not decode Persistent Identifier from Pomodoro")
        }

        if let todos = try? await ClarityServices.store().fetchTasks(filter: .all) {
            ClarityWatchConnectivity.shared.pushSnapshot(todos)
        }
        return Envelope(kind: WCKeys.Requests.stopPomodoro)
    }
    
    private static func ProcessWatchPomodoroStopped(_ message: [String:Any]?) async -> Envelope {
        // If a ToDoTaskDTO is provided, attempt to complete the task on iOS
        guard let dto = decodeMessageToToDoTask(message) else {
            Logger.WatchConnectivity.error("Error in decoding ToDoTask from message")
            return Envelope(kind: WCKeys.Requests.pomodoroStopped)
        }
        Logger.WatchConnectivity.debug("Recieved A Stopped Pomodoro for Task \(dto.name)")
        
        if let id = dto.id {
            do {
                try await ClarityServices.store().completeTask(id)
            } catch {
                Logger.WatchConnectivity.error("Error Completing Task \(dto.name) error: \(error)")
            }
        }
        return Envelope(kind: WCKeys.Requests.pomodoroStopped)
    }
    
    #endif
    
    // MARK: WatchOS Process Functions
    #if os(watchOS)
    
    private static func ProcessPhonePomodoroStarted(_ message: [String:Any]?) async -> Envelope {
        guard let dto = decodeMessageToPomodoro(message) else {
            print("Cannot decode DTO")
            return Envelope(kind: WCKeys.Requests.pomodoroStarted)
        }
        ClarityWatchConnectivity.shared.activePomodoro = dto
        print("⌚️ Received pomodoroStarted with DTO for task: \(dto.toDoTask.name)")
        return Envelope(kind: WCKeys.Requests.pomodoroStarted)
    }
    
    private static func ProcessPhonePomodoroStopped(_ message: [String:Any]?) async -> Envelope {
        print("⌚️ Dismissing Pomodoro")
        ClarityWatchConnectivity.shared.activePomodoro = nil
        
        // After stopping, request a fresh snapshot from the phone
        ClarityWatchConnectivity.shared.requestListAll(preferReliable: false) { result in
            switch result {
            case .success(let todos):
                DispatchQueue.main.async {
                    print("⌚️ Watch requested snapshot after pomodoroStopped: \(todos.count) tasks")
                    ClarityWatchConnectivity.shared.lastSnapshot = todos
                }
            case .failure(let error):
                print("⚠️ Watch failed to request snapshot after pomodoroStopped: \(error)")
            }
        }
        return Envelope(kind: WCKeys.Requests.pomodoroStopped)
    }
    
    #endif
    
    // MARK: Helper Functions
    
    private static func decodeMessageToToDoTask(_ message: [String:Any]?) -> ToDoTaskDTO? {
        var encodedDto: ToDoTaskDTO?
        if let msg = message, let data = msg[WCKeys.payload] as? Data,
           let env = try? JSONDecoder().decode(Envelope.self, from: data) {
            encodedDto = env.todo
        }
        return encodedDto
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
    
    private static func decodeMessageToPid(_ message: [String:Any]?) -> PersistentIdentifier? {
        var encodedId: String?
        if let msg = message, let id = msg["id"] as? String { encodedId = id }
        if encodedId == nil, let msg = message, let data = msg[WCKeys.payload] as? Data,
           let env = try? JSONDecoder().decode(Envelope.self, from: data) {
            encodedId = env.todotaskid
        }
        if let encodedId, let pid = try? ToDoTaskDTO.decodeId(encodedId) {
            do {
                return pid
            }
        }
        return nil
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

    public init(kind: String, todos: [ToDoTaskDTO]? = nil, todo: ToDoTaskDTO? = nil, todotaskid : String? = nil, pomodoro: PomodoroDTO? = nil) {
        self.kind = kind
        self.todos = todos
        self.todo = todo
        self.todotaskid = todotaskid
        self.pomodoro = pomodoro
    }
}

extension ClarityWatchConnectivity {
    
    

    func sessionReachabilityDidChange(_ session: WCSession) {
        print("⌚️ Reachability changed → \(session.isReachable)")
        print("⌚️ activationState=\(session.activationState.rawValue)")

        // Only pull new data when the phone becomes reachable
        guard session.isReachable else { return }

        requestListAll(preferReliable: false) { result in
            if case let .success(todos) = result {
                DispatchQueue.main.async {
                    print("⌚️ Watch pulled \(todos.count) tasks from phone")
                    self.lastSnapshot = todos
                }
            } else {
                print("⌚️ Watch failed to pull list from phone: \(result)")
            }
        }
    }
}


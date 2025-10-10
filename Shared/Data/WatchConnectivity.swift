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

final class ClarityWatchConnectivity: NSObject, WCSessionDelegate, ObservableObject {
    static let shared = ClarityWatchConnectivity()
    private let session = WCSession.default
    private let jsonEncoder = JSONEncoder()
    private let jsonDecoder = JSONDecoder()

    @Published private(set) var lastSnapshot: [ToDoTaskDTO] = []

    func start() {
        guard WCSession.isSupported() else { return }
        session.delegate = self
        print("⌚️ Creating Watch Session")
        session.activate()
    }

    // MARK: - Requests (phone<->watch both implement these)

    func requestListAll(reply: @escaping (Result<[ToDoTaskDTO], Error>) -> Void) {
        print("⌚️ Requesting Watch Data")
        let msg: [String: Any] = [WCKeys.request: WCKeys.Requests.listAll]
        if session.isReachable {
            session.sendMessage(msg, replyHandler: { dict in
                do {
                    if let data = dict[WCKeys.payload] as? Data {
                        let env = try self.jsonDecoder.decode(Envelope.self, from: data)
                        reply(.success(env.todos ?? []))
                    } else { reply(.success([])) }
                } catch { reply(.failure(error)) }
            }, errorHandler: { error in
                reply(.failure(error))
            })
        } else {
            print("⌚️ Session not reachable")
            // Fallback to cached snapshot
            reply(.success(self.lastSnapshot))
        }
    }

    func sendCreate(_ dto: ToDoTaskDTO) {
        sendReliable(.init(kind: WCKeys.Requests.create, todo: dto))
    }

    func sendComplete(id: String) {
        sendReliable(.init(kind: WCKeys.Requests.complete, todotaskid: id))
    }
    
    func sendPomodoroStart(id: String) {
        sendReliable(.init(kind: WCKeys.Requests.pomodoro, todotaskid: id))
    }

    func sendDelete(id: String) {
        sendReliable(.init(kind: WCKeys.Requests.delete, todotaskid: id))
    }

    func pushSnapshot(_ todos: [ToDoTaskDTO]) {
        guard session.activationState == .activated else { return }
        lastSnapshot = todos
        if let data = try? jsonEncoder.encode(Envelope(kind: "snapshot", todos: todos)) {
            try? session.updateApplicationContext([WCKeys.payload: data])
        }
    }

    private func sendReliable(_ env: Envelope) {
        guard session.activationState == .activated else {
            print("⌚️ sendReliable aborted: session not activated"); return
        }
        guard let data = try? jsonEncoder.encode(env) else {
            print("⌚️ sendReliable aborted: encode failed for \(env.kind)"); return
        }
        print("⌚️ transferUserInfo(kind:\(env.kind)) queued; reachable=\(session.isReachable)")
        session.transferUserInfo([WCKeys.payload: data])
        print("⌚️ outstanding transfers:", session.outstandingUserInfoTransfers.count)
    }


    // MARK: - WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        print("⌚️ activationDidCompleteWith state=\(activationState.rawValue) error=\(String(describing: error))")
    }

    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) { session.activate() }
    #endif

    // Incoming immediate request
    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        
        Task { @MainActor in
            let kind = message[WCKeys.request] as? String
            let result = await Self.handleImmediate(kind: kind) // implemented per-platform
            let data = try? self.jsonEncoder.encode(result)
            replyHandler([WCKeys.payload: data as Any])
        }
    }

    // Incoming reliable events
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        guard let data = userInfo[WCKeys.payload] as? Data,
              let env = try? jsonDecoder.decode(Envelope.self, from: data) else { return }
        Task { await Self.applyEvent(env) } // implemented per-platform
    }

    // Snapshot push from counterpart
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        guard let data = applicationContext[WCKeys.payload] as? Data,
              let env = try? jsonDecoder.decode(Envelope.self, from: data),
              let todos = env.todos else { return }
        DispatchQueue.main.async { self.lastSnapshot = todos }
    }
}

extension ClarityWatchConnectivity {
    static func handleImmediate(kind: String?) async -> Envelope {
        guard let kind else { return .init(kind: "error") }
        switch kind {
        case WCKeys.Requests.listAll:
            // Query SwiftData via your ModelActor (background)
            if let todos = try? await ClarityServices.store().fetchTasks(filter: .all) {
                return Envelope(kind: "listAll", todos: todos)
            }
        default: break
        }
        return .init(kind: "error")
    }

    static func applyEvent(_ env: Envelope) async {
        switch env.kind {
        case WCKeys.Requests.create:
            if let t = env.todo {
                _ = try? await ClarityServices.store().addTask(t)
            }
        case WCKeys.Requests.complete:
            if let encodedId = env.todotaskid {
                // Use DTO helper to decode Base64-encoded PersistentIdentifier
                if let pid = try? ToDoTaskDTO.decodeId(encodedId) {
                    _ = try? await ClarityServices.store().completeTask(pid)
                }
            }
        case WCKeys.Requests.delete:
            if let encodedId = env.todotaskid {
                if let pid = try? ToDoTaskDTO.decodeId(encodedId) {
                    try? await ClarityServices.store().deleteTask(pid)
                }
            }
        default: break
        }
        // After any mutation, push a fresh snapshot so watch updates quickly
        if let todos = try? await ClarityServices.store().fetchTasks(filter: .all){
            ClarityWatchConnectivity.shared.pushSnapshot(todos)
        }
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
        public static let pomodoro = "pomodoro"
    }
}

public struct Envelope: Codable, Sendable {
    public let kind: String
    public let todos: [ToDoTaskDTO]?       // for list/snapshot
    public let todo: ToDoTaskDTO?          // for single op
    public let todotaskid: String?

    public init(kind: String, todos: [ToDoTaskDTO]? = nil, todo: ToDoTaskDTO? = nil, todotaskid : String? = nil) {
        self.kind = kind
        self.todos = todos
        self.todo = todo
        self.todotaskid = todotaskid
    }
}

extension ClarityWatchConnectivity {
    
    

    func sessionReachabilityDidChange(_ session: WCSession) {
        print("⌚️ Reachability changed → \(session.isReachable)")

        // Only pull new data when the phone becomes reachable
        guard session.isReachable else { return }

        requestListAll { result in
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


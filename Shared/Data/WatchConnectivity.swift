//
//  WatchConnectivity.swift
//  Clarity
//
//  Created by Craig Peters on 29/09/2025.
//

import Foundation
import WatchConnectivity
import Combine

final class ClarityWatchConnectivity: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = ClarityWatchConnectivity()
    let session = WCSession.default
    @Published var activationState: WCSessionActivationState = .notActivated
    @Published var isReachable: Bool = false
    
    @Published var lastReceivedTasks: [TaskTransfer] = []
    
    struct TaskTransfer: Codable, Identifiable {
        let id: String
        let name: String
        let pomodoroTime: TimeInterval
        let due: Date
        let categories: [String]
    }
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        print("WCSession activation did complete: \(activationState) error: \(String(describing: error))")
        DispatchQueue.main.async {
            self.activationState = activationState
        }
        #if os(watchOS)
        // Request a snapshot from the phone when activation completes, but only if reachable
        if session.isReachable {
            Task { [weak self] in
                self?.requestTasksFromPhone()
            }
        } else {
            // Queue a background request safely
            session.transferUserInfo(["request": "tasks"])
        }
        #endif
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        let reachable = session.isReachable
        print("WCSession reachability changed: \(reachable)")
        DispatchQueue.main.async {
            self.isReachable = reachable
        }
    }
    
    // Handle immediate messages with reply
    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        if let complete = message["completeTask"] as? [String: Any],
           let id = complete["id"] as? String {
            #if os(iOS)
            Task {
                if let task = try? await StaticDataStore.shared.fetchTaskById(id) {
                    await StaticDataStore.shared.completeTask(task)
                }
                replyHandler(["status": "ok"])            
            }
            #else
            replyHandler([:])
            #endif
            return
        }
        
        // Phone responds to task requests; Watch handles task payloads
        if let request = message["request"] as? String, request == "tasks" {
            // iPhone side: package and reply with current tasks
            #if os(iOS)
            Task {
                let tasks = (try? await StaticDataStore.shared.fetchTasks(.all)) ?? []
                let payload = self.serializeTasks(tasks)
                replyHandler(["tasks": payload])
            }
            #else
            replyHandler([:])
            #endif
            return
        }
        
        if let array = message["tasks"] as? [[String: Any]] {
            // Watch side: receive tasks
            #if os(watchOS)
            let transfers = self.parseTasks(array)
            DispatchQueue.main.async {
                self.lastReceivedTasks = transfers
            }
            #endif
        }
    }
    
    // Handle fire-and-forget messages
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        if let complete = message["completeTask"] as? [String: Any],
           let id = complete["id"] as? String {
            #if os(iOS)
            Task {
                if let task = try? await StaticDataStore.shared.fetchTaskById(id) {
                    await StaticDataStore.shared.completeTask(task)
                }
            }
            #endif
            return
        }
        
        if let array = message["tasks"] as? [[String: Any]] {
            #if os(watchOS)
            let transfers = self.parseTasks(array)
            DispatchQueue.main.async {
                self.lastReceivedTasks = transfers
            }
            #endif
        }
    }
    
    // Background delivery fallback
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        if let complete = userInfo["completeTask"] as? [String: Any],
           let id = complete["id"] as? String {
            #if os(iOS)
            Task {
                if let task = try? await StaticDataStore.shared.fetchTaskById(id) {
                    await StaticDataStore.shared.completeTask(task)
                }
            }
            #endif
            return
        }
        
        if let array = userInfo["tasks"] as? [[String: Any]] {
            #if os(watchOS)
            let transfers = self.parseTasks(array)
            DispatchQueue.main.async {
                self.lastReceivedTasks = transfers
            }
            #endif
        } else if let request = userInfo["request"] as? String, request == "tasks" {
            // iPhone side: package and queue a response back using transferUserInfo
            #if os(iOS)
            Task {
                let tasks = (try? await StaticDataStore.shared.fetchTasks(.all)) ?? []
                let payload = self.serializeTasks(tasks)
                session.transferUserInfo(["tasks": payload])
            }
            #endif
        }
    }
    
    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {
        print("WCSession did become inactive")
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        print("WCSession did deactivate — reactivating")
        session.activate()
    }
    
    func sessionWatchStateDidChange(_ session: WCSession) {
        print("WCSession watch state did change. Paired: \(session.isPaired), Watch app installed: \(session.isWatchAppInstalled)")
    }

    #endif

    // MARK: - Helpers
    #if os(iOS)
    private func serializeTasks(_ tasks: [ToDoTask]) -> [[String: Any]] {
        return tasks.map { task in
            return [
                "id": String(describing: task.id),
                "name": task.name ?? "",
                "pomodoroTime": task.pomodoroTime,
                "due": task.due.timeIntervalSince1970,
                "categories": (task.categories ?? []).compactMap { $0.name }
            ]
        }
    }
    #else
    private func serializeTasks(_ tasks: [Any]) -> [[String: Any]] { return [] }
    #endif
    
    private func parseTasks(_ array: [[String: Any]]) -> [TaskTransfer] {
        return array.compactMap { dict in
            guard let id = dict["id"] as? String,
                  let name = dict["name"] as? String,
                  let pomodoro = dict["pomodoroTime"] as? TimeInterval,
                  let dueInterval = dict["due"] as? TimeInterval else { return nil }
            let cats = dict["categories"] as? [String] ?? []
            return TaskTransfer(id: id, name: name, pomodoroTime: pomodoro, due: Date(timeIntervalSince1970: dueInterval), categories: cats)
        }
    }
    
    #if os(watchOS)
    // Public API to request tasks from the phone as a fallback when CloudKit/iCloud data isn't available yet
    func requestTasksFromPhone() {
        guard WCSession.isSupported() else { return }
        if session.isReachable {
            session.sendMessage(["request": "tasks"], replyHandler: { [weak self] reply in
                if let array = reply["tasks"] as? [[String: Any]] {
                    let transfers = self?.parseTasks(array) ?? []
                    DispatchQueue.main.async {
                        self?.lastReceivedTasks = transfers
                    }
                }
            }, errorHandler: { error in
                print("Error requesting tasks from phone: \(error)")
            })
        } else {
            // Queue a background request
            session.transferUserInfo(["request": "tasks"])            
        }
    }
    
    func sendTaskCompleted(_ transfer: TaskTransfer) {
        guard WCSession.isSupported() else { return }
        let payload: [String: Any] = [
            "completeTask": [
                "id": transfer.id,
                "completedAt": Date().timeIntervalSince1970
            ]
        ]
        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil) { error in
                print("Error sending completion to phone: \(error)")
            }
        } else {
            session.transferUserInfo(payload)
        }
    }
    #endif

    override private init() {
        super.init()
        #if !os(watchOS)
        guard WCSession.isSupported() else {
            return
        }
        #endif
        session.delegate = self
        self.activationState = session.activationState
        self.isReachable = session.isReachable
        session.activate()
    }
}


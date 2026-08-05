//
//  WatchSnapshotStore.swift
//  Clarity
//
//  watchOS coordinator for watch ↔ phone connectivity business logic.
//

import Foundation
import WidgetKit
import XCGLogger

@MainActor
@Observable
final class WatchSnapshotStore {
    static let shared = WatchSnapshotStore()

    private(set) var snapshot: Snapshot = Snapshot(
        revision: 0,
        tasks: [],
        progress: WeeklyProgress(completed: 0, target: 0, error: nil, categories: []),
        activePomodoro: nil
    )
    private(set) var activePomodoro: PomodoroDTO?
    private(set) var optimisticallyCompleted: Set<UUID> = []

    private var lastAppliedRevision: Int = 0
    private var consumerTask: Task<Void, Never>?

    private init() {}

    func start() {
        ConnectivityTransport.shared.start()
        consumerTask = Task { [weak self] in
            for await msg in ConnectivityTransport.shared.inbound {
                await self?.apply(msg)
            }
        }
    }

    private func apply(_ msg: WireMessage) {
        switch msg {
        case .snapshot(let s), .complicationSnapshot(let s):
            guard s.revision > lastAppliedRevision else { return }
            lastAppliedRevision = s.revision
            snapshot = s
            activePomodoro = s.activePomodoro
            optimisticallyCompleted = []
            persistSnapshot(s)
            WidgetCenter.shared.reloadAllTimelines()
        case .event(let evt):
            switch evt {
            case .pomodoroStarted(let dto):
                if let end = dto.endTime, end <= Date() { return }
                activePomodoro = dto
            case .pomodoroStopped:
                activePomodoro = nil
            }
        case .command:
            // Commands don't originate on watch in this path.
            break
        }
    }

    private func persistSnapshot(_ s: Snapshot) {
        try? WidgetFileCoordinator.shared.writeTasks(s.tasks)
        try? WidgetFileCoordinator.shared.writeWeeklyProgress(s.progress)
    }

    func dismissPomodoro() {
        activePomodoro = nil
    }

    // MARK: UI intents

    func complete(_ task: ToDoTaskDTO) {
        optimisticallyCompleted.insert(task.uuid)
        Task { try? await ConnectivityTransport.shared.send(.completeTask(task.uuid)) }
    }

    func uncomplete(_ task: ToDoTaskDTO) {
        optimisticallyCompleted.remove(task.uuid)
        Task { try? await ConnectivityTransport.shared.send(.uncompleteTask(task.uuid)) }
    }

    func startPomodoro(_ task: ToDoTaskDTO) {
        Task { try? await ConnectivityTransport.shared.send(.startPomodoro(task.uuid)) }
    }

    func stopPomodoro() {
        Task { try? await ConnectivityTransport.shared.send(.stopPomodoro) }
    }

    func sendLogs(_ data: Data) {
        Task { try? await ConnectivityTransport.shared.send(.sendLogs(data)) }
    }

    func requestInitialSnapshot() async {
        do {
            let snap = try await ConnectivityTransport.shared.fetchSnapshot()
            apply(.snapshot(snap))
        } catch {
            LogManager.shared.log.debug("[WatchSnapshotStore] fetchSnapshot failed: \(error). Falling back to cached snapshot.")
            let tasks = (try? WidgetFileCoordinator.shared.readTasks()) ?? []
            let progress = WidgetFileCoordinator.shared.readWeeklyProgress() ?? WeeklyProgress(completed: 0, target: 0, error: nil, categories: [])
            snapshot = Snapshot(revision: 0, tasks: tasks, progress: progress, activePomodoro: nil)
        }
    }
}

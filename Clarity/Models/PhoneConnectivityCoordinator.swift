//
//  PhoneConnectivityCoordinator.swift
//  Clarity
//
//  iOS coordinator for watch ↔ phone connectivity business logic.
//

import Foundation
import WatchConnectivity
import WidgetKit
import SwiftData
import XCGLogger

@MainActor
@Observable
final class PhoneConnectivityCoordinator: SnapshotBuilder {
    static let shared = PhoneConnectivityCoordinator()

    private var consumerTask: Task<Void, Never>?
    private var broadcastTask: Task<Void, Never>?
    private var revision: Int = 0

    private init() {}

    func start() {
        ConnectivityTransport.shared.configure(snapshotBuilder: self)
        ConnectivityTransport.shared.start()
        consumerTask = Task { [weak self] in
            for await msg in ConnectivityTransport.shared.inbound {
                await self?.handle(msg)
            }
        }
        observePomodoroNotifications()
    }

    // MARK: SnapshotBuilder

    func buildSnapshot() async -> Snapshot {
        let tasks = (try? WidgetFileCoordinator.shared.readTasks()) ?? []
        let habits = WidgetFileCoordinator.shared.readHabits()
        let progress = WidgetFileCoordinator.shared.readWeeklyProgress() ?? WeeklyProgress(completed: 0, target: 0, error: nil, categories: [])
        let active: PomodoroDTO? = {
            guard PomodoroService.shared.isActive else { return nil }
            return PomodoroDTO(
                startTime: PomodoroService.shared.startTime,
                endTime: PomodoroService.shared.endTime,
                toDoTask: PomodoroService.shared.toDoTask ?? tasks.first ?? ToDoTaskDTO(name: nil, uuid: UUID(), completed: false)
            )
        }()
        let occurrences = await buildHabitOccurrences(habits: habits)
        return Snapshot(revision: revision, tasks: tasks, habits: habits, habitOccurrences: occurrences, progress: progress, activePomodoro: active)
    }

    private func buildHabitOccurrences(habits: [HabitDTO]) async -> [UUID: HabitOccurrenceDTO] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let store = try? await ClarityServices.store()
        var result: [UUID: HabitOccurrenceDTO] = [:]
        for habit in habits {
            guard let store = store else { continue }
            let history = (try? await store.fetchHabitHistory(habit.uuid, from: startOfDay, to: Date())) ?? []
            if let today = history.first(where: { calendar.isDate($0.periodStart, inSameDayAs: Date()) }) {
                result[habit.uuid] = today
            }
        }
        return result
    }

    func transferHabitArtwork(filename: String, for habitUUID: UUID) {
        guard let url = WidgetFileCoordinator.shared.habitArtworkURL(filename: filename) else { return }
        ConnectivityTransport.shared.transferHabitArtwork(fileURL: url, habitUUID: habitUUID)
    }

    private func handle(_ msg: WireMessage) async {
        switch msg {
        case .command(let cmd):
            await handleCommand(cmd)
        case .event:
            // Events are phone-to-watch; ignored on phone.
            break
        case .snapshot, .complicationSnapshot:
            // Snapshots are phone-to-watch; ignored on phone.
            break
        }
    }

    private func handleCommand(_ cmd: WatchCommand) async {
        switch cmd {
        case .completeTask(let id):
            do {
                try await ClarityServices.store().completeTask(id)
            } catch {
                LogManager.shared.log.error("⌚️ complete task failed: \(error)")
            }
        case .uncompleteTask(let id):
            do {
                try await ClarityServices.store().uncompleteTask(id)
            } catch {
                LogManager.shared.log.error("⌚️ uncomplete task failed: \(error)")
            }
        case .startPomodoro(let id):
            await startPomodoroFromWatch(id)
        case .stopPomodoro:
            await PomodoroService.shared.endPomodoro()
        case .sendLogs(let data):
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd_HHmmss"
            let filename = "watch_logs_\(formatter.string(from: Date())).log"
            try? WidgetFileCoordinator.shared.writeLogFile(fileName: filename, data: data)
        case .requestSnapshot:
            // No-op: reply handled in the transport via SnapshotBuilder.
            break
        case .logHabitProgress(let uuid, let amount):
            do {
                try await ClarityServices.store().logHabitProgress(uuid, amount: amount)
            } catch {
                LogManager.shared.log.error("⌚️ log habit progress failed: \(error)")
            }
        }
        broadcastSnapshot()
    }

    private func startPomodoroFromWatch(_ id: UUID) async {
        let defaults = UserDefaults(suiteName: "group.me.craigpeters.clarity")
        defaults?.set(id.uuidString, forKey: "pendingStartTimerTaskId")

        let store = try? await ClarityServices.store()
        if let dto = try? WidgetFileCoordinator.shared.readTaskByUuid(id),
           let container = store?.modelContainer {
            PomodoroService.shared.startPomodoro(for: dto, container: container, device: .watchOS)
            defaults?.removeObject(forKey: "pendingStartTimerTaskId")
        }
    }

    // MARK: Snapshot broadcast

    func broadcastSnapshot() {
        broadcastTask?.cancel()
        broadcastTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled, let self else { return }
            self.revision += 1
            let snap = await self.buildSnapshot()
            try? await ConnectivityTransport.shared.pushState(snap)
            try? await ConnectivityTransport.shared.pushComplicationIfNeeded(snap)
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    // MARK: Pomodoro notifications

    private func observePomodoroNotifications() {
        NotificationCenter.default.addObserver(
            forName: .pomodoroStarted,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                guard let task = PomodoroService.shared.toDoTask,
                      let start = PomodoroService.shared.startTime,
                      let end = PomodoroService.shared.endTime else { return }
                let dto = PomodoroDTO(startTime: start, endTime: end, toDoTask: task)
                try? await ConnectivityTransport.shared.send(.pomodoroStarted(dto))
                self.broadcastSnapshot()
            }
        }

        NotificationCenter.default.addObserver(
            forName: .pomodoroCompleted,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                let id = PomodoroService.shared.toDoTask?.uuid
                try? await ConnectivityTransport.shared.send(.pomodoroStopped(taskID: id))
                self.broadcastSnapshot()
            }
        }
    }
}

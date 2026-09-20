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
    private var lastBroadcastAt: Date = .distantPast

    // Persisted so the revision is monotonic across phone app relaunches.
    // The watch keeps its last-applied revision for the whole install, so a
    // phone restart that reset this to 0 would make the watch drop every
    // snapshot until the phone caught up — i.e. "watch never syncs".
    private static let revisionKey = "phoneSnapshotRevision"
    private var revision: Int

    private init() {
        self.revision = UserDefaults.standard.integer(forKey: Self.revisionKey)
    }

    func start() {
        ConnectivityTransport.shared.configure(snapshotBuilder: self)
        ConnectivityTransport.shared.start()
        consumerTask = Task { [weak self] in
            for await msg in ConnectivityTransport.shared.inbound {
                await self?.handle(msg)
            }
        }
        observePomodoroNotifications()
        observeFocusFilterChanges()
        // Push current state shortly after launch so a watch that was out of
        // reach (and missed queued transfers) converges once we activate.
        broadcastSnapshot(delay: .seconds(2))
    }

    /// The App Intents extension posts this Darwin notification when the focus
    /// filter changes; re-filtered tasks are pushed to the watch right away.
    private func observeFocusFilterChanges() {
        let observer = Unmanaged.passUnretained(self).toOpaque()
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            observer,
            { _, observer, _, _, _ in
                guard let observer else { return }
                let coordinator = Unmanaged<PhoneConnectivityCoordinator>.fromOpaque(observer).takeUnretainedValue()
                Task { @MainActor in
                    coordinator.broadcastSnapshot(delay: .zero)
                }
            },
            FocusFilterSync.changedNotification.rawValue as CFString,
            nil,
            .deliverImmediately
        )
    }

    // MARK: SnapshotBuilder

    func buildSnapshot() async -> Snapshot {
        let tasks = (try? WidgetFileCoordinator.shared.readTasks()) ?? []
        let habits: [HabitDTO]
        do {
            habits = try WidgetFileCoordinator.shared.readHabits()
        } catch {
            LogManager.shared.log.error("Failed to read habits snapshot: \(error)")
            habits = []
        }
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
        let enrichedHabits = await enrichHabitsForWatch(habits: habits, occurrences: occurrences)
        return Snapshot(revision: revision, tasks: tasks, habits: enrichedHabits, habitOccurrences: occurrences, progress: progress, activePomodoro: active)
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

    private func enrichHabitsForWatch(habits: [HabitDTO], occurrences: [UUID: HabitOccurrenceDTO]) async -> [HabitDTO] {
        let store = try? await ClarityServices.store()
        let calendar = HabitStreakCalculator.streakCalendar()
        let now = Date()
        let today = calendar.startOfDay(for: now)
        let rollingStart = calendar.date(byAdding: .day, value: -6, to: today) ?? today
        return await withTaskGroup(of: HabitDTO.self) { group in
            for habit in habits {
                group.addTask {
                    var enriched = habit
                    guard let store = store else { return enriched }
                    let allHistory = (try? await store.fetchHabitHistory(habit.uuid, from: Date.distantPast, to: now)) ?? []
                    let streak = HabitStreakCalculator.streak(occurrences: allHistory, frequency: habit.weeklyFrequency, freezes: habit.streakFreezes)
                    enriched.currentStreak = streak.current
                    let recentHistory = (try? await store.fetchHabitHistory(habit.uuid, from: rollingStart, to: now)) ?? []
                    // Rolling 7-day window: oldest day first, today last.
                    enriched.weekCompletionBitmap = (0..<7).map { offset -> Bool in
                        guard let day = calendar.date(byAdding: .day, value: offset - 6, to: today) else { return false }
                        return recentHistory.contains { occurrence in
                            calendar.isDate(occurrence.periodStart, inSameDayAs: day) && (occurrence.completed || occurrence.freezeUsed)
                        }
                    }
                    return enriched
                }
            }
            var result: [HabitDTO] = []
            for await habit in group {
                result.append(habit)
            }
            return result
        }
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
            broadcastSnapshot()
        case .uncompleteTask(let id):
            do {
                try await ClarityServices.store().uncompleteTask(id)
            } catch {
                LogManager.shared.log.error("⌚️ uncomplete task failed: \(error)")
            }
            broadcastSnapshot()
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
                let store = try await ClarityServices.store()
                let habit = try await store.fetchHabits().first(where: { $0.uuid == uuid })
                if habit?.healthKitIdentifier != nil {
                    _ = try await store.logHabitProgressWithHealthKit(uuid, amount: amount)
                } else {
                    _ = try await store.logHabitProgress(uuid, amount: amount, source: "watch")
                }
                broadcastSnapshot()
            } catch {
                LogManager.shared.log.error("⌚️ log habit progress failed: \(error)")
                try? await ConnectivityTransport.shared.send(.habitCommandFailed(uuid: uuid))
                // Still broadcast the current snapshot so the watch can reconcile its optimistic state.
                broadcastSnapshot()
            }
        }
    }

    private func startPomodoroFromWatch(_ id: UUID) async {
        LogManager.shared.log.debug("[PhoneConnectivity] startPomodoroFromWatch \(id)")
        let defaults = UserDefaults(suiteName: "group.me.craigpeters.clarity")
        defaults?.set(id.uuidString, forKey: "pendingStartTimerTaskId")

        let store: ClarityModelActor
        do {
            store = try await ClarityServices.store()
        } catch {
            LogManager.shared.log.error("[PhoneConnectivity] startPomodoroFromWatch: store unavailable: \(error)")
            return
        }
        let dto: ToDoTaskDTO
        do {
            guard let found = try WidgetFileCoordinator.shared.readTaskByUuid(id) else {
                LogManager.shared.log.error("[PhoneConnectivity] startPomodoroFromWatch: readTaskByUuid returned nil for \(id) — task missing from widget snapshot")
                return
            }
            dto = found
        } catch {
            LogManager.shared.log.error("[PhoneConnectivity] startPomodoroFromWatch: readTaskByUuid threw for \(id): \(error)")
            return
        }
        let container = store.modelContainer
        PomodoroService.shared.startPomodoro(for: dto, container: container, device: .watchOS)
        defaults?.removeObject(forKey: "pendingStartTimerTaskId")
        LogManager.shared.log.info("[PhoneConnectivity] Pomodoro started from watch for \(dto.name) (\(id))")
    }

    // MARK: Snapshot broadcast

    func broadcastSnapshot(delay: Duration = .milliseconds(500)) {
        broadcastTask?.cancel()
        broadcastTask = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled, let self else { return }
            self.revision += 1
            UserDefaults.standard.set(self.revision, forKey: Self.revisionKey)
            let snap = await self.buildSnapshot()
            do {
                try await ConnectivityTransport.shared.pushState(snap)
                self.lastBroadcastAt = Date()
            } catch {
                // Expected when the watch is unreachable (applicationContext
                // can only be set while the counterpart is reachable). Retry
                // with backoff so the watch converges when it comes back.
                LogManager.shared.log.debug("[PhoneConnectivity] pushState failed: \(error.localizedDescription); will retry")
                self.scheduleBroadcastRetry()
            }
            try? await ConnectivityTransport.shared.pushComplicationIfNeeded(snap)
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    private func scheduleBroadcastRetry() {
        guard Date().timeIntervalSince(lastBroadcastAt) > 30 else { return }
        broadcastSnapshot(delay: .seconds(15))
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
        ) { [weak self] notification in
            guard let self else { return }
            let taskUUID = notification.userInfo?[Notification.Name.taskUUIDKey] as? UUID
            Task { @MainActor in
                let id = taskUUID ?? PomodoroService.shared.toDoTask?.uuid
                try? await ConnectivityTransport.shared.send(.pomodoroStopped(taskID: id))
                self.broadcastSnapshot()
            }
        }
    }
}

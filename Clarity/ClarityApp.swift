//
//  ClarityApp.swift
//  Clarity
//
//  Created by Craig Peters on 17/08/2025.
//

import SwiftUI
import SwiftData
import UserNotifications
import BackgroundTasks
import AppIntents
#if canImport(WatchConnectivity)
import WatchConnectivity
#endif
import Combine

final class AppState: ObservableObject {
    @Published var showingPomodoro: Bool = false
    @Published var pomodoroUuid: UUID?
    @Published var selectedTab: Int = 0
}

@main
struct ClarityApp: App {
    private struct Migration {
        static let uuidPopulatedKeyPrefix = "com.clarity.migration.uuidPopulated_"

        static var currentBuild: String {
            Bundle.main.object(forInfoDictionaryKey: kCFBundleVersionKey as String) as? String ?? "0"
        }

        static func hasRun(forBuild build: String) -> Bool {
            UserDefaults.standard.bool(forKey: uuidPopulatedKeyPrefix + build)
        }

        static func markRun(forBuild build: String) {
            UserDefaults.standard.set(true, forKey: uuidPopulatedKeyPrefix + build)
        }
    }
    
    init() {}
    
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    private let container = try! Containers.liveApp()
    @StateObject private var appState = AppState()
    private var companion = CompanionService.shared
    @State private var store = Store()
    @Environment(\.scenePhase) private var scenePhase
    
    private func populateUUIDsIfNeeded(modelContext: ModelContext, minimumBuild: String) {
        // Only run once per build
        let currentBuild = Migration.currentBuild
        guard currentBuild >= minimumBuild, Migration.hasRun(forBuild: currentBuild) == false else { return }
        LogManager.shared.log.debug("Running Populate UUID Migration")

        var updatedCount = 0
        do {
            // Backfill ToDoTask.uuid
            let tasks = try modelContext.fetch(FetchDescriptor<ToDoTask>())
            for task in tasks where task.uuid == nil {
                task.uuid = UUID()
                updatedCount += 1
            }

            // Backfill Category.uuid
            let categories = try modelContext.fetch(FetchDescriptor<Category>())
            for category in categories where category.uuid == nil {
                category.uuid = UUID()
                updatedCount += 1
            }

            if updatedCount > 0 {
                try modelContext.save()
                LogManager.shared.log.debug("UUID migration: backfilled \(updatedCount) records")
            }
            Migration.markRun(forBuild: currentBuild)
        } catch {
            // If anything fails, don't mark as run so we can attempt again next launch
            LogManager.shared.log.error("Migration populateUUIDsIfNeeded error: \(error)")
        }
    }
        

    var body: some Scene {
        WindowGroup {
            ContentView().environment(store)
                .environmentObject(appState)
                .environment(companion)
                .modelContainer(container)
                .onAppear {
                    appDelegate.appState = appState
                    populateUUIDsIfNeeded(modelContext: container.mainContext, minimumBuild: "1.3.0")
                    // Prime the shared category snapshot so widgets / App Intents can read
                    // categories without spinning up a SwiftData container.
                    let categories = ClarityServices.snapshotCategories()
                    try? WidgetFileCoordinator.shared.writeCategories(categories)
                    Task { @MainActor in
                        await PomodoroService.shared.restoreIfNeeded(container: container, device: .iPhone)
                        if PomodoroService.shared.isActive {
                            appState.showingPomodoro = true
                        }
                    }
                }
                .task {
                    if let id = consumePendingStartTimerTaskId() {
                        appState.pomodoroUuid = id
                        LogManager.shared.log.debug("Starting Pomodero (.task) for \(id.uuidString)")
                        let store = ClarityModelActor(modelContainer: container)
                        do {
                            if let taskDTO = try await store.fetchTaskByUuid(id) {
                                PomodoroService.shared.startPomodoro(for: taskDTO, container: container, device: .iPhone)
                                appState.showingPomodoro = true
                            }
                        } catch {
                            // Log and swallow the error to keep the .task closure non-throwing
                            LogManager.shared.log.error("Failed to fetch task by UUID: \(error)")
                        }
                    }
                }
                .onChange(of: scenePhase) { _, newPhase in
                    guard newPhase == .active else { return }
                    // Keep the App Group category snapshot fresh for widgets / intents.
                    ClarityServices.writeCategorySnapshot()
                    if let id = consumePendingStartTimerTaskId() {
                        LogManager.shared.log.debug("Starting Pomodero (.onChange Active) for \(id.uuidString)")
                        appState.pomodoroUuid = id
                        let store = ClarityModelActor(modelContainer: container)
                        Task {
                            do {
                                if let taskDTO = try await store.fetchTaskByUuid(id) {
                                    PomodoroService.shared.startPomodoro(for: taskDTO, container: container, device: .iPhone)
                                    appState.showingPomodoro = true
                                }
                            } catch {
                                LogManager.shared.log.error("Failed to fetch task by UUID (resume): \(error)")
                            }
                        }
                    }
                }
        }
    }
    
    static var appShortcuts: AppShortcutsProvider.Type {
            ClarityShortcutsProvider.self
        }
    
    private func consumePendingStartTimerTaskId(appGroup: String = "group.me.craigpeters.clarity") -> UUID? {
        let defaults = UserDefaults(suiteName: appGroup)
        guard let idString = defaults?.string(forKey: "pendingStartTimerTaskId"),
              let id = UUID(uuidString: idString) else {
            return nil
        }
        defaults?.removeObject(forKey: "pendingStartTimerTaskId")
        return id
    }
}

@MainActor
class AppDelegate: NSObject, UIApplicationDelegate, @preconcurrency UNUserNotificationCenterDelegate {
    private var cancellables = Set<AnyCancellable>()
    private static var remoteLoggerInstalled = false
    
    weak var appState: AppState?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        // Migrations are triggered from ClarityApp.onAppear via modelContext
        PhoneConnectivityCoordinator.shared.start()
        ClarityModelActor.onTaskCompleted = { PhoneConnectivityCoordinator.shared.broadcastSnapshot() }
        ClarityModelActor.onTaskMutated = { PhoneConnectivityCoordinator.shared.broadcastSnapshot() }
        _ = LogManager.shared
        // let url = LogManager.defaultLogFileURL()
        LogManager.shared.log.info("Clarity logger initialized in AppDelegate")
        AppDelegate.installRemoteChangeLogger()
        NotificationCenter.default.publisher(for: .pomodoroStarted)
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.appState?.showingPomodoro = true
                    self?.appState?.selectedTab = 1
                    print("⏰ Pomodoro Started - iOS AppDelegate")
                }
            }
            .store(in: &cancellables)
        
        return true
    }
    
    // Remote change dedup (CloudKit merges)
    
    private static func installRemoteChangeLogger() {
//        NotificationCenter.default.addObserver(forName: Notification.Name.NSPersistentStoreRemoteChange, object: nil, queue: nil) { _ in
//            LogManager.shared.log.info("📥 CloudKit remote change received - running dedup")
//            Task.detached(priority: .utility) {
//                do {
//                    let store = try await ClarityServices.store()
//                    try await store.deduplicateTasksByUUID()
//                } catch {
//                    LogManager.shared.log.error("Remote merge dedup failed: \(error.localizedDescription)")
//                }
//            }
//        }
//        LogManager.shared.log.info("✅ Installed CloudKit remote change dedup observer")
    }

    
    // This allows notifications to show when app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .badge, .sound])
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        completionHandler()
    }
}


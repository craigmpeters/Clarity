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
    
    private func populateUUIDsIfNeeded(modelContext: ModelContext, minimumBuild: String) {
        // Only run once per build
        let currentBuild = Migration.currentBuild
        guard currentBuild >= minimumBuild, Migration.hasRun(forBuild: currentBuild) == false else { return }

        // Define a dynamic fetch to avoid compile-time dependency on Todo type if not imported here
        // If you have a concrete model type like `Todo`, replace with a typed FetchDescriptor<Todo>()
        let fetch = FetchDescriptor<ToDoTask>()

        var updatedCount = 0
        do {
            // Attempt to fetch all models and filter those matching "Todo" entity name
            // and missing a value for key "uuid"
            let toDoTasks = try modelContext.fetch(fetch)
            for task in toDoTasks {
                if task.uuid == nil {
                    task.uuid = UUID()
                    updatedCount += 1
                }
            }
            if updatedCount > 0 {
                try modelContext.save()
            }
            Migration.markRun(forBuild: currentBuild)
        } catch {
            // If anything fails, don't mark as run so we can attempt again next launch
            print("Migration populateUUIDsIfNeeded error: \(error)")
        }
    }
        

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .modelContainer(container)
                .onAppear {
                    appDelegate.appState = appState
                    populateUUIDsIfNeeded(modelContext: container.mainContext, minimumBuild: "1")
                }
                .environmentObject(LogCenter.shared)
        }
    }
    
    static var appShortcuts: AppShortcutsProvider.Type {
            ClarityShortcutsProvider.self
        }
}

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    private var cancellables = Set<AnyCancellable>()
    weak var appState: AppState?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        // Migrations are triggered from ClarityApp.onAppear via modelContext
        ClarityWatchConnectivity.shared.start()
        NotificationCenter.default.publisher(for: .pomodoroStarted)
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.appState?.showingPomodoro = true
                    print("⏰ Pomodoro Started - iOS AppDelegate")
                }
            }
            .store(in: &cancellables)
        
        return true
    }
    
    // This allows notifications to show when app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .badge, .sound])
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        completionHandler()
    }
}


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
    init() {}
    
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    private let container = try! Containers.liveApp()
    @StateObject private var appState = AppState()
        

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .modelContainer(container)
                .onAppear {
                    appDelegate.appState = appState
                }
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

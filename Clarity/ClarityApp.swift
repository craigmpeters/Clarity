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

@main
struct ClarityApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    let modelContainer: ModelContainer
        
        init() {
            do {
                let schema = Schema([
                    ToDoTask.self,
                    Category.self,
                    GlobalTargetSettings.self
                ])
                
                let modelConfiguration = ModelConfiguration(
                    schema: schema,
                    isStoredInMemoryOnly: false,
                    allowsSave: true,
                    groupContainer: .identifier("group.me.craigpeters.clarity") // Same as widget
                )
                
                modelContainer = try ModelContainer(
                    for: schema,
                    configurations: [modelConfiguration]
                )
            } catch {
                fatalError("Could not create ModelContainer: \(error)")
            }
        }
        

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(modelContainer)
        }
    }
    
    static var appShortcuts: AppShortcutsProvider.Type {
            ClarityShortcuts.self
        }
}

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
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

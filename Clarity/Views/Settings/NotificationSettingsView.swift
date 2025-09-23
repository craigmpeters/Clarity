//
//  NotificationSettingsView.swift
//  Clarity
//
//  Created by Craig Peters on 20/09/2025.
//

import SwiftUI
import UserNotifications

struct NotificationSettingsView: View {
    @State private var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @State private var notificationsEnabled: Bool = false
    @State private var isRequestingPermission: Bool = false
    @State private var showSettingsAlert: Bool = false

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Notifications"), footer: footerText) {
                    Toggle(isOn: Binding(
                        get: { notificationsEnabled },
                        set: { _ in }
                    )) {
                        Text("Notifications Enabled")
                    }
                    .disabled(true)
                    .accessibilityHint("Reflects current system authorization for notifications")

                    if authorizationStatus == .notDetermined {
                        Button(action: requestPermission) {
                            if isRequestingPermission {
                                ProgressView()
                            } else {
                                Label("Enable Notifications", systemImage: "bell.badge")
                            }
                        }
                        .disabled(isRequestingPermission)
                    } else if authorizationStatus == .denied {
                        Button(role: .none) {
                            openAppSettings()
                        } label: {
                            Label("Open Settings to Allow", systemImage: "gear")
                        }
                    } else {
                        // Authorized (or provisional/ephemeral) — offer a quick test permission refresh
                        Button {
                            Task { await refreshAuthorization() }
                        } label: {
                            Label("Refresh Status", systemImage: "arrow.clockwise")
                        }
                    }
                }
            }
            .navigationTitle("Notification Settings")
            .task {
                await refreshAuthorization()
            }
            .alert("Allow Notifications in Settings", isPresented: $showSettingsAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Open Settings") { openAppSettings() }
            } message: {
                Text("Notifications are currently disabled. You can enable them in the Settings app.")
            }
        }
        
    }

    private var footerText: some View {
        Group {
            switch authorizationStatus {
            case .notDetermined:
                Text("We\'ll ask for permission to send you notifications.")
            case .denied:
                Text("Notifications are turned off. Use the button above to open Settings and enable notifications for this app.")
            case .authorized, .provisional, .ephemeral:
                Text("Notifications are allowed. You can change this in Settings at any time.")
            @unknown default:
                Text("Notification status unknown.")
            }
        }
    }

    private func refreshAuthorization() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        await MainActor.run {
            authorizationStatus = settings.authorizationStatus
            notificationsEnabled = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional || settings.authorizationStatus == .ephemeral
        }
    }

    private func requestPermission() {
        isRequestingPermission = true
        Task {
            let center = UNUserNotificationCenter.current()
            do {
                let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
                await refreshAuthorization()
                if !granted {
                    await MainActor.run { showSettingsAlert = true }
                }
            } catch {
                // Handle error (e.g., show an alert in a real app)
                await refreshAuthorization()
            }
            await MainActor.run { isRequestingPermission = false }
        }
    }

    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

#Preview {
    NavigationStack {
        NotificationSettingsView()
    }
}

//
//  CloudKitSyncSettingsView.swift
//  Clarity
//
//  Created by CloudKit Sync Integration
//

import SwiftUI
import CloudKit
import SwiftData

struct CloudKitSyncSettingsView: View {
    @Bindable var cloudKitSync: CloudKitSyncManager
    
    var body: some View {
        Section("iCloud Sync") {
            HStack {
                Image(systemName: cloudKitSync.syncIcon)
                    .foregroundColor(cloudKitSync.syncStatusColor)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Sync Status")
                        .font(.headline)
                    Text(cloudKitSync.syncStatusMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                
                if cloudKitSync.syncStatus == .syncing {
                    ProgressView()
                        .scaleEffect(0.8)
                } else if cloudKitSync.isAccountAvailable {
                    Button("Sync Now") {
                        cloudKitSync.forcSync()
                    }
                    .disabled(cloudKitSync.syncStatus == .syncing)
                }
            }
            
            if !cloudKitSync.isAccountAvailable {
                VStack(alignment: .leading, spacing: 8) {
                    Text("iCloud Not Available")
                        .font(.headline)
                        .foregroundColor(.orange)
                    
                    Text("To sync your tasks across devices, sign in to iCloud in Settings.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button("Open Settings") {
                        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(settingsUrl)
                        }
                    }
                    .buttonStyle(.bordered)
                }
            }
            
            if case .failed(let error) = cloudKitSync.syncStatus {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Sync Error")
                        .font(.headline)
                        .foregroundColor(.red)
                    
                    Text(error.localizedDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button("Retry") {
                        cloudKitSync.forcSync()
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: ToDoTask.self, configurations: config)
    let syncManager = CloudKitSyncManager(modelContext: container.mainContext)
    
    Form {
        CloudKitSyncSettingsView(cloudKitSync: syncManager)
    }
}
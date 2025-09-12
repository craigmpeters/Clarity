//
//  CloudKitSyncManager.swift
//  Clarity
//
//  Created by CloudKit Sync Integration
//

import Foundation
import SwiftData
import CloudKit
import SwiftUI

@MainActor
@Observable
class CloudKitSyncManager {
    private let modelContext: ModelContext
    
    var syncStatus: SyncStatus = .unknown
    var lastSyncDate: Date?
    var syncError: Error?
    var isAccountAvailable: Bool = false
    
    enum SyncStatus: Equatable {
        case unknown
        case syncing
        case succeeded
        case failed(Error)
        case accountNotAvailable
        case disabled
        
        static func == (lhs: SyncStatus, rhs: SyncStatus) -> Bool {
            switch (lhs, rhs) {
            case (.unknown, .unknown),
                 (.syncing, .syncing),
                 (.succeeded, .succeeded),
                 (.accountNotAvailable, .accountNotAvailable),
                 (.disabled, .disabled):
                return true
            case (.failed, .failed):
                return true // We compare just the case, not the associated error
            default:
                return false
            }
        }
    }
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        checkCloudKitAccountStatus()
        observeCloudKitNotifications()
    }
    
    // MARK: - Account Status
    
    func checkCloudKitAccountStatus() {
        Task {
            do {
                let container = CKContainer(identifier: "iCloud.me.craigpeters.clarity")
                let status = try await container.accountStatus()
                
                await MainActor.run {
                    switch status {
                    case .available:
                        self.isAccountAvailable = true
                        self.syncStatus = .unknown
                    case .noAccount, .restricted:
                        self.isAccountAvailable = false
                        self.syncStatus = .accountNotAvailable
                    case .couldNotDetermine, .temporarilyUnavailable:
                        self.isAccountAvailable = false
                        self.syncStatus = .unknown
                    @unknown default:
                        self.isAccountAvailable = false
                        self.syncStatus = .unknown
                    }
                }
            } catch {
                await MainActor.run {
                    self.isAccountAvailable = false
                    self.syncStatus = .failed(error)
                    self.syncError = error
                }
            }
        }
    }
    
    // MARK: - Manual Sync
    
    func forcSync() {
        guard isAccountAvailable else {
            checkCloudKitAccountStatus()
            return
        }
        
        syncStatus = .syncing
        
        // Force SwiftData to sync with CloudKit
        Task {
            do {
                try modelContext.save()
                await MainActor.run {
                    self.syncStatus = .succeeded
                    self.lastSyncDate = Date()
                }
            } catch {
                await MainActor.run {
                    self.syncStatus = .failed(error)
                    self.syncError = error
                }
            }
        }
    }
    
    // MARK: - CloudKit Notifications
    
    private func observeCloudKitNotifications() {
        // Listen for CloudKit sync notifications
        NotificationCenter.default.addObserver(
            forName: .CKAccountChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.checkCloudKitAccountStatus()
        }
    }
    
    // MARK: - Computed Properties
    
    var syncStatusMessage: String {
        switch syncStatus {
        case .unknown:
            return "Sync status unknown"
        case .syncing:
            return "Syncing..."
        case .succeeded:
            if let lastSync = lastSyncDate {
                let formatter = RelativeDateTimeFormatter()
                return "Last synced \(formatter.localizedString(for: lastSync, relativeTo: Date()))"
            } else {
                return "Sync successful"
            }
        case .failed(let error):
            return "Sync failed: \(error.localizedDescription)"
        case .accountNotAvailable:
            return "iCloud account not available"
        case .disabled:
            return "Sync disabled"
        }
    }
    
    var syncStatusColor: Color {
        switch syncStatus {
        case .unknown:
            return .secondary
        case .syncing:
            return .blue
        case .succeeded:
            return .green
        case .failed:
            return .red
        case .accountNotAvailable:
            return .orange
        case .disabled:
            return .secondary
        }
    }
    
    var syncIcon: String {
        switch syncStatus {
        case .unknown:
            return "questionmark.circle"
        case .syncing:
            return "arrow.trianglehead.2.clockwise"
        case .succeeded:
            return "checkmark.circle"
        case .failed:
            return "exclamationmark.triangle"
        case .accountNotAvailable:
            return "person.crop.circle.badge.exclamationmark"
        case .disabled:
            return "pause.circle"
        }
    }
}
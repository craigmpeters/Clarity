//
//  CompanionChatStore.swift
//  Clarity
//
//  App-target-only SwiftData store for companion chat history.
//

import Foundation
import SwiftData
import os

private nonisolated(unsafe) let log = LogManager.shared.log

@MainActor
final class CompanionChatStore {

    static let retentionInterval: TimeInterval = 48 * 60 * 60 // 48 hours
    static let messageCap = 100

    private let container: ModelContainer
    private let inMemory: Bool

    init() {
        let schema = Schema([ChatMessage.self])
        let isTestRun = TestEnvironment.isRunningTests || ProcessInfo.processInfo.arguments.contains("--uitesting")
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: isTestRun,
            allowsSave: true,
            groupContainer: .none,
            cloudKitDatabase: .none
        )
        do {
            container = try ModelContainer(for: schema, configurations: [config])
            inMemory = isTestRun
            log.info("CompanionChatStore: \(isTestRun ? "in-memory" : "persisted") container created")
        } catch {
            log.error("CompanionChatStore: failed to create container — \(error). Falling back to in-memory.")
            let memoryConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, allowsSave: true)
            do {
                container = try ModelContainer(for: schema, configurations: [memoryConfig])
                inMemory = true
            } catch {
                fatalError("CompanionChatStore: could not create any container — \(error)")
            }
        }
        prune()
    }

    /// Create a store backed by an explicit container (used by previews/tests).
    init(container: ModelContainer) {
        self.container = container
        self.inMemory = false
    }

    var context: ModelContext {
        ModelContext(container)
    }

    func fetchRecent(limit: Int = 100) -> [ChatMessage] {
        let context = context
        let descriptor = FetchDescriptor<ChatMessage>(
            sortBy: [SortDescriptor(\.timestamp, order: .forward)]
        )
        do {
            let all = try context.fetch(descriptor)
            return Array(all.suffix(limit))
        } catch {
            log.error("CompanionChatStore: fetch failed — \(error)")
            return []
        }
    }

    func append(_ message: ChatMessage) {
        let context = context
        context.insert(message)
        do {
            try context.save()
            log.debug("CompanionChatStore: appended message at \(message.timestamp)")
        } catch {
            log.error("CompanionChatStore: append failed — \(error)")
        }
        prune()
    }

    func deleteAll() {
        let context = context
        let descriptor = FetchDescriptor<ChatMessage>()
        do {
            let all = try context.fetch(descriptor)
            for message in all {
                context.delete(message)
            }
            try context.save()
            log.info("CompanionChatStore: deleted all messages")
        } catch {
            log.error("CompanionChatStore: deleteAll failed — \(error)")
        }
    }

    func prune() {
        let context = context
        let cutoff = Date().addingTimeInterval(-Self.retentionInterval)
        let descriptor = FetchDescriptor<ChatMessage>(
            predicate: #Predicate { $0.timestamp < cutoff }
        )
        do {
            let stale = try context.fetch(descriptor)
            for message in stale {
                context.delete(message)
            }
            try context.save()
            if !stale.isEmpty {
                log.debug("CompanionChatStore: pruned \(stale.count) messages older than 48h")
            }
        } catch {
            log.error("CompanionChatStore: prune failed — \(error)")
        }
        enforceCap()
    }

    private func enforceCap() {
        let context = context
        let descriptor = FetchDescriptor<ChatMessage>(
            sortBy: [SortDescriptor(\.timestamp, order: .forward)]
        )
        do {
            let all = try context.fetch(descriptor)
            if all.count > Self.messageCap {
                let excess = all.count - Self.messageCap
                for message in all.prefix(excess) {
                    context.delete(message)
                }
                try context.save()
                log.debug("CompanionChatStore: enforced cap, removed \(excess) oldest messages")
            }
        } catch {
            log.error("CompanionChatStore: cap enforcement failed — \(error)")
        }
    }
}

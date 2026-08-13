//
//  CompanionChatStoreTests.swift
//  ClarityTests
//
//  Unit tests for the app-target companion chat history store.
//

import Foundation
import SwiftData
import Testing
@testable import Clarity

@MainActor
struct CompanionChatStoreTests {

    private func makeStore() throws -> CompanionChatStore {
        let schema = Schema([ChatMessage.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, allowsSave: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        return CompanionChatStore(container: container)
    }

    private func message(
        timestamp: Date = Date(),
        sender: ChatSender = .companion,
        text: String
    ) -> ChatMessage {
        ChatMessage(timestamp: timestamp, sender: sender, text: text)
    }

    @Test func fetchRecentReturnsAscendingOrder() throws {
        let store = try makeStore()
        let now = Date()
        store.append(message(timestamp: now.addingTimeInterval(-120), text: "older"))
        store.append(message(timestamp: now.addingTimeInterval(-60), text: "middle"))
        store.append(message(timestamp: now, text: "newest"))

        let recent = store.fetchRecent(limit: 3)
        #expect(recent.map(\.text) == ["older", "middle", "newest"])
    }

    @Test func fetchRecentSuffixLimitsCount() throws {
        let store = try makeStore()
        let now = Date()
        for i in 0..<5 {
            store.append(message(timestamp: now.addingTimeInterval(-Double(5 - i) * 60), text: "\(i)"))
        }

        #expect(store.fetchRecent(limit: 2).map(\.text) == ["3", "4"])
        #expect(store.fetchRecent(limit: 10).map(\.text) == ["0", "1", "2", "3", "4"])
    }

    @Test func fetchRecentEmptyStoreReturnsEmpty() throws {
        let store = try makeStore()
        #expect(store.fetchRecent(limit: 10).isEmpty)
    }

    @Test func appendThenFetchRoundTrip() throws {
        let store = try makeStore()
        store.append(message(text: "hello"))
        let fetched = store.fetchRecent(limit: 1)
        #expect(fetched.count == 1)
        #expect(fetched.first?.text == "hello")
        #expect(fetched.first?.sender == .companion)
    }

    @Test func deleteAllEmptiesStore() throws {
        let store = try makeStore()
        store.append(message(text: "a"))
        store.append(message(text: "b"))
        store.deleteAll()
        #expect(store.fetchRecent(limit: 10).isEmpty)
    }

    @Test func pruneRemovesMessagesJustOutsideRetentionWindow() throws {
        let store = try makeStore()
        let now = Date()
        let inside = now.addingTimeInterval(-CompanionChatStore.retentionInterval + 60)
        let outside = now.addingTimeInterval(-CompanionChatStore.retentionInterval - 60)
        store.append(message(timestamp: inside, text: "inside"))
        store.append(message(timestamp: outside, text: "outside"))

        store.prune()
        let texts = store.fetchRecent(limit: 10).map(\.text)
        #expect(texts == ["inside"])
    }

    @Test func enforceCapKeepsExactlyOneHundred() throws {
        let store = try makeStore()
        let now = Date()
        for i in 0..<100 {
            store.append(message(timestamp: now.addingTimeInterval(Double(i)), text: "\(i)"))
        }
        #expect(store.fetchRecent(limit: 200).count == 100)
        #expect(store.fetchRecent(limit: 200).first?.text == "0")
    }

    @Test func enforceCapTrimsOldestOverOneHundred() throws {
        let store = try makeStore()
        let now = Date()
        for i in 0..<101 {
            store.append(message(timestamp: now.addingTimeInterval(Double(i)), text: "\(i)"))
        }
        let recent = store.fetchRecent(limit: 200)
        #expect(recent.count == 100)
        #expect(recent.first?.text == "1")
        #expect(recent.last?.text == "100")
    }
}

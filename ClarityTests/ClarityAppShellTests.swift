//
//  ClarityAppShellTests.swift
//  ClarityTests
//
//  Unit tests for ClarityApp non-UI shell helpers.
//

import Foundation
import SwiftData
import Testing
@testable import Clarity

@MainActor
@Suite(.serialized)
struct ClarityAppShellTests {

    private let appGroup = "group.me.craigpeters.clarity.test"
    private let pendingKey = "pendingStartTimerTaskId"

    private var testDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroup)
    }

    private func cleanup() {
        testDefaults?.removeObject(forKey: pendingKey)
        ClarityApp.Migration.reset(forBuild: "1.3.0")
        ClarityApp.Migration.reset(forBuild: "1.10.0")
    }

    @Test func consumePendingStartTimerTaskIdReadsAndClearsValidUUID() throws {
        defer { cleanup() }
        let id = UUID()
        testDefaults?.set(id.uuidString, forKey: pendingKey)

        let consumed = ClarityApp.consumePendingStartTimerTaskId(appGroup: appGroup)
        #expect(consumed == id)
        #expect(testDefaults?.string(forKey: pendingKey) == nil)
    }

    @Test func consumePendingStartTimerTaskIdReturnsNilWhenMissing() throws {
        defer { cleanup() }
        #expect(ClarityApp.consumePendingStartTimerTaskId(appGroup: appGroup) == nil)
    }

    @Test func consumePendingStartTimerTaskIdReturnsNilAndClearsMalformedValue() throws {
        defer { cleanup() }
        testDefaults?.set("not-a-uuid", forKey: pendingKey)
        #expect(ClarityApp.consumePendingStartTimerTaskId(appGroup: appGroup) == nil)
        #expect(testDefaults?.string(forKey: pendingKey) == nil)
    }

    @Test func migrationHasRunAndMarkRunRoundTrip() throws {
        defer { cleanup() }
        let build = "1.3.0"
        #expect(ClarityApp.Migration.hasRun(forBuild: build) == false)
        ClarityApp.Migration.markRun(forBuild: build)
        #expect(ClarityApp.Migration.hasRun(forBuild: build) == true)
    }

    @Test func migrationHasRunPerBuild() throws {
        defer { cleanup() }
        ClarityApp.Migration.markRun(forBuild: "1.3.0")
        #expect(ClarityApp.Migration.hasRun(forBuild: "1.10.0") == false)
        #expect(ClarityApp.Migration.hasRun(forBuild: "1.3.0") == true)
    }

    @Test func populateUUIDsIfNeededRunsWhenBuildMeetsMinimumAndBackfillsUUIDs() throws {
        defer { cleanup() }
        let container = try Containers.inMemory()
        let app = ClarityApp()
        let context = container.mainContext
        let task = ToDoTask(name: "Un UUID'd")
        task.uuid = nil
        context.insert(task)
        try context.save()

        // The migration is keyed by the current build; reset it to force a run.
        ClarityApp.Migration.reset(forBuild: ClarityApp.currentBuild)
        app.populateUUIDsIfNeeded(modelContext: context, minimumBuild: "0")
        #expect(task.uuid != nil)
    }

    @Test func populateUUIDsIfNeededSkipsWhenMigrationAlreadyRunForCurrentBuild() throws {
        defer { cleanup() }
        let container = try Containers.inMemory()
        let app = ClarityApp()
        let context = container.mainContext

        // First run: reset the migration flag, then trigger migration for the current build.
        let firstTask = ToDoTask(name: "First")
        firstTask.uuid = nil
        context.insert(firstTask)
        try context.save()
        ClarityApp.Migration.reset(forBuild: ClarityApp.currentBuild)
        app.populateUUIDsIfNeeded(modelContext: context, minimumBuild: "0")
        #expect(firstTask.uuid != nil)

        // Second run: still no-op because migration has already run for the current build.
        let secondTask = ToDoTask(name: "Second")
        secondTask.uuid = nil
        context.insert(secondTask)
        try context.save()
        app.populateUUIDsIfNeeded(modelContext: context, minimumBuild: "0")
        #expect(secondTask.uuid == nil)
    }

    @Test func currentBuildLexicographicPin() {
        // PINNED: bundle build numbers are compared lexicographically in populateUUIDsIfNeeded.
        // This test documents that "1.10.0" sorts before "1.3.0" with standard string comparison.
        #expect("1.10.0" < "1.3.0")
        #expect("1.3.0" > "1.10.0")
    }
}

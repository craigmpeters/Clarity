//
//  FileCoordinatorTests.swift
//  ClarityTests
//
//  Created by OpenCode on 16/08/2026.
//

import Compression
import Foundation
import Testing
@testable import Clarity

struct FileCoordinatorTests {
    

    private func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private func compress(_ data: Data) throws -> Data {
        var compressed = Data()
        let filter = try OutputFilter(.compress, using: .zlib) { chunk in
            if let chunk { compressed.append(chunk) }
        }
        try filter.write(data)
        try filter.finalize()
        return compressed
    }

    private func task(name: String, due: Date = Date(timeIntervalSince1970: 1_000_000), categories: [CategoryDTO] = [], completed: Bool = false) -> ToDoTaskDTO {
        ToDoTaskDTO(name: name, due: due, categories: categories, uuid: UUID(), completed: completed)
    }
    
    @Test func focusFilterWorksOnFileCoordinator () throws {
        let defaults = UserDefaults(suiteName: "group.me.craigpeters.clarity")
        let filterData = """
        {"Categories": [{"name": "included"}], "showOrHide": "show"}
        """.data(using: .utf8)!
        defaults?.set(filterData, forKey: "ClarityFocusFilter")
        defer { defaults?.removeObject(forKey: "ClarityFocusFilter") }
        let due = Date(timeIntervalSince1970: 1_000_000)
        let tasks = [
            task(name: "Write task", due: due, categories: [CategoryDTO(id: nil, name: "excluded", color: .Blue, weeklyTarget: 1)], completed: false),
            task(name: "Write task", due: due, categories: [CategoryDTO(id: nil, name: "included", color: .Blue, weeklyTarget: 1)], completed: false),
        ]
        
        try WidgetFileCoordinator.shared.writeTasks(tasks)
        let read = try WidgetFileCoordinator.shared.readTasks()
        #expect(read.count  == 1)
    }

    @Test func writeAndReadTasksRoundTrip() throws {
        let due = Date(timeIntervalSince1970: 1_000_000)
        let tasks = [
            task(name: "Write task", due: due, completed: true),
            task(name: "Read task", due: due, completed: false)
        ]

        try WidgetFileCoordinator.shared.writeTasks(tasks)
        let read = try WidgetFileCoordinator.shared.readTasks()

        #expect(read.count == 2)
        #expect(read.contains { $0.name == "Write task" && $0.completed })
        #expect(read.contains { $0.name == "Read task" && !$0.completed })
    }

    @Test func applyCompressedDataRoundTrip() throws {
        let due = Date(timeIntervalSince1970: 1_000_000)
        let tasks = [
            task(name: "Applied A", due: due, completed: false),
            task(name: "Applied B", due: due, completed: true)
        ]

        let compressed = try compress(makeEncoder().encode(tasks))
        try WidgetFileCoordinator.shared.applyCompressedData(compressed)
        let read = try WidgetFileCoordinator.shared.readTasks()

        #expect(read.count == 2)
        #expect(read.contains { $0.name == "Applied A" && !$0.completed })
        #expect(read.contains { $0.name == "Applied B" && $0.completed })
    }

    @Test func decodeCompressedDataRoundTrip() throws {
        let due = Date(timeIntervalSince1970: 1_000_000)
        let tasks = [
            task(name: "Compressed A", due: due, completed: false),
            task(name: "Compressed B", due: due, completed: true)
        ]

        let compressed = try compress(makeEncoder().encode(tasks))
        let decoded = try WidgetFileCoordinator.shared.decodeCompressedData(compressed)

        #expect(decoded.count == 2)
        #expect(decoded.contains { $0.name == "Compressed A" && !$0.completed })
        #expect(decoded.contains { $0.name == "Compressed B" && $0.completed })
    }

    @Test func decodeCompressedSnapshotRoundTrip() throws {
        let due = Date(timeIntervalSince1970: 1_000_000)
        let info = WatchUserInfo(
            tasks: [task(name: "Snapshot task", due: due, completed: false)],
            progress: WeeklyProgress(
                completed: 3,
                target: 5,
                error: nil,
                categories: [CategoryProgress(name: "Work", completed: 2, target: 3, color: "Red")]
            )
        )

        let compressed = try compress(makeEncoder().encode(info))
        let decoded = try WidgetFileCoordinator.shared.decodeCompressedSnapshot(compressed)

        #expect(decoded.tasks.count == 1)
        #expect(decoded.tasks[0].name == "Snapshot task")
        #expect(decoded.progress.completed == 3)
        #expect(decoded.progress.target == 5)
        #expect(decoded.progress.categories.count == 1)
        #expect(decoded.progress.categories[0].name == "Work")
    }

    @Test func decodeCompressedDataThrowsForInvalidData() {
        let invalidData = Data("not valid zlib data".utf8)

        #expect(throws: (any Error).self) {
            try WidgetFileCoordinator.shared.decodeCompressedData(invalidData)
        }
    }
}

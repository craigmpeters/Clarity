//
//  FocusFilterTests.swift
//  ClarityTests
//
//  Created by OpenCode on 13/08/2026.
//

import Foundation
import Testing
@testable import Clarity

struct FocusFilterTests {

    private struct FakeTask: FocusFilterable {
        let name: String
        let focusCategoryNames: [String]
        let focusIsCompleted: Bool
    }

    private func task(_ name: String, categories: [String], completed: Bool = false) -> FakeTask {
        FakeTask(name: name, focusCategoryNames: categories, focusIsCompleted: completed)
    }

    @Test func noSettingsReturnsAllTasks() {
        let tasks = [task("A", categories: ["Work"]), task("B", categories: [])]
        let result = FocusFilter.apply(to: tasks, settings: nil)
        #expect(result.count == 2)
    }

    @Test func showModeIncludesTasksWithMatchingCategory() {
        let tasks = [
            task("A", categories: ["Work"]),
            task("B", categories: ["Home"]),
            task("C", categories: ["Work", "Home"])
        ]
        let settings = FocusFilter.Settings(categoryNames: ["Work"], isHidden: false)
        let result = FocusFilter.apply(to: tasks, settings: settings)
        #expect(result.map(\.name) == ["A", "C"])
    }

    @Test func showModeIncludesUncategorizedTasks() {
        let tasks = [task("A", categories: ["Work"]), task("B", categories: [])]
        let settings = FocusFilter.Settings(categoryNames: ["Work"], isHidden: false)
        let result = FocusFilter.apply(to: tasks, settings: settings)
        #expect(result.map(\.name) == ["A", "B"])
    }

    @Test func hideModeExcludesTasksWithMatchingCategory() {
        let tasks = [
            task("A", categories: ["Work"]),
            task("B", categories: ["Home"]),
            task("C", categories: ["Work", "Home"])
        ]
        let settings = FocusFilter.Settings(categoryNames: ["Work"], isHidden: true)
        let result = FocusFilter.apply(to: tasks, settings: settings)
        #expect(result.map(\.name) == ["B"])
    }

    @Test func hideModeIncludesUncategorizedTasks() {
        let tasks = [task("A", categories: ["Work"]), task("B", categories: [])]
        let settings = FocusFilter.Settings(categoryNames: ["Work"], isHidden: true)
        let result = FocusFilter.apply(to: tasks, settings: settings)
        #expect(result.map(\.name) == ["B"])
    }

    @Test func emptyCategoryListShowModeExcludesAllTasks() {
        let tasks = [task("A", categories: ["Work"]), task("B", categories: ["Home"])]
        let settings = FocusFilter.Settings(categoryNames: [], isHidden: false)
        let result = FocusFilter.apply(to: tasks, settings: settings)
        #expect(result.isEmpty)
    }

    @Test func emptyCategoryListHideModeIncludesAllTasks() {
        let tasks = [task("A", categories: ["Work"]), task("B", categories: ["Home"])]
        let settings = FocusFilter.Settings(categoryNames: [], isHidden: true)
        let result = FocusFilter.apply(to: tasks, settings: settings)
        #expect(result.count == 2)
    }

    @Test func showModeAlwaysIncludesCompletedTasks() {
        let tasks = [
            task("A", categories: ["Home"], completed: true),
            task("B", categories: ["Work"], completed: true),
            task("C", categories: ["Work"]),
            task("D", categories: ["Home"])
        ]
        let settings = FocusFilter.Settings(categoryNames: ["Work"], isHidden: false)
        let result = FocusFilter.apply(to: tasks, settings: settings)
        #expect(result.map(\.name) == ["A", "B", "C"])
    }

    @Test func hideModeAlwaysIncludesCompletedTasks() {
        let tasks = [
            task("A", categories: ["Work"], completed: true),
            task("B", categories: ["Home"], completed: true),
            task("C", categories: ["Work"]),
            task("D", categories: ["Home"])
        ]
        let settings = FocusFilter.Settings(categoryNames: ["Work"], isHidden: true)
        let result = FocusFilter.apply(to: tasks, settings: settings)
        #expect(result.map(\.name) == ["A", "B", "D"])
    }

    @Test func decodesLegacyStringCategories() throws {
        let json = """
        {
          "Categories": ["Work", "Home"],
          "showOrHide": "show"
        }
        """.data(using: .utf8)!
        let raw = try JSONDecoder().decode(_FocusFilterRaw.self, from: json)
        #expect(raw.Categories == ["Work", "Home"])
        #expect(raw.showOrHide == "show")
    }

    @Test func decodesCategoryNameObjects() throws {
        let json = """
        {
          "Categories": [{"name": "Work"}, {"name": "Home"}],
          "showOrHide": "show"
        }
        """.data(using: .utf8)!
        let raw = try JSONDecoder().decode(_FocusFilterRaw.self, from: json)
        #expect(raw.Categories == ["Work", "Home"])
        #expect(raw.showOrHide == "show")
    }

    @Test func decodesLegacyShowMode() throws {
        let json = """
        {
          "Categories": ["Work"],
          "showOrHide": "hide"
        }
        """.data(using: .utf8)!
        let raw = try JSONDecoder().decode(_FocusFilterRaw.self, from: json)
        #expect(raw.showOrHide == "hide")
    }
}

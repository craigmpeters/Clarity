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
    }

    private func task(_ name: String, categories: [String]) -> FakeTask {
        FakeTask(name: name, focusCategoryNames: categories)
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
        let settings = FocusFilter.Settings(categoryNames: ["Work"], isHide: false)
        let result = FocusFilter.apply(to: tasks, settings: settings)
        #expect(result.map(\.name) == ["A", "C"])
    }

    @Test func showModeIncludesUncategorizedTasks() {
        let tasks = [task("A", categories: ["Work"]), task("B", categories: [])]
        let settings = FocusFilter.Settings(categoryNames: ["Work"], isHide: false)
        let result = FocusFilter.apply(to: tasks, settings: settings)
        #expect(result.map(\.name) == ["A", "B"])
    }

    @Test func hideModeExcludesTasksWithMatchingCategory() {
        let tasks = [
            task("A", categories: ["Work"]),
            task("B", categories: ["Home"]),
            task("C", categories: ["Work", "Home"])
        ]
        let settings = FocusFilter.Settings(categoryNames: ["Work"], isHide: true)
        let result = FocusFilter.apply(to: tasks, settings: settings)
        #expect(result.map(\.name) == ["B"])
    }

    @Test func hideModeIncludesUncategorizedTasks() {
        let tasks = [task("A", categories: ["Work"]), task("B", categories: [])]
        let settings = FocusFilter.Settings(categoryNames: ["Work"], isHide: true)
        let result = FocusFilter.apply(to: tasks, settings: settings)
        #expect(result.map(\.name) == ["B"])
    }

    @Test func emptyCategoryListShowModeExcludesAllTasks() {
        let tasks = [task("A", categories: ["Work"]), task("B", categories: ["Home"])]
        let settings = FocusFilter.Settings(categoryNames: [], isHide: false)
        let result = FocusFilter.apply(to: tasks, settings: settings)
        #expect(result.isEmpty)
    }

    @Test func emptyCategoryListHideModeIncludesAllTasks() {
        let tasks = [task("A", categories: ["Work"]), task("B", categories: ["Home"])]
        let settings = FocusFilter.Settings(categoryNames: [], isHide: true)
        let result = FocusFilter.apply(to: tasks, settings: settings)
        #expect(result.count == 2)
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

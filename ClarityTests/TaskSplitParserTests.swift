//
//  TaskSplitParserTests.swift
//  ClarityTests
//
//  Created by OpenCode on 13/08/2026.
//

import Foundation
import Testing
@testable import Clarity

struct TaskSplitParserTests {

    @Test func emptyTextReturnsNoSuggestions() {
        let result = TaskSplitParser.parse("", fallbackTaskName: "fallback")
        #expect(result.isEmpty)
    }

    @Test func validNumberedLinesAreParsed() {
        let text = """
        1. First task | 5
        2. Second task | 10
        3. Third task | 20
        """
        let result = TaskSplitParser.parse(text, fallbackTaskName: "fallback")
        #expect(result.count == 3)
        #expect(result[0].name == "First task")
        #expect(result[0].estimatedMinutes == 5)
        #expect(result[1].name == "Second task")
        #expect(result[1].estimatedMinutes == 10)
        #expect(result[2].name == "Third task")
        #expect(result[2].estimatedMinutes == 20)
    }

    @Test func minutesAreClampedToFiveAndTwentyFive() {
        let text = """
        1. Too short | 2
        2. Too long | 60
        """
        let result = TaskSplitParser.parse(text, fallbackTaskName: "fallback")
        #expect(result.count == 2)
        #expect(result[0].estimatedMinutes == 5)
        #expect(result[1].estimatedMinutes == 25)
    }

    @Test func malformedMinutesAreDropped() {
        let text = """
        1. Good task | 15
        2. Missing minutes |
        3. No separator here
        4. Bad number | about ten
        """
        let result = TaskSplitParser.parse(text, fallbackTaskName: "fallback")
        #expect(result.count == 1)
        #expect(result[0].name == "Good task")
        #expect(result[0].estimatedMinutes == 15)
    }

    @Test func nonNumericMinutesAreStrippedToIntegers() {
        let text = """
        1. Draft email | ~12 minutes
        """
        let result = TaskSplitParser.parse(text, fallbackTaskName: "fallback")
        #expect(result.count == 1)
        #expect(result[0].estimatedMinutes == 12)
    }

    @Test func unparseableNonEmptyTextFallsBackToSingleFifteenMinuteSuggestion() {
        let text = "Nothing parseable here"
        let result = TaskSplitParser.parse(text, fallbackTaskName: "Original task")
        #expect(result.count == 1)
        #expect(result[0].name == "Original task")
        #expect(result[0].estimatedMinutes == 15)
    }

    @Test func emptyNamePartsAreIgnored() {
        let text = """
        1.  | 15
        2. Valid | 15
        """
        let result = TaskSplitParser.parse(text, fallbackTaskName: "fallback")
        #expect(result.count == 1)
        #expect(result[0].name == "Valid")
    }

    @Test func numberingPrefixIsStripped() {
        let text = """
        12.  Numbered item | 8
        """
        let result = TaskSplitParser.parse(text, fallbackTaskName: "fallback")
        #expect(result.count == 1)
        #expect(result[0].name == "Numbered item")
        #expect(result[0].estimatedMinutes == 8)
    }
}

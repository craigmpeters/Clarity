//
//  StatsTimeframeTests.swift
//  ClarityTests
//
//  Created by OpenCode on 09/08/2026.
//

import Foundation
import Testing
@testable import Clarity

struct StatsTimeframeTests {

    @Test func caseIterableContainsAllCases() {
        #expect(StatsTimeframe.allCases.count == 6)
    }

    @Test func rawValuesMatchExpected() {
        #expect(StatsTimeframe.today.rawValue == "Today")
        #expect(StatsTimeframe.last7Days.rawValue == "7 Days")
        #expect(StatsTimeframe.last30Days.rawValue == "30 Days")
        #expect(StatsTimeframe.last90Days.rawValue == "90 Days")
        #expect(StatsTimeframe.thisYear.rawValue == "This Year")
        #expect(StatsTimeframe.allTime.rawValue == "All Time")
    }

    @Test func shortDescriptionStaticCases() {
        #expect(StatsTimeframe.today.shortDescription == "24 hrs")
        #expect(StatsTimeframe.last7Days.shortDescription == "1 week")
        #expect(StatsTimeframe.last30Days.shortDescription == "1 month")
        #expect(StatsTimeframe.last90Days.shortDescription == "3 months")
        #expect(StatsTimeframe.allTime.shortDescription == "Everything")
    }

    @Test func shortDescriptionForThisYearIsCurrentYear() {
        let currentYear = Calendar.current.component(.year, from: Date()).description
        #expect(StatsTimeframe.thisYear.shortDescription == currentYear)
    }

    @Test func dateRangeStaticCases() {
        #expect(StatsTimeframe.today.dateRange == "Today only")
        #expect(StatsTimeframe.allTime.dateRange == "All completed tasks")
    }

    @Test func dateRangeDynamicCasesHaveExpectedShape() {
        // These use Date() and DateFormatter; assert shape rather than exact strings.
        #expect(StatsTimeframe.last7Days.dateRange.contains(" - "))
        #expect(StatsTimeframe.last30Days.dateRange.contains(" - "))
        #expect(StatsTimeframe.last90Days.dateRange.contains(" - "))
        #expect(StatsTimeframe.thisYear.dateRange.hasPrefix("Since "))
    }
}

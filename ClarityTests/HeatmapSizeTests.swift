//
//  HeatmapSizeTests.swift
//  ClarityTests
//
//  Created by OpenCode on 09/08/2026.
//

import Foundation
import Testing
@testable import Clarity

struct HeatmapSizeTests {

    @Test func smallPresetDimensions() {
        #expect(HeatmapSize.small.columns == 7)
        #expect(HeatmapSize.small.rows == 4)
    }

    @Test func mediumPresetDimensions() {
        #expect(HeatmapSize.medium.columns == 10)
        #expect(HeatmapSize.medium.rows == 3)
    }

    @Test func largePresetDimensions() {
        #expect(HeatmapSize.large.columns == 10)
        #expect(HeatmapSize.large.rows == 6)
    }

    @Test func customPresetDimensions() {
        #expect(HeatmapSize.custom.columns == 10)
        #expect(HeatmapSize.custom.rows == 6)
    }

    @Test func monthLabelsAndLegendOnlyForLargeAndCustom() {
        #expect(HeatmapSize.small.showMonthLabels == false)
        #expect(HeatmapSize.small.showLegend == false)
        #expect(HeatmapSize.medium.showMonthLabels == false)
        #expect(HeatmapSize.medium.showLegend == false)
        #expect(HeatmapSize.large.showMonthLabels == true)
        #expect(HeatmapSize.large.showLegend == true)
        #expect(HeatmapSize.custom.showMonthLabels == true)
        #expect(HeatmapSize.custom.showLegend == true)
    }

    @Test func onlyCustomIsInteractive() {
        #expect(HeatmapSize.small.isInteractive == false)
        #expect(HeatmapSize.medium.isInteractive == false)
        #expect(HeatmapSize.large.isInteractive == false)
        #expect(HeatmapSize.custom.isInteractive == true)
    }
}

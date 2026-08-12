//
//  SwipeActionTests.swift
//  ClarityTests
//
//  Created by OpenCode on 09/08/2026.
//

import Foundation
import Testing
import SwiftUI
@testable import Clarity

struct SwipeActionTests {

    @Test func allCasesArePresent() {
        #expect(SwipeAction.allCases.count == 5)
        #expect(SwipeAction.allCases.contains(.none))
        #expect(SwipeAction.allCases.contains(.delete))
        #expect(SwipeAction.allCases.contains(.edit))
        #expect(SwipeAction.allCases.contains(.complete))
        #expect(SwipeAction.allCases.contains(.startTimer))
    }

    @Test func titlesAreNonEmpty() {
        for action in SwipeAction.allCases {
            #expect(action.title.isEmpty == false)
        }
    }

    @Test func rawValuesMatchExpected() {
        #expect(SwipeAction.none.rawValue == "none")
        #expect(SwipeAction.delete.rawValue == "delete")
        #expect(SwipeAction.edit.rawValue == "edit")
        #expect(SwipeAction.complete.rawValue == "complete")
        #expect(SwipeAction.startTimer.rawValue == "startTimer")
    }

    @Test func systemImagesAreNonEmpty() {
        for action in SwipeAction.allCases {
            #expect(action.systemImage.isEmpty == false)
        }
    }

    @Test func systemImageAndSystemImageNameMatch() {
        // PINNED: the two image-name properties are currently identical.
        for action in SwipeAction.allCases {
            #expect(action.systemImage == action.systemImageName)
        }
    }

    @Test func onlyDeleteHasDestructiveRole() {
        for action in SwipeAction.allCases {
            if action == .delete {
                #expect(action.role == .destructive)
            } else {
                #expect(action.role == nil)
            }
        }
    }
}

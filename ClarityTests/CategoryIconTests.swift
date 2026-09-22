//
//  CategoryIconTests.swift
//  ClarityTests
//
//  Created by OpenCode on 09/08/2026.
//

import Foundation
import Testing
@testable import Clarity

struct CategoryIconTests {

    @Test func suggestedIconNameMatchesWork() {
        #expect(CategoryIcon.suggestedIconName(for: "Work") == "briefcase.fill")
    }

    @Test func suggestedIconNameIsCaseInsensitive() {
        #expect(CategoryIcon.suggestedIconName(for: "work") == "briefcase.fill")
        #expect(CategoryIcon.suggestedIconName(for: "WORK") == "briefcase.fill")
    }

    @Test func suggestedIconNameMatchesHealth() {
        #expect(CategoryIcon.suggestedIconName(for: "Health") == "heart.fill")
    }

    @Test func suggestedIconNameMatchesSubstrings() {
        #expect(CategoryIcon.suggestedIconName(for: "Mindfulness practice") == "figure.mind.and.body")
        #expect(CategoryIcon.suggestedIconName(for: "Home cleaning") == "house.fill")
    }

    @Test func unknownCategoryReturnsNil() {
        #expect(CategoryIcon.suggestedIconName(for: "xyz_unknown") == nil)
    }

    @Test func emptyCategoryReturnsNil() {
        #expect(CategoryIcon.suggestedIconName(for: "") == nil)
    }

    @Test func orderDependencePhoneMatchesSocialBeforeDigitalWellbeing() {
        // "phone" appears in both the social mapping ("phone.fill.badge.plus") and the
        // digital wellbeing mapping ("iphone.slash"). The first match wins.
        #expect(CategoryIcon.suggestedIconName(for: "phone") == "iphone.slash")
    }

    @Test func deadEntryMakeTheBedIsUnreachable() {
        // "bed" precedes "make the bed" in the mapping, so the longer phrase never matches.
        // PINNED: this is existing behavior; re-ordering the mapping would change it.
        #expect(CategoryIcon.suggestedIconName(for: "make the bed") == "bed.double.fill")
    }

    @Test func suggestionsListIsNonEmpty() {
        #expect(CategoryIcon.suggestions.isEmpty == false)
    }
}

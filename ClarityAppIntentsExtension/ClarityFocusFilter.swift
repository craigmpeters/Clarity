//
//  ClarityFocusFilter.swift
//  ClarityAppIntentsExtension
//
//  Created by Craig Peters on 14/12/2025.
//

import Foundation
import OSLog
import AppIntents

struct ClarityFocusFilter: SetFocusFilterIntent {
    static var title: LocalizedStringResource = "Set Categories"
    static var description: IntentDescription? = "What categories are displayed during this focus mode"
    
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(primaryText)")
    }
    
    private var primaryText: String {
        guard let categories = categories else {
            return "No Categories Selected"
        }
        if categories.count > 1 {
            return "\(categories.count) Categories"
        } else {
            return categories.first?.name ?? "No Categories Selected"
        }
    }
    
    
    // MARK: Parameters
    
    @Parameter(title: "Selected Categories")
    var categories: [CategoryEntity]?
    
    @Parameter(title: "Show or Hide Categories", default: .show)
    var showOrHide: FilterShowOrHide
    
    var appContext: FocusFilterAppContext {
        Logger.AppIntents.debug("App Context Called")
        return FocusFilterAppContext()
    }
    
    func perform() async throws -> some IntentResult {
        Logger.AppIntents.debug("Performing Focus Intent")
        let defaults = UserDefaults(suiteName: "group.me.craigpeters.clarity")
        let settings = CategoryFilterSettings(Categories: self.categories ?? [], showOrHide: showOrHide)
        defaults?.set(settings, forKey: "ClarityFocusFilter")
        let categoryNames = (categories ?? []).map { $0.name }.joined(separator: ", ")
        Logger.AppIntents.debug("Set Categories: \(categoryNames)")
        return .result()
    }
}


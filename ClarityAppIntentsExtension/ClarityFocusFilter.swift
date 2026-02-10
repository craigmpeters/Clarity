//
//  ClarityFocusFilter.swift
//  ClarityAppIntentsExtension
//
//  Created by Craig Peters on 14/12/2025.
//

import Foundation
import OSLog
import AppIntents
import WidgetKit
import XCGLogger

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
    
    @Parameter(title: "Show or Hide Categories", default: .hide)
    var showOrHide: FilterShowOrHide
    
    var appContext: FocusFilterAppContext {
        LogManager.shared.log.debug("App Context Called")
        return FocusFilterAppContext()
    }
    
    func perform() async throws -> some IntentResult {
        LogManager.shared.log.debug("Performing Focus Intent")
        let defaults = UserDefaults(suiteName: "group.me.craigpeters.clarity")
        let settings = CategoryFilterSettings(Categories: self.categories ?? [], showOrHide: showOrHide)
        if let defaults {
            do {
                let data = try JSONEncoder().encode(settings)
                defaults.set(data, forKey: "ClarityFocusFilter")
                if let jsonString = String(data: data, encoding: .utf8) {
                    LogManager.shared.log.debug("Saved ClarityFocusFilter JSON: \(jsonString)")
                } else {
                    LogManager.shared.log.debug("Saved ClarityFocusFilter JSON (non-UTF8 data)")
                }
            } catch {
                LogManager.shared.log.error("Failed to encode ClarityFocusFilter: \(String(describing: error))")
            }
        }
        let categoryNames = (categories ?? []).map { $0.name }.joined(separator: ", ")
        LogManager.shared.log.debug("Set Categories: \(categoryNames)")
        WidgetCenter.shared.reloadTimelines(ofKind: "TodoWidget")
        return .result()
    }
}


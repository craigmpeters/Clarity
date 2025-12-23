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
        Logger.AppIntents.debug("App Context Called")
        return FocusFilterAppContext()
    }
    
    func perform() async throws -> some IntentResult {
        Logger.AppIntents.debug("Performing Focus Intent")
        let defaults = UserDefaults(suiteName: "group.me.craigpeters.clarity")
        let settings = CategoryFilterSettings(Categories: self.categories ?? [], showOrHide: showOrHide)
        if let defaults {
            do {
                let data = try JSONEncoder().encode(settings)
                defaults.set(data, forKey: "ClarityFocusFilter")
                if let jsonString = String(data: data, encoding: .utf8) {
                    Logger.AppIntents.debug("Saved ClarityFocusFilter JSON: \(jsonString, privacy: .public)")
                } else {
                    Logger.AppIntents.debug("Saved ClarityFocusFilter JSON (non-UTF8 data)")
                }
            } catch {
                Logger.AppIntents.error("Failed to encode ClarityFocusFilter: \(String(describing: error))")
            }
        }
        let categoryNames = (categories ?? []).map { $0.name }.joined(separator: ", ")
        Logger.AppIntents.debug("Set Categories: \(categoryNames)")
        WidgetCenter.shared.reloadTimelines(ofKind: "TodoWidget")
        return .result()
    }
}


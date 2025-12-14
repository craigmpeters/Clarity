////
////  ClarityFocusFilter.swift
////  ClarityAppIntentsExtension
////
////  Created by Craig Peters on 14/12/2025.
////
//
//import Foundation
//import OSLog
//import AppIntents
//
//struct ClarityFocusFilter: SetFocusFilterIntent {
//    typealias PerformResult = <#type#>
//    
//    typealias SummaryContent = <#type#>
//    
//    static var title: LocalizedStringResource = "Set Categories"
//    static var description: IntentDescription? = "What categories are displayed during this focus mode"
//    
//    var displayRepresentation: DisplayRepresentation {
//        DisplayRepresentation(title: "\(primaryText)")
//    }
//    
//    private var primaryText: String {
//        guard let categories = categories else {
//            return "No Cateogories Selected"
//        }
//        if categories.count > 1 {
//            return "\(categories.count) Categories"
//        } else {
//            return categories.first!.name
//        }
//    }
//    
//    // MARK: Parameters
//    
//    @Parameter(title: "Selected Categories")
//    var categories: [CategoryDTO]?
//    
//    var appContext: FocusFilterAppContext {
//        Logger.AppIntents.debug("App Context Called")
//        let predicate: Predicate
//        if let categories = categories {
//            
//        }
//        
//    }
//}

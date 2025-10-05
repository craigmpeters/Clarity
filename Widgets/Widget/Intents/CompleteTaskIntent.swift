//
//  CompleteTaskIntents.swift
//  Clarity
//
//  Created by Craig Peters on 03/09/2025.
//

//
//  CompleteTaskIntent.swift
//  Clarity
//
//  Created by Craig Peters on 03/09/2025.
//

import Foundation
import AppIntents
import SwiftData
import OSLog

struct CompleteTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "Complete Task"
    static var description = IntentDescription("Mark a task as completed")
    static var openAppWhenRun: Bool = false
    private enum CompleteTaskIntentError: Error {
        case invalidID
    }
    
    @Parameter(title: "Task ID") var idToken: String
    
    // Initialize with taskId for widget usage
    init(id: PersistentIdentifier) {
        let data = try! JSONEncoder().encode(id)
        self.idToken = data.base64EncodedString()
    }
    
    // Default initializer required by AppIntent
    init() {}
    
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let data = Data(base64Encoded: idToken) else {
            throw CompleteTaskIntentError.invalidID
        }
        let id = try JSONDecoder().decode(PersistentIdentifier.self, from: data)
        let store = try await ClarityServices.store()
        try await store.completeTask(id)
        
        return .result(dialog: "Task completed")
    }
}


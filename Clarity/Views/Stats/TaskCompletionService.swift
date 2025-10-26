//#if !os(watchOS)
//import Foundation
//import SwiftData
//
///// Disabled TaskCompletionService: kept as a no-op stub to avoid breaking callers.
//final class TaskCompletionService {
//    static let shared = TaskCompletionService()
//    private init() {}
//
//    /// No-op: previously completed a task and optionally pushed updates to Apple Watch.
//    func complete(task: ToDoTask, in context: ModelContext, sendToWatch: Bool = true) {
//        // Intentionally left blank
//    }
//
//    /// No-op: previously completed a task by its identifier.
//    func completeTask(byId taskId: String, in context: ModelContext, sendToWatch: Bool = true) {
//        // Intentionally left blank
//    }
//}
//#endif

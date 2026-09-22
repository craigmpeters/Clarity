import Foundation

final class DataRepository: @unchecked Sendable {
    nonisolated static let shared = DataRepository()
    
    nonisolated private init() {}
    
    private var dataStore: [String: Any] = [:]
    
    func save<T>(value: T, forKey key: String) {
        dataStore[key] = value
    }
    
    func retrieve<T>(forKey key: String) -> T? {
        return dataStore[key] as? T
    }
    
    func remove(forKey key: String) {
        dataStore.removeValue(forKey: key)
    }
    
    func clearAll() {
        dataStore.removeAll()
    }
}

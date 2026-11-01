import Foundation

/// Search memory: maps a typed abbreviation to the window the user picked
/// with it, so the same query ranks that window first next time.
public struct SearchMemory: Codable, Equatable {
    /// normalized query → window key.
    public var map: [String: String]

    public init(map: [String: String] = [:]) {
        self.map = map
    }

    public static func normalize(_ query: String) -> String {
        query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    /// Only queries of length ≥ 2 are remembered, to avoid noise.
    public mutating func record(query: String, windowKey: String) {
        let key = Self.normalize(query)
        guard key.count >= 2 else { return }
        map[key] = windowKey
    }

    public mutating func forget(windowKey: String) {
        map = map.filter { $0.value != windowKey }
    }

    public mutating func clear() {
        map.removeAll()
    }

    public func preferredKey(for query: String) -> String? {
        map[Self.normalize(query)]
    }
}

/// Persistence-backed store for `SearchMemory`.
public final class SearchMemoryStore {
    public static let shared = SearchMemoryStore()
    public static let fileName = "search-memory.json"

    private let file: String
    public private(set) var memory: SearchMemory

    public init(file: String = SakuraFiles.searchMemory) {
        self.file = file
        self.memory = JSONFileStore.load(SearchMemory.self, fileName: file) ?? SearchMemory()
    }

    public func record(query: String, windowKey: String) {
        memory.record(query: query, windowKey: windowKey)
        JSONFileStore.save(memory, fileName: file)
    }

    public func clear() {
        memory.clear()
        JSONFileStore.save(memory, fileName: file)
    }

    public func preferredKey(for query: String) -> String? {
        memory.preferredKey(for: query)
    }

    /// Forget entries pointing at windows that no longer exist.
    public func prune(validKeys: Set<String>) {
        let before = memory.map.count
        memory.map = memory.map.filter { validKeys.contains($0.value) }
        if memory.map.count != before {
            JSONFileStore.save(memory, fileName: file)
        }
    }
}

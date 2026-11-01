import Foundation

/// One MRU entry: a window key and when it was last used.
public struct MRUEntry: Codable, Equatable {
    public var key: String
    public var lastUsedAt: Date

    public init(key: String, lastUsedAt: Date) {
        self.key = key
        self.lastUsedAt = lastUsedAt
    }
}

/// Most-recently-used ordering, persisted as JSON.
/// The pure list logic lives here so it can be unit tested without IO.
public struct MRUList: Codable, Equatable {
    public var entries: [MRUEntry]

    public init(entries: [MRUEntry] = []) {
        self.entries = entries
    }

    /// Move `key` to the front (or insert it there).
    public mutating func markUsed(key: String, at date: Date = Date()) {
        entries.removeAll { $0.key == key }
        entries.insert(MRUEntry(key: key, lastUsedAt: date), at: 0)
    }

    /// Drop entries for windows that no longer exist.
    public mutating func removeDeadKeys(valid: Set<String>) {
        entries.removeAll { !valid.contains($0.key) }
    }

    /// Rank of a key; lower = more recent. Unknown keys get a large rank so
    /// they sort after known ones (with stable relative order preserved).
    public func rank(of key: String) -> Int {
        if let index = entries.firstIndex(where: { $0.key == key }) {
            return index
        }
        return Int.max
    }

    public func timestamp(of key: String) -> Date? {
        entries.first(where: { $0.key == key })?.lastUsedAt
    }
}

/// Persistence-backed MRU store.
public final class MRUStore {
    public static let shared = MRUStore()
    public static let fileName = "mru.json"

    private let file: String
    /// Mutable so tests can seed a known list.
    public var list: MRUList

    public init(file: String = SakuraFiles.mru) {
        self.file = file
        self.list = JSONFileStore.load(MRUList.self, fileName: file) ?? MRUList()
    }

    /// Order windows by MRU: known keys first (by recency), then unknown
    /// windows sorted by their own lastUsedAt (newest first).
    /// Same-app windows are never aggregated — each window ranks alone.
    public func ordered(_ windows: [WindowModel]) -> [WindowModel] {
        let list = self.list
        return windows.enumerated().sorted { a, b in
            let ra = list.rank(of: a.element.key)
            let rb = list.rank(of: b.element.key)
            if ra != rb { return ra < rb }
            // Both unknown to MRU: fall back to the window's own lastUsedAt.
            if a.element.lastUsedAt != b.element.lastUsedAt {
                return a.element.lastUsedAt > b.element.lastUsedAt
            }
            return a.offset < b.offset
        }.map { $0.element }
    }

    public func markUsed(_ window: WindowModel, at date: Date = Date()) {
        list.markUsed(key: window.key, at: date)
        persist()
    }

    /// Drop dead keys and stamp each live window's lastUsedAt from the MRU list.
    public func restore(into windows: inout [WindowModel]) {
        let valid = Set(windows.map { $0.key })
        list.removeDeadKeys(valid: valid)
        persist()
        for index in windows.indices {
            if let date = list.timestamp(of: windows[index].key) {
                windows[index].lastUsedAt = date
            }
        }
    }

    private func persist() {
        JSONFileStore.save(list, fileName: file)
    }
}

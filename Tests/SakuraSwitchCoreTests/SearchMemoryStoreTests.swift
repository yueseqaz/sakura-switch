import Testing
import Foundation
@testable import SakuraSwitchCore

@Suite("Search memory store")
struct SearchMemoryStoreTests {

    private func makeStore() -> SearchMemoryStore {
        SearchMemoryStore(file: "test-memory-\(UUID().uuidString).json")
    }

    @Test("Recorded preferences persist across reload")
    func persistenceRoundTrip() {
        let file = "test-memory-\(UUID().uuidString).json"
        let store = SearchMemoryStore(file: file)
        store.record(query: "vs", windowKey: "100-7")
        let reloaded = SearchMemoryStore(file: file)
        #expect(reloaded.preferredKey(for: "vs") == "100-7")
        try? FileManager.default.removeItem(at: JSONFileStore.url(forFile: file))
    }

    @Test("Prune drops entries for dead windows")
    func pruneDropsDeadKeys() {
        let store = makeStore()
        store.record(query: "vs", windowKey: "100-7")
        store.record(query: "term", windowKey: "200-9")
        store.prune(validKeys: ["200-9"])
        #expect(store.preferredKey(for: "vs") == nil)
        #expect(store.preferredKey(for: "term") == "200-9")
    }

    @Test("Clear removes everything")
    func clearRemovesAll() {
        let store = makeStore()
        store.record(query: "vs", windowKey: "100-7")
        store.clear()
        #expect(store.memory.map.isEmpty)
    }
}

@Suite("MRU store restore")
struct MRURestoreTests {

    @Test("restore stamps lastUsedAt and prunes dead keys")
    func restoreStampsAndPrunes() {
        let store = MRUStore(file: "test-mru-restore-\(UUID().uuidString).json")
        store.list.markUsed(key: "1-10", at: Date(timeIntervalSince1970: 100))
        store.list.markUsed(key: "1-20", at: Date(timeIntervalSince1970: 200))
        store.list.markUsed(key: "dead-1", at: Date(timeIntervalSince1970: 300))

        var windows = [
            WindowModel(windowID: 10, pid: 1, appName: "A", bundleID: "com.a", windowTitle: "T"),
            WindowModel(windowID: 20, pid: 1, appName: "A", bundleID: "com.a", windowTitle: "T2"),
        ]
        store.restore(into: &windows)
        #expect(windows[0].lastUsedAt == Date(timeIntervalSince1970: 100))
        #expect(windows[1].lastUsedAt == Date(timeIntervalSince1970: 200))
        #expect(store.list.rank(of: "dead-1") == Int.max) // pruned
    }

    @Test("ordered keeps live windows and drops dead ranks")
    func orderedAfterPrune() {
        let store = MRUStore(file: "test-mru-order-\(UUID().uuidString).json")
        store.list.markUsed(key: "1-20", at: Date())
        store.list.markUsed(key: "1-10", at: Date())
        let windows = [
            WindowModel(windowID: 10, pid: 1, appName: "A", bundleID: "com.a", windowTitle: "T"),
            WindowModel(windowID: 20, pid: 1, appName: "A", bundleID: "com.a", windowTitle: "T2"),
        ]
        let ordered = store.ordered(windows)
        #expect(ordered.map { $0.windowID } == [10, 20])
    }
}

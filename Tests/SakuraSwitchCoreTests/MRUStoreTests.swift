import Testing
import Foundation
import Darwin
@testable import SakuraSwitchCore

@Suite("MRU ordering")
struct MRUStoreTests {

    private func window(id: UInt32, pid: pid_t) -> WindowModel {
        WindowModel(windowID: id, pid: pid, appName: "App\(id)", bundleID: "com.app\(id)", windowTitle: "W\(id)")
    }

    @Test("markUsed moves a key to the front")
    func markUsedMovesToFront() {
        var list = MRUList()
        list.markUsed(key: "a")
        list.markUsed(key: "b")
        list.markUsed(key: "c")
        #expect(list.rank(of: "c") == 0)
        #expect(list.rank(of: "b") == 1)
        #expect(list.rank(of: "a") == 2)
        list.markUsed(key: "a")
        #expect(list.rank(of: "a") == 0)
    }

    @Test("Known keys rank before unknown ones")
    func orderingMixedKnownAndUnknown() {
        var list = MRUList()
        list.markUsed(key: "2-200")
        list.markUsed(key: "1-100")

        let w1 = window(id: 100, pid: 1) // known, most recent
        let w2 = window(id: 200, pid: 2) // known, older
        let w3 = window(id: 300, pid: 3) // unknown
        var windows = [w3, w2, w1]
        windows[0].lastUsedAt = Date(timeIntervalSince1970: 100)

        let store = MRUStore(file: "test-mru-\(UUID().uuidString).json")
        store.list = list
        let ordered = store.ordered(windows)
        #expect(ordered.map { $0.windowID } == [100, 200, 300])
    }

    @Test("Unknown windows sort by their own lastUsedAt")
    func unknownWindowsSortByOwnLastUsedAt() {
        let store = MRUStore(file: "test-mru-\(UUID().uuidString).json")
        var older = window(id: 1, pid: 1)
        var newer = window(id: 2, pid: 2)
        older.lastUsedAt = Date(timeIntervalSince1970: 1)
        newer.lastUsedAt = Date(timeIntervalSince1970: 2)
        let ordered = store.ordered([older, newer])
        #expect(ordered.map { $0.windowID } == [2, 1])
    }

    @Test("Dead keys can be removed")
    func removeDeadKeys() {
        var list = MRUList()
        list.markUsed(key: "a")
        list.markUsed(key: "b")
        list.removeDeadKeys(valid: ["a"])
        #expect(list.timestamp(of: "b") == nil)
        #expect(list.timestamp(of: "a") != nil)
    }

    @Test("Windows of the same app rank independently")
    func multiWindowSameAppNotAggregated() {
        var list = MRUList()
        list.markUsed(key: "10-1")
        list.markUsed(key: "10-2")
        list.markUsed(key: "10-1")
        #expect(list.rank(of: "10-1") == 0)
        #expect(list.rank(of: "10-2") == 1)
    }

    @Test("MRUList survives a JSON round trip")
    func jsonRoundTrip() throws {
        var list = MRUList()
        list.markUsed(key: "a", at: Date(timeIntervalSince1970: 42))
        list.markUsed(key: "b", at: Date(timeIntervalSince1970: 43))
        let data = try JSONEncoder().encode(list)
        let decoded = try JSONDecoder().decode(MRUList.self, from: data)
        #expect(decoded == list)
    }
}

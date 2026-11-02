import Testing
@testable import SakuraSwitchCore

@Suite("Application window groups")
struct ApplicationWindowGroupTests {
    private func window(_ id: UInt32, pid: Int32, bundleID: String) -> WindowModel {
        WindowModel(windowID: id, pid: pid, appName: bundleID, bundleID: bundleID, windowTitle: "Window \(id)")
    }

    @Test("Interleaved windows group by application and retain MRU order")
    func preservesOrder() {
        let groups = ApplicationWindowGroup.group([
            window(1, pid: 10, bundleID: "com.editor"),
            window(2, pid: 20, bundleID: "com.browser"),
            window(3, pid: 10, bundleID: "com.editor"),
        ])
        #expect(groups.map(\.id) == ["com.editor", "com.browser"])
        #expect(groups[0].windows.map(\.windowID) == [1, 3])
    }

    @Test("One application can have windows in multiple processes")
    func multipleProcesses() {
        let groups = ApplicationWindowGroup.group([
            window(1, pid: 10, bundleID: "com.editor"),
            window(2, pid: 11, bundleID: "com.editor"),
        ])
        #expect(groups.count == 1)
        #expect(groups[0].windows.count == 2)
    }

    @Test("Applications without bundle IDs remain separate by process")
    func missingBundleIDs() {
        let groups = ApplicationWindowGroup.group([
            window(1, pid: 10, bundleID: ""),
            window(2, pid: 20, bundleID: ""),
            window(3, pid: 10, bundleID: ""),
        ])
        #expect(groups.map(\.id) == ["pid:10", "pid:20"])
        #expect(groups[0].windows.count == 2)
        #expect(ApplicationWindowGroup.group([]).isEmpty)
    }
}

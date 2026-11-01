import Testing
import Darwin
@testable import SakuraSwitchCore

@Suite("SearchEngine")
struct SearchEngineTests {

    private func window(id: UInt32, pid: pid_t, app: String, title: String,
                        bundle: String = "com.example.app") -> WindowModel {
        WindowModel(windowID: id, pid: pid, appName: app, bundleID: bundle, windowTitle: title)
    }

    private let memory = SearchMemory(map: ["vs": "100-7"])

    @Test("Empty query keeps MRU order with zero scores")
    func emptyQueryKeepsMRUOrder() {
        let windows = [
            window(id: 1, pid: 1, app: "Safari", title: "Apple"),
            window(id: 2, pid: 2, app: "Finder", title: "Downloads"),
        ]
        let hits = SearchEngine.search(windows: windows, query: "", memory: memory, fuzzyEnabled: true)
        #expect(hits.map { $0.window.windowID } == [1, 2])
        #expect(hits.map { $0.score } == [0, 0])
    }

    @Test("App-name matches outweigh title matches")
    func appNameWeightBeatsTitleWeight() {
        let appMatchWindow = window(id: 1, pid: 1, app: "Notes", title: "Shopping list")
        let titleMatchWindow = window(id: 2, pid: 2, app: "Other", title: "Notes about birds")
        let hits = SearchEngine.search(windows: [appMatchWindow, titleMatchWindow],
                                       query: "notes", memory: memory, fuzzyEnabled: true)
        #expect(hits.first?.window.windowID == 1)
    }

    @Test("Search memory ranks the remembered window first")
    func searchMemoryRanksRememberedWindowFirst() {
        let preferred = window(id: 7, pid: 100, app: "iTerm2", title: "vs code session", bundle: "com.iterm2")
        let other = window(id: 3, pid: 200, app: "Visual Studio Code", title: "main.swift", bundle: "com.microsoft.vscode")
        // The app-name match for VS Code would normally win,
        // but memory remembers that "vs" picked the iTerm2 window.
        let hits = SearchEngine.search(windows: [other, preferred],
                                       query: "vs", memory: memory, fuzzyEnabled: true)
        #expect(hits.first?.window.windowID == 7)
        #expect(hits.first?.isMemoryPreferred == true)
    }

    @Test("Non-matching windows are excluded")
    func nonMatchedWindowExcluded() {
        let windows = [window(id: 1, pid: 1, app: "Safari", title: "Apple")]
        let hits = SearchEngine.search(windows: windows, query: "zzz", memory: memory, fuzzyEnabled: true)
        #expect(hits.isEmpty)
    }

    @Test("Bundle-ID substring matches")
    func bundleIDContainsMatch() {
        let vscode = window(id: 1, pid: 1, app: "Code", title: "Untitled", bundle: "com.microsoft.VSCode")
        let hits = SearchEngine.search(windows: [vscode], query: "vscode", memory: memory, fuzzyEnabled: true)
        #expect(hits.count == 1)
    }

    @Test("Fuzzy disabled falls back to substring matching")
    func plainModeWhenFuzzyDisabled() {
        let windows = [
            window(id: 1, pid: 1, app: "Visual Studio Code", title: "main"),
            window(id: 2, pid: 2, app: "Safari", title: "Visual design"),
        ]
        let hits = SearchEngine.search(windows: windows, query: "visual", memory: memory, fuzzyEnabled: false)
        #expect(Set(hits.map { $0.window.windowID }) == Set([1, 2]))
    }

    @Test("Equal scores break by MRU order")
    func tiesBreakByMRUOrder() {
        let a = window(id: 1, pid: 1, app: "Safari", title: "same title")
        let b = window(id: 2, pid: 2, app: "Safari", title: "same title")
        let hits = SearchEngine.search(windows: [a, b], query: "same", memory: memory, fuzzyEnabled: true)
        #expect(hits.map { $0.window.windowID } == [1, 2])
    }

    @Test("Memory record/forget semantics")
    func memoryRecordAndForget() {
        var mem = SearchMemory()
        mem.record(query: "  Term  ", windowKey: "1-2")
        #expect(mem.preferredKey(for: "term") == "1-2")
        mem.record(query: "a", windowKey: "1-3") // too short, not remembered
        #expect(mem.preferredKey(for: "a") == nil)
        mem.forget(windowKey: "1-2")
        #expect(mem.preferredKey(for: "term") == nil)
    }
}

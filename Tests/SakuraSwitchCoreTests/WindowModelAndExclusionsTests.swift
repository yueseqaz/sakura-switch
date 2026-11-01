import Testing
import CoreGraphics
@testable import SakuraSwitchCore

@Suite("Window model, alignment and exclusions")
struct WindowModelAndExclusionsTests {

    @Test("Window key is pid-windowID")
    func windowKeyStable() {
        let w = WindowModel(windowID: 42, pid: 7, appName: "A", bundleID: "com.a", windowTitle: "T")
        #expect(w.key == "7-42")
        #expect(w.id == "7-42")
    }

    @Test("Equality ignores icons but respects visible state")
    func equalityIgnoresIconAndAXElement() {
        let a = WindowModel(windowID: 1, pid: 1, appName: "A", bundleID: "com.a", windowTitle: "T")
        var b = a
        b.appIcon = nil
        #expect(a == b)
        var c = a
        c.windowTitle = "Other"
        #expect(a != c)
    }

    // MARK: - Dedup

    @Test("Duplicates with same frame+title collapse")
    func dedupeRemovesSameFrameSameTitleDuplicates() {
        let axList = [
            AXWindowSnapshot(pid: 1, title: "Editor", frame: CGRect(x: 0, y: 0, width: 800, height: 600)),
            AXWindowSnapshot(pid: 1, title: "Editor", frame: CGRect(x: 0, y: 0, width: 800, height: 600)),
            AXWindowSnapshot(pid: 1, title: "Editor", frame: CGRect(x: 10, y: 0, width: 800, height: 600)),
        ]
        #expect(WindowAligner.dedupe(axList: axList).count == 2)
    }

    @Test("Different titles or pids stay separate")
    func dedupeKeepsDifferentTitlesAndPIDs() {
        let axList = [
            AXWindowSnapshot(pid: 1, title: "A", frame: CGRect(x: 0, y: 0, width: 100, height: 100)),
            AXWindowSnapshot(pid: 1, title: "B", frame: CGRect(x: 0, y: 0, width: 100, height: 100)),
            AXWindowSnapshot(pid: 2, title: "A", frame: CGRect(x: 0, y: 0, width: 100, height: 100)),
        ]
        #expect(WindowAligner.dedupe(axList: axList).count == 3)
    }

    // MARK: - AX ↔ CG alignment

    @Test("Same-frame on-screen CG window wins, other pids ignored")
    func alignMatchesSameFrameOnScreenWindow() {
        let frame = CGRect(x: 100, y: 50, width: 640, height: 480)
        let ax = [AXWindowSnapshot(pid: 9, title: "Main", frame: frame)]
        let cg = [
            CGWindowSnapshot(windowID: 111, pid: 9, frame: frame, layer: 0, isOnScreen: true),
            CGWindowSnapshot(windowID: 999, pid: 99, frame: frame, layer: 0, isOnScreen: true),
        ]
        let aligned = WindowAligner.align(axList: ax, cgList: cg)
        #expect(aligned[0]?.windowID == 111)
    }

    @Test("Title match preferred when frames collide")
    func alignPrefersTitleMatchWithinSameFrame() {
        let frame = CGRect(x: 0, y: 0, width: 500, height: 400)
        let ax = [AXWindowSnapshot(pid: 1, title: "Expected", frame: frame)]
        let cg = [
            CGWindowSnapshot(windowID: 1, pid: 1, frame: frame, layer: 0, isOnScreen: true, title: " decoy"),
            CGWindowSnapshot(windowID: 2, pid: 1, frame: frame, layer: 0, isOnScreen: true, title: "Expected"),
        ]
        let aligned = WindowAligner.align(axList: ax, cgList: cg)
        #expect(aligned[0]?.windowID == 2)
    }

    @Test("Non-zero CG layers are never matched")
    func alignIgnoresNonZeroLayers() {
        let frame = CGRect(x: 0, y: 0, width: 500, height: 400)
        let ax = [AXWindowSnapshot(pid: 1, title: "", frame: frame)]
        let cg = [CGWindowSnapshot(windowID: 1, pid: 1, frame: frame, layer: 25, isOnScreen: true)]
        let aligned = WindowAligner.align(axList: ax, cgList: cg)
        #expect(aligned[0] == nil)
    }

    @Test("Minimized windows align by title when frames diverge")
    func alignSecondPassByTitleOnly() {
        let ax = [AXWindowSnapshot(pid: 3, title: "Inbox",
                                   frame: CGRect(x: 10, y: 10, width: 300, height: 200),
                                   isMinimized: true)]
        let cg = [CGWindowSnapshot(windowID: 55, pid: 3,
                                   frame: CGRect(x: 0, y: 0, width: 999, height: 999),
                                   layer: 0, isOnScreen: false, title: "Inbox")]
        let aligned = WindowAligner.align(axList: ax, cgList: cg)
        #expect(aligned[0]?.windowID == 55)
    }

    @Test("One CG window per AX window — no double claims")
    func alignOneCGWindowPerAXWindow() {
        let frame = CGRect(x: 0, y: 0, width: 500, height: 400)
        let ax = [
            AXWindowSnapshot(pid: 1, title: "One", frame: frame),
            AXWindowSnapshot(pid: 1, title: "Two", frame: frame),
        ]
        let cg = [
            CGWindowSnapshot(windowID: 1, pid: 1, frame: frame, layer: 0, isOnScreen: true, title: "One"),
            CGWindowSnapshot(windowID: 2, pid: 1, frame: frame, layer: 0, isOnScreen: true, title: "Two"),
        ]
        let aligned = WindowAligner.align(axList: ax, cgList: cg)
        #expect(aligned[0]?.windowID == 1)
        #expect(aligned[1]?.windowID == 2)
    }

    @Test("Only AXWindow roles with non-system subroles are switchable")
    func isSwitchable() {
        #expect(WindowAligner.isSwitchable(role: "AXWindow", subrole: "AXStandardWindow"))
        #expect(!WindowAligner.isSwitchable(role: "AXButton", subrole: ""))
        #expect(!WindowAligner.isSwitchable(role: "AXWindow", subrole: "AXSystemDialog"))
        #expect(!WindowAligner.isSwitchable(role: "AXWindow", subrole: "AXSplashScreen"))
    }

    // MARK: - Screen assignment

    @Test("Screen resolution by window center")
    func screenResolutionByCenter() {
        let screens = [
            ScreenFrame(displayID: 1, frame: CGRect(x: 0, y: 0, width: 1440, height: 900)),
            ScreenFrame(displayID: 2, frame: CGRect(x: 1440, y: 0, width: 1920, height: 1080)),
        ]
        #expect(WindowScreenResolver.screenID(for: CGRect(x: 1500, y: 100, width: 400, height: 300), screens: screens) == 2)
        #expect(WindowScreenResolver.screenID(for: CGRect(x: 10, y: 10, width: 200, height: 200), screens: screens) == 1)
    }

    // MARK: - Exclusions

    @Test("Excluded bundle IDs are filtered out")
    func exclusionFilter() {
        let windows = [
            WindowModel(windowID: 1, pid: 1, appName: "Finder", bundleID: "com.apple.finder", windowTitle: "A"),
            WindowModel(windowID: 2, pid: 2, appName: "Dock", bundleID: "com.apple.dock", windowTitle: "B"),
            WindowModel(windowID: 3, pid: 3, appName: "Safari", bundleID: "com.apple.Safari", windowTitle: "C"),
        ]
        let filtered = WindowExclusions.filter(windows, excluding: ["com.apple.dock"])
        #expect(filtered.map { $0.windowID } == [1, 3])
        #expect(WindowExclusions.isExcluded(bundleID: "com.apple.dock", list: ["com.apple.dock"]))
        #expect(!WindowExclusions.isExcluded(bundleID: "com.apple.dock", list: []))
    }

    @Test("Bundle-ID validation")
    func bundleIDValidation() {
        #expect(WindowExclusions.isValid(bundleID: "com.apple.finder"))
        #expect(WindowExclusions.isValid(bundleID: "com.microsoft.VSCode"))
        #expect(!WindowExclusions.isValid(bundleID: "nodot"))
        #expect(!WindowExclusions.isValid(bundleID: ""))
        #expect(!WindowExclusions.isValid(bundleID: "has space.app"))
    }
}

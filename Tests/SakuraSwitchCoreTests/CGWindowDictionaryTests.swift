import Testing
import CoreGraphics
@testable import SakuraSwitchCore

@Suite("System window dictionaries")
struct CGWindowDictionaryTests {
    private var systemWindow: [String: Any] {
        [
            "kCGWindowOwnerPID": 123,
            "kCGWindowNumber": 456,
            "kCGWindowBounds": ["X": 100, "Y": 50, "Width": 640, "Height": 480],
            "kCGWindowLayer": 0,
            "kCGWindowIsOnscreen": true,
            "kCGWindowName": "Editor",
        ]
    }

    @Test("Real Core Graphics keys retain the ID needed by ScreenCaptureKit")
    func readsOwnerPID() throws {
        let snapshot = try #require(WindowEnumerator.cgWindowSnapshot(from: systemWindow))
        #expect(snapshot.windowID == 456)
        #expect(snapshot.pid == 123)
        #expect(snapshot.frame == CGRect(x: 100, y: 50, width: 640, height: 480))
        #expect(snapshot.isOnScreen)
    }

    @Test("Window titles are optional when Screen Recording is not granted")
    func missingTitle() throws {
        var info = systemWindow
        info.removeValue(forKey: "kCGWindowName")
        let snapshot = try #require(WindowEnumerator.cgWindowSnapshot(from: info))
        #expect(snapshot.title == nil)
        #expect(snapshot.windowID == 456)
    }

    @Test("Invalid bounds and missing window identity are discarded")
    func rejectsInvalidEntries() {
        var info = systemWindow
        info["kCGWindowBounds"] = ["invalid": 0]
        #expect(WindowEnumerator.cgWindowSnapshot(from: info) == nil)
        info = systemWindow
        info.removeValue(forKey: "kCGWindowOwnerPID")
        #expect(WindowEnumerator.cgWindowSnapshot(from: info) == nil)
        info = systemWindow
        info["kCGWindowNumber"] = 0
        #expect(WindowEnumerator.cgWindowSnapshot(from: info) == nil)
    }
}

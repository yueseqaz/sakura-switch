import CoreGraphics
import Testing
@testable import SakuraSwitchCore

@Suite("Window preview proportions")
struct WindowPreviewGeometryTests {
    @Test("Portrait windows shrink in both dimensions instead of distorting")
    func portrait() {
        let size = WindowPreviewGeometry.fittedSize(source: CGSize(width: 700, height: 1400),
                                                    bounds: CGSize(width: 208, height: 260))
        #expect(size == CGSize(width: 130, height: 260))
    }

    @Test("Ultrawide captures preserve their ratio without a minimum-height crop")
    func wide() {
        let size = WindowPreviewGeometry.fittedSize(source: CGSize(width: 2400, height: 400),
                                                    bounds: CGSize(width: 208, height: 260))
        #expect(size.width == 208)
        #expect(abs(size.width / size.height - 6) < 0.0001)
    }

    @Test("Unknown frames fall back to a usable placeholder")
    func unknown() {
        let bounds = CGSize(width: 208, height: 120)
        #expect(WindowPreviewGeometry.fittedSize(source: .zero, bounds: bounds) == bounds)
        #expect(WindowPreviewGeometry.fittedSize(source: CGSize(width: CGFloat.infinity, height: 20), bounds: bounds) == bounds)
    }
}

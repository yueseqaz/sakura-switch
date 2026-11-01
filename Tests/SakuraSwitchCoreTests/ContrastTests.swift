import Testing
import CoreGraphics
@testable import SakuraSwitchCore

@Suite("WCAG contrast")
struct ContrastTests {

    private func rgbColor(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> CGColor {
        CGColor(srgbRed: r, green: g, blue: b, alpha: 1)
    }

    @Test("Known anchors: black on white is 21:1")
    func knownRatios() {
        let black = Contrast.relativeLuminance(r: 0, g: 0, b: 0)
        let white = Contrast.relativeLuminance(r: 1, g: 1, b: 1)
        #expect(abs(Contrast.ratio((0, 0, 0), (1, 1, 1)) - 21) < 0.01)
        #expect(abs(black - 0) < 0.001)
        #expect(abs(white - 1) < 0.001)
    }

    @Test("Light-mode body text meets WCAG AA (≥ 4.5:1)")
    func lightModeTextMeetsAA() {
        let label = rgbColor(0.10, 0.10, 0.11)
        let background = rgbColor(0.96, 0.96, 0.97)
        #expect(Contrast.meetsAA(text: label, background: background))
    }

    @Test("Dark-mode body text on charcoal meets WCAG AA")
    func darkModeTextMeetsAA() {
        let label = rgbColor(0.92, 0.92, 0.94)
        let background = rgbColor(0.16, 0.16, 0.18)
        #expect(Contrast.meetsAA(text: label, background: background))
    }

    @Test("Secondary labels meet AA on both modes")
    func secondaryTextMeetsAAOnBothModes() {
        let secondaryLight = rgbColor(0.35, 0.35, 0.38)
        let lightBackground = rgbColor(0.96, 0.96, 0.97)
        let secondaryDark = rgbColor(0.72, 0.72, 0.76)
        let darkBackground = rgbColor(0.16, 0.16, 0.18)
        #expect(Contrast.meetsAA(text: secondaryLight, background: lightBackground))
        #expect(Contrast.meetsAA(text: secondaryDark, background: darkBackground))
    }

    @Test("Low-contrast pairs are detected as failing")
    func failingContrastIsDetected() {
        let a = rgbColor(0.5, 0.5, 0.5)
        let b = rgbColor(0.55, 0.55, 0.55)
        #expect(!Contrast.meetsAA(text: a, background: b))
    }

    @Test("Switcher panel text pairs meet AA")
    func switcherPanelPairsMeetAA() {
        // NSVisualEffectView .popover approximations:
        // light ≈ rgb(0.98), dark ≈ rgb(0.21).
        let lightPanel = rgbColor(0.98, 0.98, 0.98)
        let darkPanel = rgbColor(0.22, 0.22, 0.24)
        #expect(Contrast.meetsAA(text: rgbColor(0.12, 0.12, 0.13), background: lightPanel))
        #expect(Contrast.meetsAA(text: rgbColor(0.95, 0.95, 0.96), background: darkPanel))
    }
}

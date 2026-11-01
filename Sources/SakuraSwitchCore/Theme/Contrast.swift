import Foundation
import CoreGraphics

/// WCAG relative luminance / contrast ratio math.
/// Used by the theme layer to verify that text/background pairs stay readable,
/// and covered by unit tests (WCAG AA requires ≥ 4.5:1 for body text).
public enum Contrast {

    /// sRGB relative luminance (WCAG 2.x formula), channels in 0…1.
    public static func relativeLuminance(r: Double, g: Double, b: Double) -> Double {
        func channel(_ c: Double) -> Double {
            if c <= 0.03928 { return c / 12.92 }
            return pow((c + 0.055) / 1.055, 2.4)
        }
        let rl = channel(r), gl = channel(g), bl = channel(b)
        return 0.2126 * rl + 0.7152 * gl + 0.0722 * bl
    }

    /// Contrast ratio between two RGB triples (0…1 each). Result is 1…21.
    public static func ratio(_ a: (r: Double, g: Double, b: Double),
                             _ b: (r: Double, g: Double, b: Double)) -> Double {
        let la = relativeLuminance(r: a.r, g: a.g, b: a.b)
        let lb = relativeLuminance(r: b.r, g: b.g, b: b.b)
        let lighter = max(la, lb)
        let darker = min(la, lb)
        return (lighter + 0.05) / (darker + 0.05)
    }

    /// Convenience: ratio between a text color and a solid background color.
    public static func ratio(text: CGColor, background: CGColor) -> Double {
        ratio(rgbOf(text), rgbOf(background))
    }

    /// Whether `text` on `background` meets WCAG AA (≥ 4.5:1).
    public static func meetsAA(text: CGColor, background: CGColor) -> Bool {
        ratio(text: text, background: background) >= 4.5
    }

    private static func rgbOf(_ color: CGColor) -> (r: Double, g: Double, b: Double) {
        guard let converted = color.converted(to: CGColorSpace(name: CGColorSpace.sRGB)!,
                                              intent: .defaultIntent,
                                              options: nil),
              let comps = converted.components, comps.count >= 3 else {
            return (0, 0, 0)
        }
        return (Double(comps[0]), Double(comps[1]), Double(comps[2]))
    }
}

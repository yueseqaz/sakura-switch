import AppKit

/// Programmatically drawn cherry-blossom status icon (template, adapts to
/// menu bar light/dark). Five notched petals like the app icon.
enum SakuraStatusIcon {

    static func makeImage(size: CGFloat = 18) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            let s = rect.width
            let cx = s / 2, cy = s / 2
            let petalScale = s * 0.47

            let petal = Self.petalPath(scale: petalScale)
            NSColor.black.setFill()
            for i in 0..<5 {
                NSGraphicsContext.current?.saveGraphicsState()
                let transform = NSAffineTransform()
                transform.translateX(by: cx, yBy: cy)
                transform.rotate(byRadians: CGFloat(i) * 72 * .pi / 180)
                transform.concat()
                petal.fill()
                NSGraphicsContext.current?.restoreGraphicsState()
            }
            // Center hole so the icon doesn't blob at 16–18 px.
            NSGraphicsContext.current?.saveGraphicsState()
            let previousOperation = NSGraphicsContext.current?.compositingOperation
            NSGraphicsContext.current?.compositingOperation = .destinationOut
            let hole = NSBezierPath(ovalIn: NSRect(x: cx - s * 0.055, y: cy - s * 0.055,
                                                   width: s * 0.11, height: s * 0.11))
            NSColor.black.setFill()
            hole.fill()
            NSGraphicsContext.current?.compositingOperation = previousOperation ?? .sourceOver
            NSGraphicsContext.current?.restoreGraphicsState()
            return true
        }
        image.isTemplate = true
        return image
    }

    /// Sakura petal pointing up with a notch at the tip (AppKit flavor).
    private static func petalPath(scale: CGFloat) -> NSBezierPath {
        let p = NSBezierPath()
        let w = 0.34 * scale
        let tip = 0.98 * scale
        let notchH = 0.16 * scale

        p.move(to: .zero)
        p.curve(to: NSPoint(x: -w, y: -tip + notchH),
                controlPoint1: NSPoint(x: -w * 0.95, y: -0.25 * scale),
                controlPoint2: NSPoint(x: -w * 1.06, y: -0.66 * scale))
        p.line(to: NSPoint(x: -w * 0.58, y: -tip))
        p.line(to: NSPoint(x: 0, y: -tip + notchH * 1.8))
        p.line(to: NSPoint(x: w * 0.58, y: -tip))
        p.line(to: NSPoint(x: w, y: -tip + notchH))
        p.curve(to: .zero,
                controlPoint1: NSPoint(x: w * 1.06, y: -0.66 * scale),
                controlPoint2: NSPoint(x: w * 0.95, y: -0.25 * scale))
        p.close()
        return p
    }
}

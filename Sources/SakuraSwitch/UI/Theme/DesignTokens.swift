import AppKit

/// Sakura Switch design tokens — macOS-native minimal frosted glass.
///
/// Principles: restrained, light, clear, compact, soft, non-intrusive.
/// Neutral colors dominate; blue appears only for explicit interactive
/// states. Light mode uses soft gray-white, dark mode neutral charcoal
/// (never pure black). Hierarchy comes from luminance differences, hairline
/// strokes and restrained shadows — not heavy borders or glows.
enum DS {

    // MARK: - Spacing (uniform grid: 4 / 8 / 12 / 16 / 24)

    static let space05: CGFloat = 4
    static let space1: CGFloat = 8
    static let space2: CGFloat = 12
    static let space3: CGFloat = 16
    static let space4: CGFloat = 24

    // MARK: - Corner radii

    static let radiusControl: CGFloat = 7   // buttons, fields (6–8)
    static let radiusCard: CGFloat = 11     // content cards (10–12)
    static let radiusPanel: CGFloat = 18    // floating panels (16–20)

    // MARK: - Typography (system font: SF Pro on macOS, 苹方 for Chinese)

    static let fontCaption = NSFont.systemFont(ofSize: 11)
    static let fontCaptionMedium = NSFont.systemFont(ofSize: 11, weight: .medium)
    static let fontBody = NSFont.systemFont(ofSize: 13)
    static let fontBodyMedium = NSFont.systemFont(ofSize: 13, weight: .medium)
    static let fontTitle = NSFont.systemFont(ofSize: 15, weight: .semibold)
    static let fontMono = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)

    // MARK: - Semantic colors (dynamic, resolve per appearance)

    /// Card background: barely lighter than the window in light mode,
    /// barely lighter than charcoal in dark mode.
    static let card = NSColor(name: nil) { appearance in
        appearance.isDark
            ? NSColor.white.withAlphaComponent(0.055)
            : NSColor.white.withAlphaComponent(0.55)
    }

    /// Inset control background (search fields, text fields, buttons).
    static let control = NSColor(name: nil) { appearance in
        appearance.isDark
            ? NSColor.white.withAlphaComponent(0.075)
            : NSColor.white.withAlphaComponent(0.65)
    }

    /// Hover state for rows/buttons — subtle, never loud.
    static let hover = NSColor(name: nil) { appearance in
        appearance.isDark
            ? NSColor.white.withAlphaComponent(0.09)
            : NSColor.black.withAlphaComponent(0.05)
    }

    /// Selected row/card background.
    static let selection = NSColor(name: nil) { appearance in
        appearance.isDark
            ? NSColor.white.withAlphaComponent(0.13)
            : NSColor.black.withAlphaComponent(0.08)
    }

    /// Hairline stroke: low contrast by design.
    static let hairline = NSColor(name: nil) { appearance in
        appearance.isDark
            ? NSColor.white.withAlphaComponent(0.10)
            : NSColor.black.withAlphaComponent(0.09)
    }

    /// Primary text — AA-verified pairs with the card backgrounds.
    static let textPrimary = NSColor(name: nil) { appearance in
        appearance.isDark
            ? NSColor(srgbRed: 0.93, green: 0.93, blue: 0.95, alpha: 1)
            : NSColor(srgbRed: 0.11, green: 0.11, blue: 0.12, alpha: 1)
    }

    /// Secondary text — still ≥ 4.5:1 on card backgrounds.
    static let textSecondary = NSColor(name: nil) { appearance in
        appearance.isDark
            ? NSColor(srgbRed: 0.72, green: 0.72, blue: 0.76, alpha: 1)
            : NSColor(srgbRed: 0.38, green: 0.38, blue: 0.41, alpha: 1)
    }

    /// Tertiary text (hints, shortcuts) — non-essential info only.
    static let textTertiary = NSColor(name: nil) { appearance in
        appearance.isDark
            ? NSColor(srgbRed: 0.55, green: 0.55, blue: 0.59, alpha: 1)
            : NSColor(srgbRed: 0.56, green: 0.56, blue: 0.60, alpha: 1)
    }

    /// Accent blue — only for explicit interactive states.
    static let accent = NSColor.controlAccentColor

    /// Danger (destructive), used sparingly.
    static let danger = NSColor.systemRed

    // MARK: - App metadata

    static var appVersion: String { AppInfo.version }
}

// MARK: - Appearance helpers

extension NSAppearance {
    var isDark: Bool {
        bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
    }
}

// MARK: - App metadata

enum AppInfo {
    static var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0-dev"
    }

    static var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    static var bundleID: String {
        Bundle.main.bundleIdentifier ?? "com.yueseqaz.sakuraswitch"
    }

    static var githubURL: URL { URL(string: "https://github.com/yueseqaz/sakura-switch")! }
}

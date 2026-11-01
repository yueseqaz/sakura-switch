import AppKit
import CoreGraphics

/// One switchable window. `axElement` is optional so that pure logic
/// (dedup, alignment, filtering) stays unit-testable without AX handles.
public struct WindowModel: Identifiable, Equatable {
    public var windowID: CGWindowID
    public var pid: pid_t
    public var appName: String
    public var bundleID: String
    public var windowTitle: String
    public var appIcon: NSImage?
    public var frame: CGRect
    public var isMinimized: Bool
    public var isFullscreen: Bool
    public var isOnScreen: Bool
    public var screenID: CGDirectDisplayID?
    public var lastUsedAt: Date
    public var axElement: AXUIElement?
    public var isExcluded: Bool

    public init(windowID: CGWindowID,
                pid: pid_t,
                appName: String,
                bundleID: String,
                windowTitle: String,
                appIcon: NSImage? = nil,
                frame: CGRect = .zero,
                isMinimized: Bool = false,
                isFullscreen: Bool = false,
                isOnScreen: Bool = true,
                screenID: CGDirectDisplayID? = nil,
                lastUsedAt: Date = .distantPast,
                axElement: AXUIElement? = nil,
                isExcluded: Bool = false) {
        self.windowID = windowID
        self.pid = pid
        self.appName = appName
        self.bundleID = bundleID
        self.windowTitle = windowTitle
        self.appIcon = appIcon
        self.frame = frame
        self.isMinimized = isMinimized
        self.isFullscreen = isFullscreen
        self.isOnScreen = isOnScreen
        self.screenID = screenID
        self.lastUsedAt = lastUsedAt
        self.axElement = axElement
        self.isExcluded = isExcluded
    }

    /// Stable key while the window lives: pid + CGWindowID.
    public var key: String { "\(pid)-\(windowID)" }

    public var id: String { key }

    public static func == (lhs: WindowModel, rhs: WindowModel) -> Bool {
        lhs.key == rhs.key
            && lhs.appName == rhs.appName
            && lhs.windowTitle == rhs.windowTitle
            && lhs.frame == rhs.frame
            && lhs.isMinimized == rhs.isMinimized
            && lhs.isFullscreen == rhs.isFullscreen
            && lhs.isOnScreen == rhs.isOnScreen
            && lhs.screenID == rhs.screenID
            && lhs.lastUsedAt == rhs.lastUsedAt
            && lhs.isExcluded == rhs.isExcluded
    }
}

/// A screen's global frame plus its display ID; used for screen assignment.
public struct ScreenFrame {
    public let displayID: CGDirectDisplayID
    public let frame: CGRect

    public init(displayID: CGDirectDisplayID, frame: CGRect) {
        self.displayID = displayID
        self.frame = frame
    }
}

public enum WindowScreenResolver {
    /// Assign a display ID by checking which screen contains the window
    /// frame's center. Returns nil for minimized/fully-offscreen windows.
    public static func screenID(for frame: CGRect, screens: [ScreenFrame]) -> CGDirectDisplayID? {
        guard !screens.isEmpty else { return nil }
        let center = CGPoint(x: frame.midX, y: frame.midY)
        if let containing = screens.first(where: { $0.frame.contains(center) }) {
            return containing.displayID
        }
        // Fall back to the screen with the largest intersection.
        let best = screens.max { a, b in
            a.frame.intersection(frame).width * a.frame.intersection(frame).height
                < b.frame.intersection(frame).width * b.frame.intersection(frame).height
        }
        guard let best, !best.frame.intersection(frame).isNull else { return nil }
        return best.displayID
    }
}

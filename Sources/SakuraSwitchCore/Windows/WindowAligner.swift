import Foundation
import CoreGraphics
import ApplicationServices

/// Value snapshots used by pure alignment/dedup logic (unit-testable).
public struct AXWindowSnapshot: Equatable {
    public var pid: pid_t
    public var title: String
    public var frame: CGRect
    public var role: String
    public var subrole: String
    public var isMinimized: Bool

    public init(pid: pid_t, title: String, frame: CGRect,
                role: String = kAXWindowRole, subrole: String = "", isMinimized: Bool = false) {
        self.pid = pid
        self.title = title
        self.frame = frame
        self.role = role
        self.subrole = subrole
        self.isMinimized = isMinimized
    }
}

public struct CGWindowSnapshot: Equatable {
    public var windowID: CGWindowID
    public var pid: pid_t
    public var frame: CGRect
    /// CGWindowLayer, 0 = normal window content.
    public var layer: Int
    public var isOnScreen: Bool
    /// `kCGWindowName` — only present with Screen Recording permission.
    public var title: String?

    public init(windowID: CGWindowID, pid: pid_t, frame: CGRect, layer: Int,
                isOnScreen: Bool, title: String? = nil) {
        self.windowID = windowID
        self.pid = pid
        self.frame = frame
        self.layer = layer
        self.isOnScreen = isOnScreen
        self.title = title
    }
}

/// Pure helpers that merge the AX window list with CGWindowList data.
public enum WindowAligner {

    /// Tolerance in points when comparing AX frames to CG bounds.
    public static let frameTolerance: CGFloat = 1.0

    private static func framesMatch(_ a: CGRect, _ b: CGRect) -> Bool {
        abs(a.origin.x - b.origin.x) <= frameTolerance
            && abs(a.origin.y - b.origin.y) <= frameTolerance
            && abs(a.size.width - b.size.width) <= frameTolerance
            && abs(a.size.height - b.size.height) <= frameTolerance
    }

    private static func titlesMatch(_ axTitle: String, _ cgTitle: String?) -> Bool {
        guard let cgTitle else { return false }
        if axTitle.isEmpty || cgTitle.isEmpty { return false }
        return axTitle == cgTitle
    }

    /// Map each AX window (by index) to the CG window snapshot that represents it.
    ///
    /// Matching rules, per pid, over layer-0 CG windows not yet claimed:
    /// 1. Frame match (±1pt). When several CG windows share the frame,
    ///    prefer the one whose title equals the AX title; on-screen first.
    /// 2. Otherwise: exact title match at any frame (covers minimized windows
    ///    whose CG bounds may be stale).
    ///
    /// - Returns: dictionary axIndex → CGWindowSnapshot (entries may be missing).
    public static func align(axList: [AXWindowSnapshot],
                             cgList: [CGWindowSnapshot]) -> [Int: CGWindowSnapshot] {
        var result: [Int: CGWindowSnapshot] = [:]
        var used = Set<CGWindowID>()

        let cgByPID = Dictionary(grouping: cgList.filter { $0.layer == 0 }, by: { $0.pid })

        // Pass 1: frame match with title preference.
        for (index, ax) in axList.enumerated() {
            let candidates = (cgByPID[ax.pid] ?? []).filter { cg in
                !used.contains(cg.windowID) && framesMatch(cg.frame, ax.frame)
            }
            if candidates.isEmpty { continue }
            let titleMatch = candidates.first { titlesMatch(ax.title, $0.title) }
            let onScreen = candidates.first { $0.isOnScreen }
            let best = titleMatch ?? onScreen ?? candidates[0]
            result[index] = best
            used.insert(best.windowID)
        }

        // Pass 2: title-only match for still-unmatched AX windows.
        for (index, ax) in axList.enumerated() where result[index] == nil {
            guard !ax.title.isEmpty else { continue }
            let candidate = (cgByPID[ax.pid] ?? []).first { cg in
                !used.contains(cg.windowID) && cg.title == ax.title
            }
            if let candidate {
                result[index] = candidate
                used.insert(candidate.windowID)
            }
        }

        return result
    }

    /// Remove duplicate AX windows: same pid + (nearly) same frame + same title.
    /// Keeps the first occurrence; the input order is preserved otherwise.
    public static func dedupe(axList: [AXWindowSnapshot]) -> [AXWindowSnapshot] {
        var seen = Set<String>()
        var out: [AXWindowSnapshot] = []
        for ax in axList {
            let key = "\(ax.pid)|\(Int(ax.frame.origin.x))|\(Int(ax.frame.origin.y))|\(Int(ax.frame.width))|\(Int(ax.frame.height))|\(ax.title)"
            if seen.insert(key).inserted {
                out.append(ax)
            }
        }
        return out
    }

    /// Windows whose AX role is not a real window, or whose subrole marks
    /// system chrome, are not switchable.
    public static func isSwitchable(role: String, subrole: String) -> Bool {
        guard role == kAXWindowRole else { return false }
        let ignoredSubroles: Set<String> = [
            "AXSystemDialog",
            "AXSplashScreen",
            "AXFloatingWindow",
        ]
        return !ignoredSubroles.contains(subrole)
    }
}

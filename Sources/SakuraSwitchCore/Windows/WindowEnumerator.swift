import AppKit
import ApplicationServices
import CoreGraphics

/// Enumerates switchable windows of all regular apps via the Accessibility
/// API, aligned with CGWindowList data for window IDs and screen assignment.
/// Blocking — always call from a background queue.
/// CGWindow dictionary keys — the SDK stopped exposing the C constants to
/// Swift, but their string values are stable API.
enum CGWindowKey {
    static let number = "kCGWindowNumber"
    static let ownerPID = "kCGWindowOwnerPID"
    static let bounds = "kCGWindowBounds"
    static let layer = "kCGWindowLayer"
    static let isOnscreen = "kCGWindowIsOnscreen"
    static let name = "kCGWindowName"
    static let ownerName = "kCGWindowOwnerName"
}

public final class WindowEnumerator {

    public init() {}

    // MARK: - Screens

    public static func screenFrames() -> [ScreenFrame] {
        NSScreen.screens.compactMap { screen in
            guard let deviceID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
                return nil
            }
            return ScreenFrame(displayID: CGDirectDisplayID(deviceID.uint32Value), frame: screen.frame)
        }
    }

    // MARK: - CG window list

    public static func cgWindows() -> [CGWindowSnapshot] {
        let options = CGWindowListOption(arrayLiteral: .optionAll)
        guard let raw = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return []
        }
        return raw.compactMap(cgWindowSnapshot(from:))
    }

    /// Decode the public CGWindowList dictionary without depending on a live desktop.
    public static func cgWindowSnapshot(from info: [String: Any]) -> CGWindowSnapshot? {
        guard let pidNumber = info[CGWindowKey.ownerPID] as? NSNumber,
              let idNumber = info[CGWindowKey.number] as? NSNumber,
              idNumber.uint32Value != kCGNullWindowID,
              let boundsAny = info[CGWindowKey.bounds],
              CFGetTypeID(boundsAny as CFTypeRef) == CFDictionaryGetTypeID() else { return nil }
        var bounds = CGRect.zero
        guard CGRectMakeWithDictionaryRepresentation(unsafeDowncast(boundsAny as CFTypeRef, to: CFDictionary.self), &bounds) else { return nil }
        return CGWindowSnapshot(windowID: idNumber.uint32Value,
                                pid: pid_t(pidNumber.int32Value),
                                frame: bounds,
                                layer: (info[CGWindowKey.layer] as? NSNumber)?.intValue ?? 0,
                                isOnScreen: (info[CGWindowKey.isOnscreen] as? NSNumber)?.boolValue ?? false,
                                title: info[CGWindowKey.name] as? String)
    }

    // MARK: - Enumeration

    /// Full enumeration. Exclusions are bundle IDs to skip.
    public func enumerate(exclusions: Set<String>) -> [WindowModel] {
        let started = Date()
        let screens = Self.screenFrames()
        let cgList = Self.cgWindows()
        let cgByPID = Dictionary(grouping: cgList.filter { $0.layer == 0 }, by: { $0.pid })

        let apps = NSWorkspace.shared.runningApplications.filter {
            $0.activationPolicy == .regular && !$0.isTerminated
        }

        var models: [WindowModel] = []
        models.reserveCapacity(apps.count * 2)

        for app in apps {
            let pid = app.processIdentifier
            let bundleID = app.bundleIdentifier ?? ""
            if exclusions.contains(bundleID) { continue }

            let axApp = AXHelper.applicationElement(pid: pid)
            guard let windowElements = AXHelper.array(axApp, kAXWindowsAttribute) else { continue }

            // Read + filter AX windows (also dedupes same-frame/title pairs).
            var snapshots: [AXWindowSnapshot] = []
            var elements: [AXUIElement] = []
            for element in windowElements {
                guard let snapshot = AXHelper.windowSnapshot(pid: pid, element: element) else { continue }
                if WindowAligner.dedupe(axList: snapshots + [snapshot]).count == snapshots.count {
                    continue // duplicate of an existing snapshot
                }
                snapshots.append(snapshot)
                elements.append(element)
            }

            // Align with CG windows for IDs / on-screen state / screen.
            let aligned = WindowAligner.align(axList: snapshots, cgList: cgByPID[pid] ?? [])

            for (index, snapshot) in snapshots.enumerated() {
                let cg = aligned[index]
                let windowID = cg?.windowID ?? Self.fallbackWindowID(snapshot)
                let isOnScreen = cg?.isOnScreen ?? true
                let screenID = WindowScreenResolver.screenID(for: snapshot.frame, screens: screens)

                let model = WindowModel(
                    windowID: windowID,
                    pid: pid,
                    appName: app.localizedName ?? "App(\(pid))",
                    bundleID: bundleID,
                    windowTitle: snapshot.title,
                    appIcon: app.icon,
                    frame: snapshot.frame,
                    isMinimized: snapshot.isMinimized,
                    isFullscreen: snapshot.isFullscreen,
                    isOnScreen: isOnScreen,
                    screenID: screenID,
                    lastUsedAt: .distantPast,
                    axElement: elements[index],
                    isExcluded: false
                )
                models.append(model)
            }
        }

        let elapsed = Date().timeIntervalSince(started)
        Log.windowEnumeration.info("Enumerated \(models.count) windows in \(String(format: "%.0f", elapsed * 1000), privacy: .public)ms")
        return models
    }

    /// Deterministic pseudo-ID for AX windows without a CG counterpart.
    static func fallbackWindowID(_ snapshot: AXWindowSnapshot) -> CGWindowID {
        var hasher = Hasher()
        hasher.combine(snapshot.pid)
        hasher.combine(Int(snapshot.frame.origin.x))
        hasher.combine(Int(snapshot.frame.origin.y))
        hasher.combine(Int(snapshot.frame.width))
        hasher.combine(Int(snapshot.frame.height))
        hasher.combine(snapshot.title)
        return CGWindowID(truncatingIfNeeded: hasher.finalize())
    }
}

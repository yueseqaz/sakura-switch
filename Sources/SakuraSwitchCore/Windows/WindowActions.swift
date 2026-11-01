import AppKit
import ApplicationServices

/// Window control operations executed from the switcher.
public enum WindowActions {

    // MARK: - Switching

    /// Bring a window to the front: unminimize, activate the app, raise,
    /// set main + focused. Cross-Space windows go through app activation,
    /// letting the system perform the Space transition.
    @discardableResult
    public static func activate(_ window: WindowModel) -> Bool {
        var success = true

        // 1. Restore minimized windows first.
        if window.isMinimized, let element = window.axElement {
            if !AXHelper.setBool(element, kAXMinimizedAttribute, false) {
                Log.switcher.error("Failed to unminimize window")
                success = false
            }
        }

        // 2. Activate the owning app.
        guard let app = NSRunningApplication(processIdentifier: window.pid) else {
            return false
        }
        activateApp(app)

        // 3. Raise and focus the window.
        if let element = window.axElement {
            if !AXHelper.perform(element, kAXRaiseAction) {
                Log.switcher.error("Raise action failed")
                success = false
            }
            AXHelper.setBool(element, kAXMainAttribute, true)
            AXHelper.setBool(element, kAXFocusedAttribute, true)
        }

        return success
    }

    /// `NSRunningApplication.activate` is deprecated on macOS 14+; wrap it so
    /// the deprecation stays contained.
    @available(macOS, introduced: 13.0, deprecated: 14.0)
    static func activateApp(_ app: NSRunningApplication) {
        app.activate(options: [.activateIgnoringOtherApps])
    }

    // MARK: - Quick actions

    @discardableResult
    public static func close(_ window: WindowModel) -> Bool {
        guard let element = window.axElement,
              let rawClose = AXHelper.attribute(element, kAXCloseButtonAttribute),
              CFGetTypeID(rawClose) == AXUIElementGetTypeID() else {
            Log.switcher.error("No close button for window")
            return false
        }
        let closeButton = unsafeDowncast(rawClose, to: AXUIElement.self)
        return AXHelper.perform(closeButton, kAXPressAction)
    }

    @discardableResult
    public static func minimize(_ window: WindowModel) -> Bool {
        guard let element = window.axElement else { return false }
        return AXHelper.setBool(element, kAXMinimizedAttribute, true)
    }

    @discardableResult
    public static func toggleFullscreen(_ window: WindowModel) -> Bool {
        guard let element = window.axElement else { return false }
        return AXHelper.setBool(element, "AXFullScreen", !window.isFullscreen)
    }

    @discardableResult
    public static func hideApp(_ window: WindowModel) -> Bool {
        guard let app = NSRunningApplication(processIdentifier: window.pid) else { return false }
        return app.hide()
    }

    @discardableResult
    public static func quitApp(_ window: WindowModel) -> Bool {
        guard let app = NSRunningApplication(processIdentifier: window.pid) else { return false }
        return app.terminate()
    }

    /// Reveal the window's document in Finder (⌘R on file windows).
    @discardableResult
    public static func revealInFinder(_ window: WindowModel) -> Bool {
        guard let element = window.axElement,
              let document = AXHelper.string(element, kAXDocumentAttribute) else {
            return false
        }
        var path = document
        // Document attributes may be file URLs or plain paths.
        if let url = URL(string: document), url.isFileURL {
            path = url.path
        }
        guard FileManager.default.fileExists(atPath: path) else {
            Log.switcher.error("Document path does not exist")
            return false
        }
        return NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: (path as NSString).deletingLastPathComponent)
    }
}

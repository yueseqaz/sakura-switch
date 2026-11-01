import Foundation
import AppKit
import ApplicationServices
import CoreGraphics

/// Accessibility permission — required for the whole app.
/// Checked on every switcher invocation, so a fresh grant applies
/// without restarting the app.
public enum AccessibilityPermission {

    public static var isGranted: Bool {
        AXIsProcessTrusted()
    }

    /// Deep link into System Settings → Privacy & Security → Accessibility.
    public static func openSystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}

/// Screen Recording permission — optional, only for window thumbnails.
public enum ScreenCapturePermission {

    public static var isGranted: Bool {
        CGPreflightScreenCaptureAccess()
    }

    /// Triggers the system prompt (once); afterwards the user manages the
    /// toggle in System Settings.
    public static func request() {
        _ = CGRequestScreenCaptureAccess()
    }

    public static func openSystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }
}

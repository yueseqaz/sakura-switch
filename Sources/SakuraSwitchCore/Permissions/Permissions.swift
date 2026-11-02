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

    /// Register this running app with TCC before sending the user to Settings.
    public static func request() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let granted = AXIsProcessTrustedWithOptions(options as CFDictionary)
        Log.permissions.info("Accessibility request: granted=\(granted), bundle=\(Bundle.main.bundleIdentifier ?? "unbundled", privacy: .public)")
    }

    public static func requestAndOpenSystemSettings() {
        if !isGranted { request() }
        openSystemSettings()
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
        let granted = CGRequestScreenCaptureAccess()
        Log.permissions.info("Screen Recording request: granted=\(granted)")
    }

    public static func requestAndOpenSystemSettings() {
        if !isGranted { request() }
        openSystemSettings()
    }

    public static func openSystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }
}

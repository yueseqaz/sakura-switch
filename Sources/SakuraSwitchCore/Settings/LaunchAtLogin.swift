import Foundation
import ServiceManagement

/// Launch-at-login via `SMAppService` (macOS 13+). Failures are reported
/// to the caller and logged — they never block the app.
public enum LaunchAtLogin {

    public static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    @discardableResult
    public static func setEnabled(_ enabled: Bool) -> Bool {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            Log.settings.info("Launch at login set to \(enabled)")
            return true
        } catch {
            Log.settings.error("Launch at login update failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }
}
